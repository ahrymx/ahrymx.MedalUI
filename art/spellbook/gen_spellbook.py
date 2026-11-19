#!/usr/bin/env python3
"""The spellbook's page (spells/spellbook.lua; 2026-11-19, mockup B of
/workspace/bookpage-sheet.png), original:

- parchment.tga (256x256): a dark, aged parchment, its colours baked in,
  seamless so the code tiles it: soft cloudy mottling in three sizes,
  faint fibres and a few blurred blotches, all wrapping at the edges (the
  page's darkening at its edges and its spine's shadow are the code's);
- dots.tga (8x2): white, its alpha a dot every 4 px along a row: the
  ledger's dotted rule between the spells, tiled along its length.

    python3 art/spellbook/gen_spellbook.py   -> media/spellbook/parchment, dots (.tga)
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
import export  # noqa: E402

OUT = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin", "media", "spellbook")
SIZE = 256
BASE, DARK = (70, 55, 34), (28, 22, 14)        # the page's light and its shadow


def wrapped_noise(size, cells, rng):
    """Smooth noise that tiles: a random grid of cells, itself tiled 3x3,
    resized, and its middle kept."""
    grid = rng.random((cells, cells))
    big = np.tile(grid, (3, 3))
    img = Image.fromarray((big * 255).astype("uint8")).resize((size * 3, size * 3), Image.BICUBIC)
    return np.asarray(img).astype(float)[size:2 * size, size:2 * size] / 255


def wrapped(draw_fn, size):
    """Draw on a canvas three times the size, then fold it onto one tile
    (each mark lands where it would wrap)."""
    big = Image.new("RGBA", (size * 3, size * 3), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(big), size)
    big = big.filter(ImageFilter.GaussianBlur(2))
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for i in range(3):
        for j in range(3):
            tile.alpha_composite(big.crop((i * size, j * size, (i + 1) * size, (j + 1) * size)))
    return tile


def parchment():
    rng = np.random.default_rng(7)
    n = (0.5 * wrapped_noise(SIZE, 6, rng) + 0.3 * wrapped_noise(SIZE, 20, rng)
         + 0.2 * wrapped_noise(SIZE, 85, rng))
    t = np.clip(0.55 + 0.45 * (n - 0.5) * 1.6, 0, 1)
    b, d = np.array(BASE, float), np.array(DARK, float)
    img = Image.fromarray((d + (b - d) * t[..., None]).astype("uint8")).convert("RGBA")
    r = random.Random(7)

    def marks(dr, size):
        for _ in range(int(size * size / 2500) * 9):
            x, y = r.randrange(size, 2 * size), r.randrange(size, 2 * size)
            length, a = r.randrange(6, 22), r.random() * math.pi
            dr.line((x, y, x + length * math.cos(a), y + length * math.sin(a)), fill=DARK + (22,), width=1)
        for _ in range(3):
            x, y, rad = r.randrange(size, 2 * size), r.randrange(size, 2 * size), r.randrange(30, 70)
            dr.ellipse((x - rad, y - rad, x + rad, y + rad), fill=DARK + (26,))
    img.alpha_composite(wrapped(marks, SIZE))
    return img


def dots():
    img = Image.new("RGBA", (8, 2), (255, 255, 255, 0))
    for x in (0, 4):
        for y in (0, 1):
            img.putpixel((x, y), (255, 255, 255, 255))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    export.to_tga(parchment(), os.path.join(OUT, "parchment.tga"))
    export.to_tga(dots(), os.path.join(OUT, "dots.tga"))
    print(OUT)


if __name__ == "__main__":
    main()
