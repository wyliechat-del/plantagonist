"""Joins preview frames into one picture (side by side) or an animated GIF.
  python3 sheet.py OUT.png a.png b.png ...
  python3 sheet.py --gif OUT.gif a.png b.png ...
"""
import sys

from PIL import Image

args = sys.argv[1:]
if args[0] == "--gif":
    out, files = args[1], args[2:]
    frames = [Image.open(f).convert("RGB") for f in files]
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=45, loop=0)
else:
    out, files = args[0], args[1:]
    imgs = [Image.open(f).convert("RGB") for f in files]
    w, h = imgs[0].size
    sheet = Image.new("RGB", (w * len(imgs), h), "white")
    for i, im in enumerate(imgs):
        sheet.paste(im, (i * w, 0))
    sheet.save(out)
