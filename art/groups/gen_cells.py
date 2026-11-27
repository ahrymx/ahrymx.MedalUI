r"""Mockup: the group cell before and after the readability pass (2026-11-27).

Before: the class colour edge to edge (x0.8), the name 11 px centred left,
level and value 9 px at the foot, a flat power bar.
After ("class fill, deepened"): the same class colour, shaded toward its
foot, a 1 px light along its top, a dark band behind the name row at the
health's foot (role, name, value), the level 10 px top left, the text
outlined; the power bar muted further and shaded.

Drawn at 2x (about a 1440p screen at UI scale 1) -> render/cells.png
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "render")
FONT = os.path.join(HERE, "..", "..", "WoW", "Interface", "AddOns", "MedalUI", "media", "fonts",
                    "MarcellusSC-Regular.ttf")
S = 2

INK = (18, 17, 16)
WELL = (22, 22, 26)
GOLD, GOLD_D, GOLD_B = (196, 165, 87), (138, 112, 52), (224, 184, 74)
TEXT = (242, 234, 210)
DIM = (178, 168, 140)
BG = (52, 58, 66)
DEAD = (90, 90, 90)
MANA, RAGE, ENERGY = (0, 0, 255), (255, 0, 0), (255, 255, 0)
CLASS = {"PRIEST": (255, 255, 255), "ROGUE": (255, 245, 105), "MAGE": (63, 199, 235),
         "DRUID": (255, 125, 10), "WARRIOR": (199, 156, 110), "PALADIN": (244, 140, 186),
         "SHAMAN": (0, 112, 221), "HUNTER": (170, 211, 114), "WARLOCK": (135, 136, 238),
         "HOSTILE": (204, 77, 56)}
ROLE = {"TANK": (120, 160, 230), "HEALER": (110, 200, 110), "DAMAGER": (220, 110, 90)}

PARTY = [("Ahrymx", "SHAMAN", "HEALER", 0.94, 0.80, MANA, 47, False),
         ("Isolde", "PRIEST", "HEALER", 0.62, 0.55, MANA, 46, False),
         ("Thalric", "WARRIOR", "TANK", 0.88, 0.40, RAGE, 48, False),
         ("Velis", "ROGUE", "DAMAGER", 0.18, 0.70, ENERGY, 47, False),
         ("Brannoc", "PALADIN", "DAMAGER", 0.0, 0.0, MANA, 45, True)]
RAID = [("Mardu", "MAGE", 1.0), ("Kerrin", "HUNTER", 0.71), ("Ysolt", "WARLOCK", 0.45),
        ("Orrin", "DRUID", 0.93), ("Nokamii", "PRIEST", 0.30)]


def f(px):
    return ImageFont.truetype(FONT, px * S)


def mul(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def over(img, box, rgba):
    """Alpha-paint a rectangle."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rectangle(box, fill=rgba)
    img.alpha_composite(layer)


def vshade(img, x0, y0, x1, y1, a_top, a_foot):
    """Black, a_top at the top to a_foot at the foot."""
    h = max(1, y1 - y0)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(h):
        a = int(255 * (a_top + (a_foot - a_top) * i / (h - 1 if h > 1 else 1)))
        d.line([(x0, y0 + i), (x1 - 1, y0 + i)], fill=(0, 0, 0, a))
    img.alpha_composite(layer)


