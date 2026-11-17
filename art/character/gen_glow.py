#!/usr/bin/env python3
"""A soft light (character/paperdoll.lua's stage: the light behind the
model, the glow on the floor at its feet): white, its alpha falling off
smoothly from the middle to nothing at the edge, so a tint and a stretch
make any coloured light or oval without a ring or a band showing.

    python3 art/character/gen_glow.py   -> media/character/glow.tga (128x128)

The falloff is a smoothstep on the distance, eased again (t^2), so the
middle is full and the edge comes to nothing with no line where it ends.
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


def glow(size):
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = min(1.0, math.hypot(x - c, y - c) / (size / 2))
            t = 1 - d
            a = t * t * (3 - 2 * t)          # smoothstep
            px[x, y] = (255, 255, 255, int(round(255 * a * a)))
    return img


def main():
    out = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin", "media", "character")
    os.makedirs(out, exist_ok=True)
    export.to_tga(glow(SIZE), os.path.join(out, "glow.tga"))
    print(os.path.join(out, "glow.tga"))


if __name__ == "__main__":
    main()
