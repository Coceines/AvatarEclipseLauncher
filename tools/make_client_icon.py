"""Regenerates src/otcicon.ico from data/images/clienticon.png.

The .ico is embedded into the exe at compile time (referenced by the .rc
files). A multi-size icon keeps it crisp on taskbar, title bar and desktop.
"""
import os
from PIL import Image, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'data', 'images', 'icon.png')
OUT = os.path.join(ROOT, 'src', 'otcicon.ico')

img = Image.open(SRC)
img = ImageOps.exif_transpose(img)
if img.mode != 'RGBA':
    img = img.convert('RGBA')

# downscale big sources gracefully: crop to square then high-quality resize
w, h = img.size
if w != h:
    s = min(w, h)
    img = img.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2))

sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
img.save(OUT, format='ICO', sizes=sizes)
print('wrote %s' % OUT)

# sanity re-open
chk = Image.open(OUT)
print('icon frames:', getattr(chk, 'n_frames', 1))
