#!/usr/bin/env python3
"""A woven linen (window/shell.lua's page backdrop, the Character page's):
a plain weave, warp and weft crossing over and under, each thread a little
heavier or lighter than its neighbours (the slubs of real linen), with a
fine fibre over it. White on clear, tiling without a seam, so the game
tints it (the class's colour) and sets how much it shows.

    python3 art/character/gen_linen.py   -> media/character/linen.tga (128x128)

PITCH pixels a thread (PITCH divides SIZE, so the tile meets itself). A
thread is lit along its middle and falls away at its edges, and the one on
top dims where it dives under the next: the weave's shading. (2026-11-26,
the user's: "woven linen in the class's colour", threads twice the first
cross-hatch's size.)
"""
import math
import os
import random
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
import export  # noqa: E402

SIZE, PITCH = 128, 8
SEED = 3


def weave(size, pitch, seed=SEED):
    rnd = random.Random(seed)
    threads = size // pitch
    warp = [rnd.uniform(.55, 1) for _ in range(threads)]      # the slubs, each thread its weight
    weft = [rnd.uniform(.55, 1) for _ in range(threads)]
    fibre = [[rnd.gauss(0, .07) for _ in range(size)] for _ in range(size)]
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            i, j = x // pitch, y // pitch
            u, v = (x % pitch + .5) / pitch, (y % pitch + .5) / pitch
            if (i + j) % 2 == 0:
                # the warp on top: round across it, dimming where it dives
                value = math.sin(math.pi * u) * warp[i] * (.5 + .5 * math.sin(math.pi * v))
            else:
                value = math.sin(math.pi * v) * weft[j] * (.5 + .5 * math.sin(math.pi * u))
            value = max(0.0, min(1.0, value + fibre[y][x]))
            px[x, y] = (255, 255, 255, int(round(255 * value)))
    return img


def main():
    out = os.path.join(ROOT, "WoW", "Interface", "AddOns", "MedalUI", "media", "character")
    os.makedirs(out, exist_ok=True)
    export.to_tga(weave(SIZE, PITCH), os.path.join(out, "linen.tga"))
    print(os.path.join(out, "linen.tga"))


if __name__ == "__main__":
    main()