def hband(img, x0, y0, x1, y1, a, feather=4 * S):
    """Black at a, its top edge feathered over feather px (no hard seam)."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for j in range(y1 - y0):
        k = min(1, (j + 1) / feather)
        d.line([(x0, y0 + j), (x1 - 1, y0 + j)], fill=(0, 0, 0, int(255 * a * k)))
    img.alpha_composite(layer)


def fit(d, s, size, room):
    """s cut with an ellipsis to fit room px."""
    if d.textlength(s, font=f(size)) <= room:
        return s
    while s and d.textlength(s + "...", font=f(size)) > room:
        s = s[:-1]
    return s.rstrip() + "..."


def text(d, xy, s, size, fill, anchor="la", outline=False):
    if outline:
        d.text(xy, s, font=f(size), fill=fill, anchor=anchor, stroke_width=1, stroke_fill=(0, 0, 0))
    d.text((xy[0] + S, xy[1] + S), s, font=f(size), fill=(0, 0, 0), anchor=anchor) if not outline else None
    d.text(xy, s, font=f(size), fill=fill, anchor=anchor)


def role(d, cx, cy, r):
    c = ROLE[r]
    d.ellipse([cx - 6 * S, cy - 6 * S, cx + 6 * S, cy + 6 * S], fill=INK, outline=mul(c, 0.9), width=S)
    d.ellipse([cx - 2 * S, cy - 2 * S, cx + 2 * S, cy + 2 * S], fill=c)


def cell(img, x, y, w, h, name, cls, rl, hp, pw, pcol, level, dead, new, small=False):
    d = ImageDraw.Draw(img)
    W, H = w * S, h * S
    ph = 4 if small else 5
    hh = (h - ph - 1) * S
    d.rectangle([x, y, x + W - 1, y + H - 1], fill=WELL)
    col = DEAD if dead else mul(CLASS[cls], 0.8)
    if not dead:
        d.rectangle([x, y, x + int(W * hp) - 1, y + hh - 1], fill=col)
    pc = mul(pcol, 0.65 if new else 0.8)
    py = y + hh + S
    d.rectangle([x, y + hh, x + W - 1, py - 1], fill=INK)
    if not dead:
        d.rectangle([x, py, x + int(W * pw) - 1, y + H - 1], fill=pc)
    nsz = (12 if small else 13) if new else 11
    if new:
        vshade(img, x, y, x + W, y + hh, 0.0, 0.30)
        if not dead:
            over(img, [x, y, x + int(W * hp) - 1, y + S - 1], (255, 255, 255, 26))
        vshade(img, x, py, x + W, y + H, 0.0, 0.35)
        band = (nsz + 5) * S
        hband(img, x, y + hh - band, x + W, y + hh, 0.30)
        d = ImageDraw.Draw(img)
        mid = y + hh - band // 2
        tx = x + 4 * S
        if rl and not small:
            role(d, x + 10 * S, mid, rl)
            tx = x + 20 * S
        if dead:
            text(d, (tx, mid), name, nsz, (150, 150, 150), "lm", True)
            text(d, (x + W - 4 * S, mid), "Dead", 11 if not small else 10, (200, 80, 70), "rm", True)
        else:
            val = f"{int(hp * 100)}%"
            vsz = 11 if not small else 10
            room = x + W - 8 * S - d.textlength(val, font=f(vsz)) - tx
            text(d, (tx, mid), fit(d, name, nsz, room), nsz, TEXT, "lm", True)
            text(d, (x + W - 4 * S, mid), val, vsz, TEXT, "rm", True)
            if not small:
                text(d, (x + 4 * S, y + 3 * S), "??" if level < 0 else str(level), 10, (230, 40, 40) if level < 0 else DIM, "la", True)
    else:
        d = ImageDraw.Draw(img)
        if rl and not small:
            role(d, x + 10 * S, y + hh // 2 + 2 * S, rl)
        tx = x + (22 if rl and not small else 4) * S
        text(d, (tx, y + (hh // 2 if not small else 3 * S)), name, 11, TEXT, "lm" if not small else "la")
        if not small:
            text(d, (tx, y + hh - 3 * S), "??" if level < 0 else str(level), 9, (230, 40, 40) if level < 0 else DIM, "ld")
        text(d, (x + W - 4 * S, y + hh - 3 * S), "Dead" if dead else f"{int(hp * 100)}%", 9, DIM, "rd")


def box(img, x, y, w, rows_h, title):
    d = ImageDraw.Draw(img)
    W, Hh = w * S, rows_h * S
    pad = 5 * S
    d.rectangle([x, y, x + W + 2 * pad, y + Hh + 2 * pad], fill=INK, outline=GOLD, width=2 * S)
    d.rectangle([x + 2 * S, y + 2 * S, x + W + 2 * pad - 2 * S, y + Hh + 2 * pad - 2 * S], outline=GOLD_D, width=S)
    tw = int(d.textlength(title, font=f(12))) + 20 * S
    tx = x + (W + 2 * pad) // 2 - tw // 2
    d.rectangle([tx, y - 20 * S, tx + tw, y], fill=INK, outline=GOLD, width=S)
    d.text((tx + tw // 2, y - 10 * S), title, font=f(12), fill=GOLD_B, anchor="mm")
    return x + pad, y + pad


def panel(new):
    img = Image.new("RGBA", (420 * S, 360 * S), BG + (255,))
    d = ImageDraw.Draw(img)
    d.text((10 * S, 8 * S), "After" if new else "Before", font=f(16), fill=TEXT)
    # party: 5 cells of 160x40, gap 3
    ox, oy = box(img, 12 * S, 58 * S, 160, 5 * 43 - 3, "Party")
    for i, (n, c, r, hp, pw, pc, lv, dead) in enumerate(PARTY):
        cell(img, ox, oy + i * 43 * S, 160, 40, n, c, r, hp, pw, pc, lv, dead, new)
    # raid column: 112x36
    ox, oy = box(img, 200 * S, 58 * S, 112, 5 * 39 - 3, "Group 1")
    for i, (n, c, hp) in enumerate(RAID):
        cell(img, ox, oy + i * 39 * S, 112, 36, n, c, None, hp, 0.8, MANA, 60, False, new, small=True)
    # boss: 180x40
    ox, oy = box(img, 200 * S, 296 * S, 180, 40, "Bosses")
    d = ImageDraw.Draw(img)
    cell(img, ox, oy, 180, 40, "High Warlord Naj'entus", "HOSTILE", None, 0.64, 1.0, MANA, -1, False, new)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    a, b = panel(False), panel(True)
    out = Image.new("RGBA", (a.width * 2, a.height), BG + (255,))
    out.paste(a, (0, 0))
    out.paste(b, (a.width, 0))
    path = os.path.join(OUT, "cells.png")
    out.convert("RGB").save(path)
    print(path, out.size)


if __name__ == "__main__":
    main()
