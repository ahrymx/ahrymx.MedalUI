#!/usr/bin/env python3
"""The game menu's Social window (window/gamemenu.lua): a honeycomb drawn
behind its lists, the friends' and the guild's alike.

    python3 art/widgets/gen_social.py   -> media/gamemenu-honeycomb.tga

512x512, white lines on nothing (the alpha is the art), so the game tints
it gold with SetVertexColor and fades it down the list with SetGradient.
It is cropped from its top left at a texel a point, never stretched, so its
cells keep their shape at any list height; a list taller than it is scaled
up evenly. Pointy-topped cells, a side of 16, the lines 1.25 wide, drawn at
four times the size and brought down, so their edges are soft.
"""
import math
import os
import subprocess

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
MEDIA = os.path.join(ROOT, "WoW", "Interface", "AddOns", "MedalUI", "media", "gamemenu-honeycomb.tga")
OUT = os.path.join(HERE, "render")

SIZE, SIDE, LINE, SS = 512, 16, 1.25, 4


def honeycomb():
    big = SIZE * SS
    im = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(im)
    r = SIDE * SS
    w = math.sqrt(3) * r                     # a cell across
    step_y = 1.5 * r                         # a row down
    lw = max(1, round(LINE * SS))
    rows = int(big / step_y) + 2
    cols = int(big / w) + 2
    for row in range(-1, rows):
        cy = row * step_y
        shift = (w / 2) if row % 2 else 0
        for col in range(-1, cols):
            cx = col * w + shift
            pts = [(cx + r * math.cos(math.radians(60 * k - 90)),
                    cy + r * math.sin(math.radians(60 * k - 90))) for k in range(7)]
            d.line(pts, fill=255, width=lw, joint="curve")
    alpha = im.resize((SIZE, SIZE), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, "gamemenu-honeycomb.png")
    honeycomb().save(tmp)
    subprocess.run(["magick", tmp, "-define", "tga:compression=none", MEDIA], check=True)
    print(MEDIA)


if __name__ == "__main__":
    main()
