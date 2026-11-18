#!/usr/bin/env python3
"""The talents window's effects (spells/talents.lua), white, their alpha
soft, tinted and sized by the code:

- sheen.tga (64x64): a diagonal band of light across a maxed talent's icon,
  from its lower left to its upper right, nearer the top-left corner;
- beam.tga (64x16): a lit line's halo, soft across its height and even
  along it (a Line's texture runs along its length, its height across the
  line's thickness);
- glow.tga (128x128): the glow behind a talent, shown two icons wide:
  full round the icon's square (its middle third), then fading softly to
  nothing at the edge, so most of it shows past the icon (the character
  window's glow, faint from its middle out, all but hid under it).

    python3 art/talents/gen_talents.py   -> media/talents/sheen.tga, beam.tga, glow.tga
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
import export  # noqa: E402

OUT = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin", "media", "talents")


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def sheen(n=64):
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    px = img.load()
    for y in range(n):
        for x in range(n):
            # distance from the band's middle, the diagonal x + y = 0.55 n, in a share of n
            d = abs((x + y) / n - 0.55)
            a = 1 - smooth(d / 0.2)
            px[x, y] = (255, 255, 255, int(round(255 * a)))
    return img


def beam(w=64, h=16):
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    px = img.load()
    for y in range(h):
        t = 1 - abs((y + 0.5) / h * 2 - 1)        # 1 in the middle, 0 at the edges
        a = smooth(t) ** 1.5
        for x in range(w):
            px[x, y] = (255, 255, 255, int(round(255 * a)))
    return img


def glow(n=128, core=0.5, corner=0.25):
    """core: the icon's half size, as a share of the texture's half; corner: its rounding,
    as a share of the core."""
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    px = img.load()
    c = (n - 1) / 2
    r = core * corner
    for y in range(n):
        for x in range(n):
            u, v = abs(x - c) / (n / 2), abs(y - c) / (n / 2)
            # the distance out from a rounded square of half size core
            qx, qy = max(u - (core - r), 0), max(v - (core - r), 0)
            d = max(0.0, (qx * qx + qy * qy) ** 0.5 - r)
            t = d / (1 - core)
            a = (1 - smooth(t)) ** 1.1
            px[x, y] = (255, 255, 255, int(round(255 * a)))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, img in (("sheen", sheen()), ("beam", beam()), ("glow", glow())):
        export.to_tga(img, os.path.join(OUT, name + ".tga"))
        print(os.path.join(OUT, name + ".tga"))


if __name__ == "__main__":
    main()
