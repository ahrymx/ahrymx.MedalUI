#!/usr/bin/env python3
"""mdlui_Tooltips' Gilded header glow: the panel's tint rising from the header's top
left corner (the "A . Gilded" mockup's radial-gradient(120% 140% at 0 0, ...)).

    python3 art/tooltips/gen_tooltips.py   -> assets/tooltips/header-glow.png and the
                                              companion's art/header-glow.tga

White, the light in the alpha: the panel colours it with SetVertexColor and scales it
by the tint's strength. The texture is stretched over the header band, so the ellipse
follows the band's shape as the CSS one follows its box.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
from export import to_tga  # noqa: E402

ASSETS = os.path.join(ROOT, "assets", "tooltips")
MEDIA = os.path.join(ROOT, "WoW", "Interface", "AddOns", "mdlui_Tooltips", "art")

# the mockup's stops, alpha relative to the first: .34 at 0, .10 at 45%, 0 at 80%
STOPS = [(0.0, 1.0), (0.45, 0.10 / 0.34), (0.80, 0.0)]


def header_glow(w=256, h=128):
    y, x = np.mgrid[0:h, 0:w]
    u, v = (x + 0.5) / w, (y + 0.5) / h            # 0..1 across the band, from its top left
    d = np.hypot(u / 1.2, v / 1.4)                 # the ellipse's radius, 1 at its edge
    alpha = np.interp(d, [s for s, _ in STOPS], [a for _, a in STOPS], right=0.0)
    rgba = np.zeros((h, w, 4))
    rgba[..., :3] = 1.0
    rgba[..., 3] = alpha
    return Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA")


def main():
    os.makedirs(ASSETS, exist_ok=True)
    img = header_glow()
    img.save(os.path.join(ASSETS, "header-glow.png"))
    to_tga(img, os.path.join(MEDIA, "header-glow.tga"))
    print("header-glow", img.size)


if __name__ == "__main__":
    main()
