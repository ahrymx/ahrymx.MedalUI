#!/usr/bin/env python3
"""A docked or floating window's head medallion's ring (window/shell.lua's
Medal; 2026-11-26, /workspace/swell-mock-2.png, the user's pick): a
bevelled band, lit at its top and falling to shadow at its foot, a dark
keyline outside it and a fine dark line inside. Its brightness is baked as
grey on white, so the window tints it (the theme's gold) by its vertex
colour; inside it is clear, for the medallion's face.

    python3 art/window/gen_medallion.py   -> media/window/medallion-ring.tga (128x128)

Measured in the medallion's own points (MEDAL = 46 across): the keyline
0.8, the band 3.7, the inner line 0.7 (the band's inside, 18.5 from the
middle, where the face shows).
"""
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
import export  # noqa: E402

SIZE = 128
MEDAL = 46.0                    # the medallion's width in points: the scale of the numbers below
KEY, BAND, INNER = 0.8, 3.7, 0.7
SS = 4                          # samples a texel, each way


def ring(size):
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    c = size / 2
    unit = size / MEDAL         # texels a point
    r_out = MEDAL / 2
    for y in range(size):
        for x in range(size):
            acc = [0.0, 0.0]        # brightness x alpha, alpha
            for sy in range(SS):
                for sx in range(SS):
                    dx = (x + (sx + 0.5) / SS - c) / unit
                    dy = (y + (sy + 0.5) / SS - c) / unit
                    d = math.hypot(dx, dy)
                    depth = r_out - d           # in from the outer edge, in points
                    if depth < 0 or depth > KEY + BAND + INNER:
                        continue
                    if depth < KEY:
                        v = 0.10                # the keyline: near black
                    elif depth < KEY + BAND:
                        # the band: lit at the top (dy < 0) to shadow at the foot,
                        # a crest along its middle
                        t = (dy / r_out + 1) / 2            # 0 top .. 1 foot
                        base = 1.0 - 0.68 * t ** 0.85
                        u = (depth - KEY) / BAND            # 0 outer .. 1 inner
                        crest = 1 - abs(u - 0.4) * 0.9
                        v = max(0.0, min(1.0, base * (0.72 + 0.28 * crest)))
                    else:
                        v = 0.06                # the inner line: dark
                    acc[0] += v
                    acc[1] += 1
            n = SS * SS
            if acc[1]:
                v = acc[0] / acc[1]
                g = int(round(255 * v))
                px[x, y] = (g, g, g, int(round(255 * acc[1] / n)))
    return img


def main():
    out = os.path.join(ROOT, "WoW", "Interface", "AddOns", "MedalUI", "media", "window")
    os.makedirs(out, exist_ok=True)
    export.to_tga(ring(SIZE), os.path.join(out, "medallion-ring.tga"))
    print(os.path.join(out, "medallion-ring.tga"))


if __name__ == "__main__":
    main()
