#!/usr/bin/env python3
"""Gera a bolinha azul (huntdot.png) usada no minimap do módulo Hunt Waypoint.

PNG 9x9 RGBA, circulo azul com anel de contorno mais escuro.
Sem dependencias externas (zlib + struct da stdlib).

Uso:  python tools/make_huntdot.py
"""
import os
import struct
import zlib

W = H = 9
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "data", "images", "game", "minimap", "huntdot.png")

INNER = (63, 123, 255, 255)    # azul claro (centro)
RING = (30, 70, 160, 255)      # azul escuro (contorno)
TRANSP = (0, 0, 0, 0)

CX = (W - 1) / 2.0
CY = (H - 1) / 2.0


def pixel(x, y):
    d = ((x - CX) ** 2 + (y - CY) ** 2) ** 0.5
    if d <= 2.0:
        return INNER
    if d <= 3.0:
        return RING
    return TRANSP


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def main():
    raw = bytearray()
    for y in range(H):
        raw.append(0)  # filtro None
        for x in range(W):
            raw.extend(pixel(x, y))

    ihdr = struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "wb") as f:
        f.write(png)
    print("OK ->", OUT, os.path.getsize(OUT), "bytes")


if __name__ == "__main__":
    main()
