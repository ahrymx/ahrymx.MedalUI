#!/usr/bin/env python3
"""The game menu's filter as a vignette (window/gamemenu.lua): the world
behind the menu clear in its middle, darkening out to its edges and most at
its corners.

    python3 art/widgets/gen_vignette.py   -> media/gamemenu-vignette.tga

256x256, white on nothing (the alpha is the art), stretched over the world
the menu leaves (beside the docked panel, or the whole screen), so its oval
takes the shape of what it covers; the game tints it and sets its strength
with SetVertexColor. The alpha climbs on a smoothstep of the distance from
the middle, an edge's middle at 1 and a corner's at 1.41: clear to 0.35,
full past 1.3.
"""
import math
import os
import subprocess

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
MEDIA = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin", "media", "gamemenu-vignette.tga")
OUT = os.path.join(HERE, "render")

SIZE, CLEAR, FULL = 256, 0.35, 1.3


def smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def vignette():
    alpha = Image.new("L", (SIZE, SIZE), 0)
    half = (SIZE - 1) / 2
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot((x - half) / half, (y - half) / half)
            alpha.putpixel((x, y), round(255 * smooth(CLEAR, FULL, d)))
    out = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, "gamemenu-vignette.png")
    vignette().save(tmp)
    subprocess.run(["magick", tmp, "-define", "tga:compression=none", MEDIA], check=True)
    print(MEDIA)


if __name__ == "__main__":
    main()
