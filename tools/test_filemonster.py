#!/usr/bin/env python3
"""Testa a logica de nome-de-arquivo -> nome-de-criatura da lib huntWaypoint.lua."""
import re

# equivalente python do padrao Lua: src:match("([^/\\]+)%.lua$")
PAT = re.compile(r"([^/\\]+)\.lua$")


def file_monster_name(src):
    m = PAT.search(src or "")
    f = m.group(1) if m else ""
    return re.sub(r"[-_]", " ", f)


TESTS = [
    ("data/huntwaypoint/terra_beetle.lua", "Terra beetle"),
    ("@data/huntwaypoint/abelha_de_barro.lua", "Abelha de barro"),
    ("data/huntwaypoint/Cockroach.lua", "Cockroach"),
    ("data/huntwaypoint/mother-of-scarabs.lua", "Mother of scarabs"),
    ("data/huntwaypoint/sea-serpent.lua", "Sea serpent"),
    ("data/huntwaypoint/Joaninha da terra.lua", "Joaninha da terra"),
    ("", ""),
]

ok = True
for src, expected in TESTS:
    got = file_monster_name(src)
    status = "OK " if got.lower() == expected.lower() else "FAIL"
    if got.lower() != expected.lower():
        ok = False
    print(f"  {status} {src!r} -> {got!r} (esperado {expected!r})")

print("TODOS OK" if ok else "HÁ FALHAS")
raise SystemExit(0 if ok else 1)
