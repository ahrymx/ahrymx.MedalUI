#!/usr/bin/env python3
"""mdlui_RadialMenu's own wheel art: FlareUI's layout, each part redrawn in Medalluin's
gold and ink (the user's call, 2026-11-16, from the mockups' "FlareUI layout" boards).

    python3 art/radial/gen_radial.py   -> assets/radial/*.png and the companion's art/radial/*.tga

Each texture is drawn at its own size in texels; the comment on each says the size the
wheel shows it at (Radial/Radial.lua), and lengths below are in those screen pixels.
Edges are anti-aliased by coverage (a one-texel ramp), not by supersampling.

FlareUI's MIT textures stay where only their colour changes: Divider (the slice edges),
SliceGlow and HalfMask (the slice light) and Dot (a sub-radial's page dots).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
from export import to_tga  # noqa: E402

ASSETS = os.path.join(ROOT, "assets", "radial")
MEDIA = os.path.join(ROOT, "WoW", "Interface", "AddOns", "mdlui_RadialMenu", "art", "radial")

# Medalluin's palette (options/theme.lua)
INK = (0x12, 0x11, 0x10)
TEXT = (0xf2, 0xea, 0xd2)
GOLD = (0xc4, 0xa5, 0x57)
GOLD_D = (0x8a, 0x70, 0x34)
GOLD_B = (0xe0, 0xb8, 0x4a)
EDGE = (0x2b, 0x27, 0x20)


class Canvas:
    """An RGBA float canvas of n x n texels standing for `shown` screen pixels."""

    def __init__(self, n, shown):
        self.n, self.k = n, n / shown
        self.rgba = np.zeros((n, n, 4))
        c = (n - 1) / 2
        y, x = np.mgrid[0:n, 0:n]
        self.x, self.y = (x - c) / self.k, (c - y) / self.k   # screen px, y up, from the centre
        self.r = np.hypot(self.x, self.y)

    def cover(self, d):
        """Coverage from a signed distance in screen px (negative inside)."""
        return np.clip(0.5 - d * self.k, 0, 1)

    def paint(self, colour, alpha):
        """Paints colour over what is there, alpha a texel array (0..1)."""
        a = np.clip(alpha, 0, 1)[..., None]
        c = np.array(colour, float) / 255
        out_a = a + self.rgba[..., 3:] * (1 - a)
        rgb = (c * a + self.rgba[..., :3] * self.rgba[..., 3:] * (1 - a)) / np.maximum(out_a, 1e-6)
        self.rgba = np.concatenate([rgb, out_a], axis=-1)

    def band(self, colour, r_in, r_out, alpha=1.0):
        self.paint(colour, alpha * self.cover(self.r - r_out) * (1 - self.cover(self.r - r_in)))

    def image(self):
        return Image.fromarray((np.clip(self.rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def backdrop():
    """The ink disc behind the wheel (Blizzard's Radial_Wheel_BG before), shown at
    max(300, radius * 3.1): dense to two thirds out, then fading to nothing at the edge."""
    c = Canvas(256, 256)
    t = c.r / 128
    alpha = np.where(t < 0.64, 0.92 - 0.07 * t / 0.64, 0.85 * (1 - smooth((t - 0.64) / 0.35)))
    c.paint(INK, np.where(t < 0.99, alpha, 0))
    return c


def outer_ring():
    """A thin dark-gold ring where the slots' light ends, at radius + 0.9 icon (about 350 px)."""
    c = Canvas(512, 360)
    c.band(GOLD_D, 178.4, 179.6, 0.55)
    return c


def hub():
    """The centre ring (FlareUI's tinted Ring before), 56 px: an ink disc, a gold rim and a
    dark-gold hairline inside it. The cancel X sits on it."""
    c = Canvas(128, 56)
    c.band(INK, 0, 27.5)
    c.band(GOLD, 25.6, 27.6)
    c.band(GOLD_D, 21.8, 22.8, 0.6)
    return c


def rim(lit):
    """A slot's rim over its round icon (the talent-node rim before), 52 px: a dark outline,
    a gold band lit from above, a dark-gold inner line. The centre is empty: the icon shows
    there, over the ink well the code draws. Lit: the bright gold of the aimed slot."""
    c = Canvas(128, 52)
    shade = 0.5 + 0.5 * np.clip(c.y / 26, -1, 1)          # 1 at the top, 0 at the bottom
    top, bottom = (np.array(GOLD_B if lit else GOLD, float), np.array(GOLD if lit else GOLD_D, float) * (1.08 if not lit else 1))
    band_rgb = bottom + (top - bottom) * (0.35 + 0.65 * shade)[..., None]
    a_band = c.cover(c.r - 25.2) * (1 - c.cover(c.r - 22.2))
    c.band(EDGE, 25.0, 26.0)
    # the band's colour varies by texel: paint it channel-wise
    a = a_band[..., None]
    c.rgba[..., :3] = band_rgb / 255 * a + c.rgba[..., :3] * (1 - a)
    c.rgba[..., 3] = np.maximum(c.rgba[..., 3], a_band)
    c.band(GOLD_B if lit else GOLD_D, 21.2, 22.2, 0.9 if lit else 0.8)
    return c


def rim_glow():
    """The aimed slot's glow, shown at 80 px behind its 52 px rim."""
    c = Canvas(128, 80)
    t = (c.r - 24) / 16
    c.paint(GOLD_B, np.where(c.r > 24, 0.6 * (1 - smooth(t)), 0.6))
    return c


def pointer():
    """The aim arrow (Blizzard's Radial_Wheel_Select_Pointer before), shown at 112 px and
    turned to the cursor's angle, so drawn pointing right: a notched arrowhead from 37 to
    50 px out, just beyond the hub ring, with a soft gold glow."""
    c = Canvas(128, 112)
    ss = 8                                   # the polygon is drawn 8x and scaled down
    big = Image.new("L", (c.n * ss, c.n * ss), 0)
    tip, base, half, notch = 50.0, 37.0, 9.0, 37.0 + 13 * 0.28

    def at(px, py):                          # screen px from the centre, y up -> big texels
        mid = c.n * ss / 2
        return (mid + px * c.k * ss, mid - py * c.k * ss)

    ImageDraw.Draw(big).polygon([at(tip, 0), at(base, half), at(notch, 0), at(base, -half)], fill=255)
    small = big.resize((c.n, c.n), Image.LANCZOS)
    shape = np.asarray(small, float) / 255
    glow = np.asarray(small.filter(ImageFilter.GaussianBlur(3 * c.k)), float) / 255
    c.paint(GOLD_B, np.clip(glow * 1.4, 0, 0.7))
    c.paint(GOLD_B, shape)
    return c


def cancel():
    """The cancel X in the centre (Blizzard's Radial_Wheel_Icon_Close before), 24 px: two
    round-ended strokes 20 px long, 3 px thick, in Medalluin's text colour. Idle, the code
    shows it at half alpha."""
    c = Canvas(64, 24)
    best = np.full(c.r.shape, 1e9)
    for ang in (45, -45):
        a = math.radians(ang)
        ux, uy = math.cos(a), math.sin(a)
        along = np.clip(c.x * ux + c.y * uy, -8.5, 8.5)
        best = np.minimum(best, np.hypot(c.x - along * ux, c.y - along * uy))
    c.paint(TEXT, c.cover(best - 1.5))
    return c


def cancel_glow():
    """The bloom under a lit cancel X (Blizzard's Radial_Wheel_Select_Close before), 48 px."""
    c = Canvas(64, 48)
    c.paint(GOLD_B, 0.55 * (1 - smooth(c.r / 23.5)))
    return c


def mask():
    """A round mask for the icons and the ink well (the client's CircleMaskScalable before):
    white inside, transparent outside, at any size."""
    c = Canvas(64, 64)
    c.paint((255, 255, 255), c.cover(c.r - 31.5))
    return c


PARTS = {
    "Backdrop": backdrop, "OuterRing": outer_ring, "Hub": hub,
    "Rim": lambda: rim(False), "RimLit": lambda: rim(True), "RimGlow": rim_glow,
    "Pointer": pointer, "Cancel": cancel, "CancelGlow": cancel_glow, "Mask": mask,
}


def main():
    os.makedirs(ASSETS, exist_ok=True)
    os.makedirs(MEDIA, exist_ok=True)
    for name, draw in PARTS.items():
        img = draw().image()
        img.save(os.path.join(ASSETS, name + ".png"))
        to_tga(img, os.path.join(MEDIA, name + ".tga"))
        print(name, img.size)


if __name__ == "__main__":
    main()
