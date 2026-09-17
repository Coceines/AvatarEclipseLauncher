#!/usr/bin/env python3
"""Checador de *ligacoes* do .otui: ids, anchors, imagens e o que o lua procura.

Complementa o tools/check_otui.py (que valida as regras do parser: indentacao,
comentario com '--', estilo indefinido...). Este aqui valida o que o parser
aceita mas quebra em runtime:

  * id duplicado entre irmaos (getChildById devolve o primeiro);
  * anchors apontando para id que nao existe - em OTClient o alvo e' procurado
    em parentWidget->getChildById() (uianchorlayout.cpp), ou seja, so' entre
    IRMAOS (fora 'parent', 'prev' e 'next');
  * image-source relativo (modulo) ou /images/... que nao existe no disco;
  * id que algum .lua da mesma pasta pede em getChildById()/recursiveGetChildById()
    e que nao existe em nenhum .otui varrido (nome trocado, widget apagado).

Uso:
    python tools/check_otui_widgets.py <arquivo.otui|pasta> [...]
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

WIDGET_LINE = re.compile(r"^([A-Za-z_][\w-]*)(\s*<\s*([A-Za-z_][\w-]*))?\s*$")
PROP_LINE = re.compile(r"^\s*([$@!]*[A-Za-z_][\w.-]*)(?:\s+[^:]*)?\s*:\s*(.*)$")
LUA_ID = re.compile(r"""(?:recursive)?[gG]etChildById\(\s*['"]([^'"]+)['"]\s*\)""")

SPECIAL_TARGETS = {"parent", "prev", "next", ""}
ANCHOR_KEYS = {"top", "bottom", "left", "right", "horizontalCenter",
               "verticalCenter", "centerIn", "fill"}


class Widget:
    __slots__ = ("name", "base", "line", "parent", "id", "props")

    def __init__(self, name, base, line, parent):
        self.name = name
        self.base = base
        self.line = line
        self.parent = parent
        self.id = None
        self.props = {}


def parse(path):
    """Arvore de widgets do arquivo + linhas de ancoragem de imagem."""
    widgets, stack = [], []
    for n, raw in enumerate(path.read_text(encoding="utf-8", errors="surrogateescape").splitlines(), 1):
        if not raw.strip() or raw.lstrip().startswith(("//", "--")):
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        text = raw.strip()
        m = WIDGET_LINE.match(text)
        if m and ":" not in text:
            while stack and stack[-1][0] >= indent:
                stack.pop()
            parent = stack[-1][1] if stack else None
            w = Widget(m.group(1), m.group(3), n, parent)
            widgets.append(w)
            stack.append((indent, w))
            continue
        m = PROP_LINE.match(raw)
        if m and stack:
            key, value = m.group(1).lstrip("!"), m.group(2).strip()
            stack[-1][1].props.setdefault(key, value)
            if key == "id":
                stack[-1][1].id = value
    return widgets


def check_file(path, *, scan_ids, ignore_unknown_lua_ids=False):
    errors = []
    widgets = parse(path)
    children = {}
    for w in widgets:
        children.setdefault(id(w.parent), []).append(w)

    seen = {}
    for w in widgets:
        if not w.id:
            continue
        if w.id in seen:
            errors.append(f"linha {w.line}: id '{w.id}' repetido no arquivo (antes na linha {seen[w.id]})")
        seen[w.id] = w.line
        scan_ids.add(w.id)

    for siblings in children.values():
        ids = {}
        for w in siblings:
            if w.id:
                if w.id in ids:
                    errors.append(f"linha {w.line}: dois irmaos com id '{w.id}'")
                ids[w.id] = w.line

    for w in widgets:
        sibling_ids = {s.id for s in children.get(id(w.parent), []) if s.id}
        for key, value in w.props.items():
            if not key.startswith("anchors."):
                continue
            prop = key.split(".", 1)[1]
            if prop not in ANCHOR_KEYS:
                errors.append(f"linha {w.line}: anchor desconhecido '{key}'")
                continue
            target = value if prop == "centerIn" else value.split(".")[0].strip()
            if target in SPECIAL_TARGETS or target in sibling_ids:
                continue
            errors.append(
                f"linha {w.line}: '{key}: {value}' aponta para '{target}', que nao e' irmao "
                f"deste widget (anchors so' resolvem parent/prev/next/irmaos)"
            )

    for w in widgets:
        src = w.props.get("image-source")
        if not src:
            continue
        value = src
        if value.startswith("/"):
            candidate = ROOT / "data" / value[1:]
        else:
            candidate = path.parent / value
        if not candidate.suffix:
            candidate = candidate.with_suffix(".png")
        if not candidate.exists():
            errors.append(f"linha {w.line}: image-source '{value}' nao encontrada ({candidate})")

    return errors


def main(argv):
    targets = [pathlib.Path(a) for a in argv] or [pathlib.Path(".")]
    files, lua_files = [], []
    for t in targets:
        if t.is_dir():
            files.extend(sorted(t.rglob("*.otui")))
            lua_files.extend(sorted(t.rglob("*.lua")))
        else:
            files.append(t)
            if t.suffix == ".lua":
                lua_files.append(t)

    scan_ids = set()
    bad = 0
    for path in files:
        errors = check_file(path, scan_ids=scan_ids)
        if errors:
            bad += 1
            print(f"[!] {path}")
            for e in errors[:15]:
                print(f"      {e}")
        else:
            print(f"[ok] {path}")

    missing = {}
    for lua in lua_files:
        text = lua.read_text(encoding="utf-8", errors="surrogateescape")
        for ident in LUA_ID.findall(text):
            if ident and ident not in scan_ids:
                missing.setdefault(ident, set()).add(lua.name)
    if missing:
        bad += 1
        print("\n[!] ids pedidos pelo lua que nao existem em nenhum .otui varrido:")
        for ident, where in sorted(missing.items()):
            print(f"      {ident}   ({', '.join(sorted(where))})")

    print(f"\n{len(files)} otui, {len(lua_files)} lua varridos, {bad} com problema")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
