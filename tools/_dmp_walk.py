"""Diagnostico de minidump: acha a thread que crashou, le a pilha e resolve os enderecos
de retorno com dbghelp (usa o PDB do otclient_gl.exe que esta na raiz do client).

Uso:  python tools/_dmp_walk.py [caminho_do_dump]
"""
import ctypes
import ctypes.wintypes as w
import os
import struct
import sys
import time

EXE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'otclient_gl.exe'))
MODBASE = 0x7FF75A000000
MODSIZE = 0x01094000


def parse_dump(path):
    with open(path, 'rb') as fh:
        data = fh.read()
    sig, _, nstreams, dirrva, _, tstamp, _ = struct.unpack_from('<IIIIIII', data, 0)
    assert data[:4] == b'MDMP', 'nao e um minidump'
    streams = {}
    for i in range(nstreams):
        st, sz, rva = struct.unpack_from('<III', data, dirrva + i * 12)
        streams.setdefault(st, []).append((sz, rva))
    return data, streams, tstamp


def exc_stream(data, streams):
    sz, rva = streams[6][0]
    tid = struct.unpack_from('<I', data, rva)[0]
    code, eflags, erec, eaddr, nparams = struct.unpack_from('<IIQQI', data, rva + 8)
    # MINIDUMP_EXCEPTION_CONTEXT (LOCATION_DESCRIPTOR) logo depois do exception record
    tctx_size, tctx_rva = struct.unpack_from('<II', data, rva + 8 + 152)
    return tid, code, eaddr, nparams, tctx_rva


def threads(data, streams):
    sz, rva = streams[3][0]
    (n,) = struct.unpack_from('<I', data, rva)
    out = []
    for i in range(n):
        b = rva + 4 + i * 48
        tid = struct.unpack_from('<I', data, b)[0]
        st_start, st_sz, st_rva = struct.unpack_from('<QII', data, b + 16)
        ctx_sz, ctx_rva = struct.unpack_from('<II', data, b + 32)
        out.append(dict(tid=tid, stack=(st_start, st_sz, st_rva), ctx=(ctx_sz, ctx_rva)))
    return out


class SYMBOL_INFO(ctypes.Structure):
    _fields_ = [('SizeOfStruct', w.ULONG), ('TypeIndex', w.ULONG),
                ('Reserved', ctypes.c_ulonglong * 2), ('Index', w.ULONG), ('Size', w.ULONG),
                ('ModBase', ctypes.c_ulonglong), ('Flags', w.ULONG), ('Value', ctypes.c_ulonglong),
                ('Address', ctypes.c_ulonglong), ('Register', w.ULONG), ('Scope', w.ULONG),
                ('Tag', w.ULONG), ('NameLen', w.ULONG), ('MaxNameLen', w.ULONG),
                ('Name', ctypes.c_char * 2048)]


class LINE64(ctypes.Structure):
    _fields_ = [('SizeOfStruct', w.ULONG), ('Key', ctypes.c_void_p), ('LineNumber', w.ULONG),
                ('FileName', ctypes.c_char_p), ('Address', ctypes.c_ulonglong)]


def init_dbg():
    dbg = ctypes.WinDLL('dbghelp')
    dbg.SymSetOptions(0x2 | 0x4 | 0x10)
    h = ctypes.WinDLL('kernel32').GetCurrentProcess()
    dbg.SymInitialize.argtypes = [ctypes.c_void_p, ctypes.c_char_p, w.BOOL]
    dbg.SymInitialize(h, None, False)
    dbg.SymLoadModuleEx.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_char_p,
                                    ctypes.c_char_p, ctypes.c_ulonglong, w.DWORD,
                                    ctypes.c_void_p, w.DWORD]
    dbg.SymLoadModuleEx.restype = ctypes.c_ulonglong
    dbg.SymLoadModuleEx(h, None, EXE.encode(), None, MODBASE, MODSIZE, None, 0)
    dbg.SymFromAddr.argtypes = [ctypes.c_void_p, ctypes.c_ulonglong,
                               ctypes.POINTER(ctypes.c_ulonglong), ctypes.POINTER(SYMBOL_INFO)]
    dbg.SymGetLineFromAddr64.argtypes = [ctypes.c_void_p, ctypes.c_ulonglong,
                                         ctypes.POINTER(w.DWORD), ctypes.POINTER(LINE64)]
    return dbg, h


