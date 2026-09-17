"""Converts the loading images (jpg/jpeg) in data/loadingimages to PNG.

The OTClient texture loader only supports PNG/APNG, so the jpg files were
invisible on the loading screen. Originals are kept.
"""
import os
from PIL import Image, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'data', 'loadingimages')
SRC = os.path.normpath(SRC)

converted = 0
for name in sorted(os.listdir(SRC)):
    low = name.lower()
    if not (low.endswith('.jpg') or low.endswith('.jpeg')):
        continue
    src = os.path.join(SRC, name)
    out = os.path.join(SRC, os.path.splitext(name)[0] + '.png')
    img = Image.open(src)
    img = ImageOps.exif_transpose(img)  # respect rotation metadata
    if img.mode not in ('RGB', 'RGBA'):
        img = img.convert('RGB')
    img.save(out, 'PNG', optimize=True)
    print('converted %s -> %s (%dx%d)' % (name, os.path.basename(out), img.width, img.height))
    converted += 1

print('done: %d images' % converted)
