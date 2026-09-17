#!/usr/bin/env python3
"""Linter de OTUI (OTML) para este client.

Reproduz as regras do parser real para pegar os erros que so aparecem no boot
como ``failed to load UI from 'x.otui': ...``:

  * indentacao com tab ou numero impar de espacos
    (OTMLParser::getLineDepth, src/framework/otml/otmlparser.cpp);
  * salto de indentacao invalido (OTMLParser::parseLine);
  * comentario escrito com '-': em OTUI **so '//' e comentario**. Uma linha
    iniciada por '-' e sem ':' vira um no sem tag, e o client estoura
    "'' is not a defined style" (uimanager.cpp:512), derrubando o arquivo
    inteiro -- junto com os widgets que ele define (foi o que apagou o botao
    do menu ao adicionar uma linha '-- ...' no game_menu.otui);
  * estilo (ou base de estilo) nao definido
    (UIManager::createWidgetFromOTML / importStyleFromOTML);
  * mais de um widget principal no mesmo arquivo.

Estilos comecando por "UI" sao definidos automaticamente pelo client
(UIManager::getStyle), entao nao entram na checagem. A tabela de estilos e
montada a partir de todos os arquivos varridos, ou seja, e mais permissiva que
a ordem real de carregamento -- serve para pegar nome errado, nao ordem.

Uso:
    python tools/check_otui.py                # varre modules/, mods/ e data/styles/
    python tools/check_otui.py <arquivo.otui> [arquivo.otui ...]

Sai com codigo 1 se achar qualquer problema.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCAN_DIRS = ("modules", "mods", "data/styles")

STYLE_DECL = re.compile(r"^(?P<name>[^<]+)<(?P<base>[^<]+)$")


class Problem:
    def __init__(self, path: Path, line: int, text: str, reason: str) -> None:
        self.path = path
        self.line = line
        self.text = text
        self.reason = reason

    def __str__(self) -> str:
        where = f"{self.path}:{self.line}" if self.line else str(self.path)
        if self.text:
            where += f"  ->  {self.text.strip()!r}"
        return f"{where}: {self.reason}"


class Node:
    __slots__ = ("tag", "unique", "value", "line", "text", "children")

    def __init__(self, tag: str, unique: bool, value: str, line: int, text: str) -> None:
        self.tag = tag
        self.unique = unique
        self.value = value
        self.line = line
        self.text = text
        self.children: list["Node"] = []


def parse_otml(path: Path) -> tuple[list[Node], list[Problem]]:
    """Replica OTMLParser::parseLine/parseNode/getLineDepth."""
    roots: list[Node] = []
    problems: list[Problem] = []
    containers: dict[int, list[Node]] = {0: roots}
    current_depth = 0
    previous: Node | None = None
    current_container: list[Node] = roots

    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    idx = 0
    while idx < len(lines):
        raw = lines[idx]
        idx += 1
        lineno = idx
        line = raw.rstrip("\r")

        spaces = 0
        while spaces < len(line) and line[spaces] == " ":
            spaces += 1
        depth = spaces // 2

        if spaces < len(line) and line[spaces] == "\t":
            problems.append(Problem(path, lineno, line, "indentacao com tab nao e permitida"))
            continue
        if spaces % 2 != 0:
            problems.append(Problem(path, lineno, line, "indentacao deve ser multipla de 2 espacos"))
            continue

        data = line.strip()
        if not data:
            continue
        if data.startswith("//"):
            continue

        # parseLine(): resolve o container (pai) pelo nivel de indentacao
        if depth == current_depth + 1:
            if previous is None:
                problems.append(Problem(path, lineno, line, "salto de indentacao invalido"))
                continue
            current_container = previous.children
            containers[depth] = current_container
        elif depth < current_depth:
            current_container = containers.get(depth, roots)
        elif depth != current_depth:
            problems.append(Problem(path, lineno, line, f"salto de indentacao invalido (depth {depth})"))
            continue
        current_depth = depth

        # parseNode(): unique depende so de existir ':' (OTMLParser::parseNode
        # roda node->setUnique(dotsPos != npos) fora do if do '-')
        has_colon = ":" in data
        if data[0] == "-":
            tag, value, unique = "", data[1:].strip(), has_colon
        elif has_colon:
            tag, _, value = data.partition(":")
            tag, value, unique = tag.strip(), value.strip(), True
        else:
            tag, value, unique = data, "", False

        node = Node(tag, unique, value, lineno, line)
        current_container.append(node)
        containers[depth] = current_container
        previous = node

        # valor multilinha (|, |-, |+): consome as linhas seguintes
        # (OTMLParser::parseNode); nessas linhas nao vale a validacao de indentacao
        if value in ("|", "|-", "|+"):
            multi = []
            while idx < len(lines):
                nxt = lines[idx].rstrip("\r")
                sp = 0
                while sp < len(nxt) and nxt[sp] == " ":
                    sp += 1
                if sp // 2 > current_depth:
                    multi.append(nxt[(current_depth + 1) * 2:])
                    idx += 1
                elif nxt.strip():
                    break
                else:
                    idx += 1
                multi.append("\n")
            node.value = "".join(multi)
            node.text = line

    return roots, problems


def style_index(files: list[Path]) -> set[str]:
    names: set[str] = set()
    for f in files:
        try:
            roots, _ = parse_otml(f)
        except OSError:
            continue
        for node in roots:
            m = STYLE_DECL.match(node.tag)
            if m:
                names.add(m.group("name").strip())
    return names


def check_file(path: Path, styles: set[str]) -> list[Problem]:
    roots, problems = parse_otml(path)

    def defined(name: str) -> bool:
        name = name.strip()
        return name in styles or name.startswith("UI")

    def check_children(node: Node) -> None:
        for child in node.children:
            if child.unique:
                continue
            if not child.tag:
                problems.append(Problem(
                    path, child.line, child.text,
                    "no sem tag -> \"'' is not a defined style\". Em OTUI o comentario e '//' "
                    "(linha iniciada por '-' quebra o arquivo inteiro)",
                ))
            elif not defined(child.tag):
                problems.append(Problem(path, child.line, child.text, f"'{child.tag}' is not a defined style"))
            check_children(child)

    mains = 0
    for node in roots:
        m = STYLE_DECL.match(node.tag)
        if m:
            base = m.group("base").strip()
            if not defined(base):
                problems.append(Problem(path, node.line, node.text, f"base de estilo '{base}' nao definida"))
            check_children(node)
            continue
        mains += 1
        if not defined(node.tag):
            problems.append(Problem(path, node.line, node.text, f"'{node.tag}' is not a defined style"))
        check_children(node)

    if mains > 1:
        problems.append(Problem(path, 0, "", "mais de um widget principal no mesmo arquivo .otui"))
    return problems


def scan_targets() -> list[Path]:
    out: list[Path] = []
    for d in SCAN_DIRS:
        base = ROOT / d
        if base.is_dir():
            out.extend(sorted(base.rglob("*.otui")))
    return out


def targets(argv: list[str]) -> tuple[list[Path], list[Path]]:
    """(arquivos a checar, arquivos que alimentam a tabela de estilos)."""
    scan = scan_targets()
    if not argv:
        return scan, scan
    explicit: list[Path] = []
    for arg in argv:
        p = Path(arg)
        if p.is_dir():
            explicit.extend(sorted(p.rglob("*.otui")))
        else:
            explicit.append(p)
    # a tabela de estilos sempre vem do projeto inteiro: os widgets do core
    # (Label, ScrollablePanel, ...) vivem em data/styles
    return explicit, scan + explicit


def label(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def printable(text: str) -> str:
    """Evita UnicodeEncodeError no console do Windows (arquivos em latin-1)."""
    enc = getattr(sys.stdout, "encoding", None) or "utf-8"
    return text.encode(enc, "replace").decode(enc, "replace")


def main(argv: list[str]) -> int:
    files, index_files = targets(argv)
    styles = style_index(index_files)
    bad = 0
    for f in files:
        if not f.exists():
            print(f"  ?? {f} (nao existe)")
            continue
        problems = check_file(f, styles)
        if problems:
            bad += 1
            print(printable(f"FAIL {label(f)}"))
            for p in problems:
                print(printable(f"       {p}"))
    print(f"RESULT: {len(files) - bad}/{len(files)} arquivos .otui ok")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
