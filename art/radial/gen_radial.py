#!/usr/bin/env python3
"""mdlui_RadialMenu's own wheel art: FlareUI's layout, each part redrawn in Medalluin's
gold and ink (the user's call, 2026-11-16, from the mockups' "FlareUI layout" boards).

    python3 art/radial/gen_radial.py          -> assets/radial/*.png and the companion's art/radial/*.tga
    python3 art/radial/gen_radial.py glyphs   -> the emote category glyphs only (Glyph*.tga)

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



# ------------------------------------------------------------------ emote category glyphs
# The presets' categories (Core/Presets.lua), picked by the user from the mockup's candidates
# (2026-11-16): Medalluin's glyph style, as art/strips/gen_strips.py's (a 20x20 box, the gold
# gradient, a dark outline), on an ink square the round button masks. 64 texels; the glyph is
# about 30 px in the 46 px icon.
GLYPH_TEXELS, GLYPH_BOX = 64, 42


def _circ(cx, cy, r):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}"/>'


def _rect(x, y, w, h, rx=0, rot=None):
    t = f' transform="rotate({rot[0]} {rot[1]} {rot[2]})"' if rot else ""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}"{t}/>'


def _path(d, rot=None):
    t = f' transform="rotate({rot[0]} {rot[1]} {rot[2]})"' if rot else ""
    return f'<path d="{d}"{t}/>'


def _mask_face(smile):
    """A theatre mask: the face, its eye holes and its mouth (and a tear) cut out."""
    face = [_path("M3,3 C7,1.5 13,1.5 17,3 C17.5,11 15,17 10,18.8 C5,17 2.5,11 3,3 Z")]
    cuts = [_path("M5.2,7 C6.2,5.6 8,5.6 8.8,7.2 C8,8.6 6.2,8.6 5.2,7 Z"),
            _path("M11.2,7.2 C12,5.6 13.8,5.6 14.8,7 C13.8,8.6 12,8.6 11.2,7.2 Z")]
    if smile:
        cuts.append(_path("M5.6,11 C7.5,15.2 12.5,15.2 14.4,11 C12.4,12.6 7.6,12.6 5.6,11 Z"))
    else:
        cuts.append(_path("M5.8,15 C7.6,11.2 12.4,11.2 14.2,15 C12.4,13.6 7.6,13.6 5.8,15 Z"))
        cuts.append(_path("M6.2,9.6 C6.9,10.8 7.1,11.8 6.8,12.6 C6.4,12.6 6,11.4 6.2,9.6 Z"))
    return face, cuts


def _sword(rot):
    s = ("M10,0.6 L11.6,2.6 L11.6,12.2 L8.4,12.2 L8.4,2.6 Z M5.2,12.2 L14.8,12.2 L14.8,14.2 L5.2,14.2 Z "
         "M9,14.2 L11,14.2 L11,17.4 L9,17.4 Z M8.2,17.4 L11.8,17.4 L11.8,19.2 L8.2,19.2 Z")
    return _path(s, rot=(rot, 10, 10))


# name: (shapes, holes cut from them)
GLYPHS = {
    "Greetings": ([_rect(5, 9, 10, 9, 3)]                                   # an open hand
                  + [_rect(x, top, 2.2, 12 - top, 1.1) for x, top in [(5.2, 3.2), (7.7, 1.6), (10.2, 1.4), (12.7, 2.6)]]
                  + [_rect(2.6, 8, 2.2, 7, 1.1, rot=(-35, 3.7, 14))], []),
    "Joy": _mask_face(True),                                                # the comedy mask
    "Sorrow": _mask_face(False),                                            # the tragedy mask
    "Taunts": ([_path("M5,8.6 C5,4.6 15,4.6 15,8.6 L15,12.4 L13,13.6 L13,16.4 L7,16.4 L7,13.6 L5,12.4 Z"),
                _path("M5.4,7.4 C3,7 1,4.6 1.4,1.6 C2.6,4 4.2,4.6 6.6,5 Z"),   # a horned skull
                _path("M14.6,7.4 C17,7 19,4.6 18.6,1.6 C17.4,4 15.8,4.6 13.4,5 Z")],
               [_circ(7.9, 9.8, 1.6), _circ(12.1, 9.8, 1.6), _rect(8.8, 14, 0.7, 2.4), _rect(10.5, 14, 0.7, 2.4)]),
    "AtEase": ([_rect(2.4, 15.2, 15.2, 2.4, 1.2, rot=(-14, 10, 16.4)),       # a campfire
                _rect(2.4, 15.2, 15.2, 2.4, 1.2, rot=(14, 10, 16.4)),
                _path("M10,14.4 C7.2,14.4 6,12.6 6.6,10.6 C7.2,8.8 8.6,8.2 8.6,6 C10,7.2 10.4,8.4 10.2,9.6 "
                      "C11.4,8.6 11.6,6.6 11.2,4.6 C13.8,6.4 14.6,9.4 13.8,11.6 C13.2,13.4 12,14.4 10,14.4 Z")], []),
    "Playful": ([_path("M3,16 C3,11 6,7.4 2.4,4 C7,4.4 9,7.4 10,10.4 C11,7.4 13,4.4 17.6,4 C14,7.4 17,11 17,16 Z"),
                 _path("M8.6,10.4 C8.6,6 9.2,3.6 10,2.6 C10.8,3.6 11.4,6 11.4,10.4 Z"),   # a jester's cap
                 _rect(2.4, 15.4, 15.2, 3, 1.4), _circ(2.6, 3.6, 1.6), _circ(17.4, 3.6, 1.6), _circ(10, 2, 1.5)], []),
    "Battle": ([_sword(45), _sword(-45)], []),                              # crossed swords
    "Distress": ([_path("M10,1.4 L19,17.6 L1,17.6 Z")],                     # a warning sign
                 [_path("M8.9,6.6 L11.1,6.6 L10.6,12.8 L9.4,12.8 Z"), _circ(10, 15, 1.2)]),
    "Signals": ([_rect(3, 1.4, 1.8, 18, 0.9), _path("M4.8,2.6 L18,6.8 L4.8,11 Z")], []),   # a pennant
}


class Picture:
    """A finished image, for PARTS (which expects .image())."""

    def __init__(self, img):
        self.img = img

    def image(self):
        return self.img


def glyph(name):
    import io
    import subprocess
    from PIL import ImageFilter
    shapes, holes = GLYPHS[name]
    big = GLYPH_BOX * 4
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{big}" height="{big}" viewBox="-1 -1 22 22">'
           '<defs><linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">'
           '<stop offset="0" stop-color="#f0d488"/><stop offset="1" stop-color="#a8823a"/></linearGradient>'
           '<mask id="m" maskUnits="userSpaceOnUse" x="-1" y="-1" width="22" height="22">'
           '<rect x="-1" y="-1" width="22" height="22" fill="#fff"/>'
           f'<g fill="#000">{"".join(holes)}</g></mask></defs>'
           f'<g fill="url(#gold)" mask="url(#m)">{"".join(shapes)}</g></svg>')
    png = subprocess.run(["rsvg-convert"], input=svg.encode(), capture_output=True, check=True).stdout
    g = Image.open(io.BytesIO(png)).convert("RGBA").resize((GLYPH_BOX, GLYPH_BOX), Image.LANCZOS)
    # the dark outline, a texel round the glyph
    edge = Image.new("RGBA", g.size, (0x2a, 0x1e, 0x08, 0))
    edge.putalpha(g.getchannel("A").filter(ImageFilter.MaxFilter(3)))
    edge.alpha_composite(g)
    out = Image.new("RGBA", (GLYPH_TEXELS, GLYPH_TEXELS), INK + (255,))
    at = (GLYPH_TEXELS - GLYPH_BOX) // 2
    out.alpha_composite(edge, (at, at))
    return Picture(out)

PARTS = {
    "Backdrop": backdrop, "OuterRing": outer_ring, "Hub": hub,
    "Rim": lambda: rim(False), "RimLit": lambda: rim(True), "RimGlow": rim_glow,
    "Pointer": pointer, "Cancel": cancel, "CancelGlow": cancel_glow, "Mask": mask,
}


def main():
    os.makedirs(ASSETS, exist_ok=True)
    os.makedirs(MEDIA, exist_ok=True)
    # "glyphs": the emote category glyphs alone, the wheel's parts left as they are
    parts = dict(PARTS)
    for name in GLYPHS:
        parts["Glyph" + name] = (lambda n: lambda: glyph(n))(name)
    if sys.argv[1:] == ["glyphs"]:
        parts = {k: v for k, v in parts.items() if k.startswith("Glyph")}
    for name, draw in parts.items():
        img = draw().image()
        img.save(os.path.join(ASSETS, name + ".png"))
        to_tga(img, os.path.join(MEDIA, name + ".tga"))
        print(name, img.size)


if __name__ == "__main__":
    main()
