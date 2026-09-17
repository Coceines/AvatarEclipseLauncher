# Generates the loading-screen art with pure stdlib (no PIL needed):
#   img/vignette.png   - radial fade-to-black (transparent center -> black edges)
#   img/bar_track.png  - rounded track (24x24, radius 7, 1px border) for 9-slice
#   img/bar_fill.png   - rounded blue fill with subtle vertical gradient
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'img')
os.makedirs(OUT, exist_ok=True)


def write_png(path, w, h, pix):
    raw = bytearray()
    for y in range(h):
        raw.append(0)  # filter: None
        for x in range(w):
            raw.extend(pix(x, y))

    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + \
            struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

    ihdr = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)  # 8-bit RGBA
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) + \
        chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)
    print('wrote %s (%d bytes)' % (path, os.path.getsize(path)))


# ---- 1) vignette: fade OUT from inside to outside -------------------------
W = 1024


def vignette(x, y):
    dx = (x - (W - 1) / 2.0) / (W / 2.0)
    dy = (y - (W - 1) / 2.0) / (W / 2.0)
    r = (dx * dx + dy * dy) ** 0.5 / (2 ** 0.5)  # 0 center -> 1 corner
    t = (r - 0.26) / 0.74
    if t < 0:
        t = 0.0
    elif t > 1:
        t = 1.0
    a = int(255 * (t * t * (3 - 2 * t)))  # smoothstep
    return (0, 0, 0, a)


write_png(os.path.join(OUT, 'vignette.png'), W, W, vignette)


# ---- 2/3) rounded 9-slice bar parts --------------------------------------
def rounded_dist(x, y, rad, w, h):
    x0, y0 = rad, rad
    x1, y1 = w - 1 - rad, h - 1 - rad
    cx = min(max(x, x0), x1)
    cy = min(max(y, y0), y1)
    return ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5


B = 24
RAD = 7


def bar_track(x, y):
    d = rounded_dist(x, y, RAD, B, B)
    if d > RAD:
        return (0, 0, 0, 0)
    if d > RAD - 1:
        return (60, 68, 86, 255)      # border
    return (13, 16, 22, 255)          # track fill


def bar_fill(x, y):
    d = rounded_dist(x, y, RAD, B, B)
    if d > RAD:
        return (0, 0, 0, 0)
    if d > RAD - 1:
        return (147, 197, 253, 255)   # light border
    t = y / (B - 1.0)
    r = int(59 + (37 - 59) * t)       # #3b82f6 -> #2554b4
    g = int(130 + (84 - 130) * t)
    b = int(246 + (180 - 246) * t)
    return (r, g, b, 255)


write_png(os.path.join(OUT, 'bar_track.png'), B, B, bar_track)
write_png(os.path.join(OUT, 'bar_fill.png'), B, B, bar_fill)
print('done.')
