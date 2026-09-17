"""Compila todos os .lua de modules/ e mods/ com um Lua 5.1 real (luaL_loadfile).

Cada arquivo roda em um estado Lua novo e isolado: assim um arquivo problematico
nao derruba a varredura inteira.

Uso:
    python tools/lua_syntax_check.py [lua51.dll]
      (sem argumento, procura a DLL em %TEMP%/luacheck, /tmp/luacheck e no PATH)
"""
import ctypes
import os
import sys
from pathlib import Path

LUA_OK = 0


def find_dll(argv):
    candidates = []
    if len(argv) > 1:
        candidates.append(Path(argv[1]))
    temp = os.environ.get("TEMP") or os.environ.get("TMP") or "/tmp"
    candidates += [
        Path(temp) / "luacheck" / "lua51.dll",
        Path("/tmp/luacheck/lua51.dll"),
        Path("lua51.dll"),
    ]
    for c in candidates:
        if c.is_file():
            return c
    sys.exit("lua51.dll nao encontrada; passe o caminho como argumento")


def check(lua, path):
    """Compila um arquivo num estado Lua novo. Retorna a mensagem de erro ou None."""
    L = lua.luaL_newstate()
    if not L:
        return "nao consegui criar o estado Lua"
    try:
        rc = lua.luaL_loadfile(L, str(path).encode("utf-8", "replace"))
        if rc == LUA_OK:
            return None
        msg = lua.lua_tolstring(L, -1, None)
        return (msg or b"").decode("utf-8", "replace")
    finally:
        lua.lua_close(L)


def main():
    dll = find_dll(sys.argv)
    root = Path(__file__).resolve().parent.parent
    lua = ctypes.CDLL(str(dll))
    lua.luaL_newstate.restype = ctypes.c_void_p
    lua.luaL_newstate.argtypes = []
    lua.luaL_loadfile.restype = ctypes.c_int
    lua.luaL_loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lua.lua_tolstring.restype = ctypes.c_char_p
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    lua.lua_close.argtypes = [ctypes.c_void_p]

    files = []
    for base in ("modules", "mods"):
        files += sorted((root / base).rglob("*.lua"))
    files += sorted(root.glob("*.lua"))

    bad = 0
    for f in files:
        err = check(lua, f)
        if err:
            bad += 1
            rel = f.relative_to(root)
            print("ERRO %s\n     %s" % (rel, err))

    print("%d/%d arquivos compilam" % (len(files) - bad, len(files)))
    return 1 if bad else 0


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    sys.exit(main())
