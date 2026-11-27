#!/usr/bin/env python3
"""The character stage's vignette (character/paperdoll.lua, 2026-11-27,
the user's pick A on the canvas "Character stage: floor + vignette"):
white, clear in an oval round the model and its alpha rising to full at
the edges and corners, so a black tint darkens the stage's rim and draws
the eye to the middle. Stretched over the whole stage.

    python3 art/character/gen_vignette.py   -> media/character/vignette.tga (128x128)

The oval is 78% of the width and 62% of the height across (the radii a
CSS ellipse would take), its middle a little above the stage's (46%).
Clear out to 52% of the way to the oval's edge, then a smoothstep up to
full there and beyond (the corners).
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
RX, RY, CY = 0.78, 0.62, 0.46
CLEAR = 0.52


def vignette(size):
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            u = ((x + 0.5) / size - 0.5) / RX
            v = ((y + 0.5) / size - CY) / RY
            t = min(1.0, max(0.0, (math.hypot(u, v) - CLEAR) / (1 - CLEAR)))
            a = t * t * (3 - 2 * t)          # smoothstep
            px[x, y] = (255, 255, 255, int(round(255 * a)))
    return img


def main():
    out = os.path.join(ROOT, "WoW", "Interface", "AddOns", "MedalUI", "media", "character")
    os.makedirs(out, exist_ok=True)
    export.to_tga(vignette(SIZE), os.path.join(out, "vignette.tga"))
    print(os.path.join(out, "vignette.tga"))


if __name__ == "__main__":
    main()
