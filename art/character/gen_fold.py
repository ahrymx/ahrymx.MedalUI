#!/usr/bin/env python3
"""A list heading's fold mark (character/list.lua's plate): a solid
triangle pointing down, white for code to tint, turned a quarter (-90
degrees, pointing right) while its heading is folded.

    python3 art/character/gen_fold.py   -> media/character/fold.tga (16x16)

Drawn at 8x and scaled down, so its edges are smooth; centred on the
texture, so the turn keeps it in place.
"""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
import export  # noqa: E402

SIZE, UP = 16, 8


def fold(size):
    big = size * UP
    img = Image.new("RGBA", (big, big), (255, 255, 255, 0))
    d = ImageDraw.Draw(img)
    # 10 wide and 6 tall of the 16, its middle on the texture's
    w, h = 10 * UP, 6 * UP
    left, top = (big - w) / 2, (big - h) / 2
    d.polygon([(left, top), (left + w, top), (big / 2, top + h)], fill=(255, 255, 255, 255))
    return img.resize((size, size), Image.LANCZOS)


def main():
    out = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin", "media", "character")
    export.to_tga(fold(SIZE), os.path.join(out, "fold.tga"))
    print(os.path.join(out, "fold.tga"))


if __name__ == "__main__":
    main()