def resolve(dbg, h, addr):
    sym = SYMBOL_INFO()
    sym.SizeOfStruct = ctypes.sizeof(SYMBOL_INFO)
    sym.MaxNameLen = 2000
    disp = ctypes.c_ulonglong(0)
    name = None
    if dbg.SymFromAddr(h, addr, ctypes.byref(disp), ctypes.byref(sym)):
        name = '%s+0x%X' % (sym.Name.decode(), disp.value)
    ln = LINE64()
    ln.SizeOfStruct = ctypes.sizeof(LINE64)
    d = w.DWORD(0)
    line = ''
    if dbg.SymGetLineFromAddr64(h, addr, ctypes.byref(d), ctypes.byref(ln)):
        f = (ln.FileName or b'').decode()
        f = f.split('\\Avatar-comprado-client\\')[-1]
        line = '   [%s:%d]' % (f, ln.LineNumber)
    return name, line


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.expandvars(
        r'%APPDATA%\OTClientV8\otclientv8\exception2.dmp')
    data, streams, tstamp = parse_dump(path)
    print('dump    :', path, '(%d bytes)' % len(data))
    print('criado em:', time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(tstamp)))
    tid, code, eaddr, nparams, tctx_rva = exc_stream(data, streams)
    print('thread  : %d   excecao=0x%08X  endereco=0x%016X' % (tid, code, eaddr))
    th = [t for t in threads(data, streams) if t['tid'] == tid]
    if not th:
        print('thread nao esta na lista!')
        return
    t = th[0]
    st_start, st_sz, st_rva = t['stack']
    stack_here = st_rva and st_sz
    print('pilha   : 0x%X  (%d KB no dump: %s)' % (st_start, st_sz // 1024,
                                                  'sim' if stack_here else 'nao (usar exception_full.dmp)'))
    if tctx_rva:
        rsp = struct.unpack_from('<Q', data, tctx_rva + 0x98)[0]
        rbp = struct.unpack_from('<Q', data, tctx_rva + 0xA0)[0]
        rip = struct.unpack_from('<Q', data, tctx_rva + 0xF8)[0]
        print('contexto: RIP=0x%016X  RSP=0x%016X  RBP=0x%016X' % (rip, rsp, rbp))
    else:
        rsp = st_start

    def read_range(handle, start, size):
        """Le [start, start+size) usando os mapas de memoria do dump (Memory64List=9 / MemoryList=5)."""
        # Memory64List
        if 9 in streams:
            sz, rva = streams[9][0]
            n, base_rva = struct.unpack_from('<QQ', data, rva)
            off = base_rva
            for i in range(n):
                rs, rsz = struct.unpack_from('<QQ', data, rva + 16 + i * 16)
                if rs <= start < rs + rsz:
                    avail = min(size, rs + rsz - start)
                    handle.seek(off + (start - rs))
                    return handle.read(avail)
                off += rsz
        for sz, rva in streams.get(5, []):
            (nmem,) = struct.unpack_from('<I', data, rva)
            for i in range(nmem):
                rs, rsz, rrva = struct.unpack_from('<QII', data, rva + 4 + i * 16)
                if rs <= start < rs + rsz:
                    avail = min(size, rs + rsz - start)
                    return data[rrva:rrva + avail]
        return b''

    want = 128 * 1024
    window_start = rsp if rsp else st_start
    if st_rva and st_rva + min(st_sz, 4096) <= len(data) and not (5 in streams or 9 in streams):
        st_data = data[st_rva:st_rva + st_sz]
        window_start = st_start
    else:
        full = path.replace('exception2.dmp', 'exception_full.dmp')
        if not os.path.exists(full):
            print('nao achei', full)
            return
        print('lendo a pilha do dump completo (isso leva alguns segundos)...')
        with open(full, 'rb') as fh:
            st_data = read_range(fh, window_start, want)
    if not st_data:
        print('nao consegui ler a pilha')
        return
    st_start = window_start

    dbg, h = init_dbg()
    lo, hi = MODBASE, MODBASE + MODSIZE
    print('\n=== cadeia de chamadas (enderecos de retorno na pilha) ===')
    seen = set()
    top = rsp - st_start if rsp >= st_start else 0
    for off in range(0, len(st_data) - 8, 8):
        (val,) = struct.unpack_from('<Q', st_data, off)
        if lo <= val < hi:
            name, line = resolve(dbg, h, val)
            key = (name, line)
            if key in seen:
                continue
            seen.add(key)
            print('  [rsp+0x%05X] 0x%016X  %s%s' % (off - top if off >= top else off - top,
                                                  val, name or '?', line))


if __name__ == '__main__':
    main()
