#!/usr/bin/env python3
"""The medallions' bezel (2026-11-26, the user's pick, "5 · Glint" of
/workspace/bezel-mock-sheet.png): slim, a dark keyline outside, a gold line,
a dark line inside; and its glint, a bright catch at the upper left.

    python3 art/window/gen_bezel.py   -> media/window/bezel-{s,m,l}.tga, bezel-glint-{s,m,l}.tga

The bezel is white (its line) and black (its keylines) on clear: the game
tints it by vertex colour, the caller's gold (dark at rest, light lit), the
keylines staying dark. The glint is white on clear, drawn over the line in
ADD, tinted the light gold. Inside the bezel is clear, for the medallion's
face or icon.

A texture scales with its medallion, so each size class has its own, its
widths in points right at the class's middle size (SIZES): the keyline
1.0, the line 1.6, the inner line 0.8 (bezel.lua picks the class).
"""
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
import export  # noqa: E402

SIZES = {"s": 20.0, "m": 32.0, "l": 50.0}      # each class's middle size, points
TEX = 128
KEY, LINE, INNER = 1.0, 1.6, 0.8
SS = 4


def glint_at(t, lx):
    """the glint's strength at t (0 top .. 1 foot), lx (-1 left .. 1 right)"""
    return max(0.0, 1 - ((t - 0.12) ** 2 * 9 + (lx + 0.55) ** 2 * 2.2)) ** 2


def render(size):
    unit = TEX / size                            # texels a point
    c = TEX / 2
    r_out = size / 2
    bez = Image.new("RGBA", (TEX, TEX), (0, 0, 0, 0))
    gl = Image.new("RGBA", (TEX, TEX), (255, 255, 255, 0))
    pb, pg = bez.load(), gl.load()
    for y in range(TEX):
        for x in range(TEX):
            v = a = g = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    dx = (x + (sx + 0.5) / SS - c) / unit
                    dy = (y + (sy + 0.5) / SS - c) / unit
                    depth = r_out - math.hypot(dx, dy)
                    if depth < 0 or depth >= KEY + LINE + INNER:
                        continue
                    if depth < KEY:
                        a += 0.9
                    elif depth < KEY + LINE:
                        v += 1
                        a += 1
                        g += glint_at((dy / r_out + 1) / 2, dx / r_out)
                    else:
                        a += 0.85
            n = SS * SS
            if a:
                # premultiplied over the samples: the line white, the keylines black
                level = int(round(255 * v / a))
                pb[x, y] = (level, level, level, int(round(255 * a / n)))
            if g:
                pg[x, y] = (255, 255, 255, int(round(255 * min(1.0, g / n))))
    return bez, gl


def main():
    out = os.path.join(ROOT, "WoW", "Interface", "AddOns", "MedalUI", "media", "window")
    os.makedirs(out, exist_ok=True)
    for name, size in SIZES.items():
        bez, gl = render(size)
        for stem, img in (("bezel-", bez), ("bezel-glint-", gl)):
            path = os.path.join(out, stem + name + ".tga")
            export.to_tga(img, path)
            print(path)


if __name__ == "__main__":
    main()
