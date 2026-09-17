#!/usr/bin/env python3
"""Checador simples de balanceamento de (), [], {} em arquivos Lua/OTUI.

Ignora strings ("...", '...') e comentarios (--, --[[ ]]).
Uso: python tools/check_lua_balance.py <arquivo> [arquivo...]
"""
import sys


def strip_strings_and_comments(s):
    out = []
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        if c == "-" and s[i:i + 2] == "--":
            if s[i:i + 4] == "--[[":
                j = s.find("]]", i + 4)
                i = (j + 2) if j != -1 else n
            else:
                j = s.find("\n", i + 2)
                i = (j + 1) if j != -1 else n
            out.append(" ")
        elif c in ('"', "'"):
            quote = c
            j = i + 1
            while j < n:
                if s[j] == "\\":
                    j += 2
                    continue
                if s[j] == quote:
                    break
                j += 1
            i = j + 1 if j < n else n
            out.append('""')
        else:
            out.append(c)
            i += 1
    return "".join(out)


def check(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        s = f.read()
    s = strip_strings_and_comments(s)
    stack = []
    pairs = {")": "(", "]": "[", "}": "{"}
    for i, ch in enumerate(s):
        if ch in "([{":
            stack.append((ch, i))
        elif ch in ")]}":
            if not stack or stack[-1][0] != pairs[ch]:
                print(f"  ERRO {path}:{s.count(chr(10), 0, i) + 1}: '{ch}' sem par")
                return False
            stack.pop()
    if stack:
        ch, i = stack[0]
        print(f"  ERRO {path}: abre '{ch}' linha {s.count(chr(10), 0, i) + 1} sem fechar")
        return False
    print(f"  OK {path}")
    return True


def main():
    ok = True
    for f in sys.argv[1:]:
        try:
            if not check(f):
                ok = False
        except Exception as e:
            print(f"  ERRO lendo {f}: {e}")
            ok = False
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
