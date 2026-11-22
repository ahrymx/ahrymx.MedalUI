#!/usr/bin/env python3
"""mdlui_Tooltips' quest badge glyphs: one small white shape a file, tinted in
the game by its badge's word colour (SetVertexColor).

    python3 art/tooltips/gen_glyphs.py   -> assets/tooltips/glyph-*.png and the
                                            companion's art/glyph-*.tga

progress  an hourglass                  ready     a tick
completed a tick in a ring              failed    a cross
repeat    an arrow circling round       chain     two links

The level has none: its chip reads "LvL 38" in the chip's own font.

Drawn at 8x and shrunk to 32x32, so the edges are smooth at 12px.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
from export import to_tga  # noqa: E402

ASSETS = os.path.join(ROOT, "assets", "tooltips")
MEDIA = os.path.join(ROOT, "WoW", "Interface", "AddOns", "mdlui_Tooltips", "art")

SIZE, K = 32, 8
N = SIZE * K
W = 255


def canvas():
    img = Image.new("L", (N, N), 0)
    return img, ImageDraw.Draw(img)


def s(v):
    """32px units to the big canvas"""
    return v * K


def line(d, pts, width):
    pts = [(s(x), s(y)) for x, y in pts]
    d.line(pts, fill=W, width=int(s(width)), joint="curve")
    r = s(width) / 2
    for x, y in pts:                                   # round caps
        d.ellipse([x - r, y - r, x + r, y + r], fill=W)






def progress():
    img, d = canvas()
    line(d, [(8, 4), (24, 4)], 3)
    line(d, [(8, 28), (24, 28)], 3)
    d.polygon([(s(9.5), s(6)), (s(22.5), s(6)), (s(16), s(16))], outline=W, width=int(s(2.4)))
    d.polygon([(s(16), s(16)), (s(22.5), s(26)), (s(9.5), s(26))], outline=W, width=int(s(2.4)))
    d.polygon([(s(12), s(25)), (s(20), s(25)), (s(16), s(19))], fill=W)   # the sand fallen
    return img


def ready():
    img, d = canvas()
    line(d, [(6, 17), (13, 24), (26, 9)], 4.2)
    return img


def completed():
    img, d = canvas()
    d.ellipse([s(2), s(2), s(30), s(30)], outline=W, width=int(s(2.6)))
    line(d, [(10, 16.5), (14.5, 21), (22.5, 11.5)], 3.4)
    return img


def failed():
    img, d = canvas()
    line(d, [(8, 8), (24, 24)], 4.2)
    line(d, [(24, 8), (8, 24)], 4.2)
    return img


def repeat():
    img, d = canvas()
    d.arc([s(5), s(5), s(27), s(27)], 40, 320, fill=W, width=int(s(3.4)))
    # the arrowhead at the arc's end (320 degrees, clockwise from three o'clock)
    a = math.radians(320)
    cx, cy, r = 16 + 11 * math.cos(a), 16 + 11 * math.sin(a), 6
    d.polygon([(s(cx + r * 0.9), s(cy + 1)), (s(cx - r * 0.7), s(cy - r * 0.2)), (s(cx + 1), s(cy - r))], fill=W)
    return img


def chain():
    """two rounded links, crossing at 45 degrees"""
    big = Image.new("L", (N, N), 0)
    for cx in (9.5, 22.5):
        link = Image.new("L", (N, N), 0)
        d = ImageDraw.Draw(link)
        d.rounded_rectangle([s(cx - 8), s(10.5), s(cx + 8), s(21.5)], radius=s(5.5), outline=W, width=int(s(2.8)))
        big = Image.fromarray(np.maximum(np.array(big), np.array(link)))
    return big.rotate(-45, resample=Image.BICUBIC, center=(N / 2, N / 2))


GLYPHS = {"progress": progress, "ready": ready,
          "completed": completed, "failed": failed, "repeat": repeat, "chain": chain}


def main():
    os.makedirs(ASSETS, exist_ok=True)
    for name, draw in GLYPHS.items():
        alpha = draw().resize((SIZE, SIZE), Image.LANCZOS)
        img = Image.merge("RGBA", (Image.new("L", alpha.size, W),) * 3 + (alpha,))
        img.save(os.path.join(ASSETS, "glyph-%s.png" % name))
        to_tga(img, os.path.join(MEDIA, "glyph-%s.tga" % name))
        print("glyph-" + name, img.size)


if __name__ == "__main__":
    main()
