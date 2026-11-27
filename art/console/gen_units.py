r"""Mockup: the console's player and target frames (2026-11-27), in the
Reticule's unit window (204x38 art px: health 28, seam 2, power 8; the
player the left copy, the target the right, mirrored).

  Today  flat class fill, the name 13 px pale, the value 11 px dim at the
         inner end, the power value 9 px centred, the level 9 px on the
         power bar's outer end; buffs/debuffs inside the health's foot.
  A      the group cells' look (gen_cells.py): the fill shaded toward its
         foot, a 1 px top light, outlined warm-white text; the level small
         and dim gold before the name; the power value at the power bar's
         inner end; the auras above the window (it sits at the console's
         top edge), buffs from the outer end past the crown, debuffs from
         the inner end.
  B      as A, the level in a dark badge over the outer corner, where the
         health meets the power bar.

Built (2026-11-27): B, its badge inside the power bar's outer bottom corner,
under the name; the buffs (35 px) and the debuffs under them at the same
size outside the window's outer end, running away from the screen's centre.

Drawn at 3x -> render/units.png
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "render")
FONT = os.path.join(HERE, "..", "..", "WoW", "Interface", "AddOns", "MedalUI", "media", "fonts",
                    "MarcellusSC-Regular.ttf")
S = 3

W, HEALTH, SEAM, POWER = 204, 28, 2, 8
H = HEALTH + SEAM + POWER
INK = (18, 17, 16)
WELL = (14, 14, 18)
GOLD, GOLD_D, GOLD_B = (196, 165, 87), (138, 112, 52), (224, 184, 74)
TEXT = (242, 234, 210)
DIM = (178, 168, 140)
BG = (52, 58, 66)
MANA, RAGE = (0, 0, 255), (255, 0, 0)
SHAMAN, PRIEST = (0, 112, 221), (255, 255, 255)
FRIEND, HOSTILE = (0, 255, 0), (255, 0, 0)
AURA = [(150, 90, 40), (60, 120, 170)]
DEBUFF = (150, 40, 150)

# name, side (-1 player, 1 target), fill, health, power colour, power, power text, level, crown, auras
CASES = [
    ("Ahry", -1, SHAMAN, 1.00, MANA, 1.00, "2688 | 100%", "47", True, True),
    ("Azugor", 1, FRIEND, 1.00, MANA, 1.00, "1995 | 100%", "45", False, False),
    ("High Warlord Naj'entus", 1, HOSTILE, 0.64, RAGE, 0.30, "30 | 30%", "??", False, True),
    ("Isolde", -1, PRIEST, 0.18, MANA, 0.55, "1420 | 55%", "46", False, False),
]


def f(px):
    return ImageFont.truetype(FONT, int(px * S))


def mul(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def layer(img):
    return Image.new("RGBA", img.size, (0, 0, 0, 0))


def vshade(img, x0, y0, x1, y1, a_top, a_foot):
    h = max(1, y1 - y0)
    lay = layer(img)
    d = ImageDraw.Draw(lay)
    for i in range(h):
        a = int(255 * (a_top + (a_foot - a_top) * i / max(1, h - 1)))
        d.line([(x0, y0 + i), (x1 - 1, y0 + i)], fill=(0, 0, 0, a))
    img.alpha_composite(lay)


def over(img, box, rgba):
    lay = layer(img)
    ImageDraw.Draw(lay).rectangle(box, fill=rgba)
    img.alpha_composite(lay)


def text(d, xy, s, size, fill, anchor, outline):
    if outline:
        d.text(xy, s, font=f(size), fill=fill, anchor=anchor, stroke_width=max(1, S // 2),
               stroke_fill=(0, 0, 0))
    else:
        d.text((xy[0] + S, xy[1] + S), s, font=f(size), fill=(0, 0, 0), anchor=anchor)
        d.text(xy, s, font=f(size), fill=fill, anchor=anchor)


def width(d, s, size):
    return d.textlength(s, font=f(size))


def fit(d, s, size, room):
    if width(d, s, size) <= room:
        return s
    while s and width(d, s + "...", size) > room:
        s = s[:-1]
    return s.rstrip() + "..."


def icon(img, x, y, col, size=15):
    d = ImageDraw.Draw(img)
    z = size * S
    d.rectangle([x, y, x + z - 1, y + z - 1], fill=INK)
    d.rectangle([x + S, y + S, x + z - S - 1, y + z - S - 1], fill=col)
    d.line([(x + S, y + S), (x + z - S - 1, y + z - S - 1)], fill=mul(col, 1.4), width=S)


def crown(d, cx, cy):
    r = 6 * S
    pts = [(cx - r, cy + r // 2), (cx - r, cy - r // 2), (cx - r // 2, cy), (cx, cy - r), (cx + r // 2, cy),
           (cx + r, cy - r // 2), (cx + r, cy + r // 2)]
    d.polygon(pts, fill=GOLD_B, outline=(60, 40, 10))


def unit(img, x, y, case, style):
    """The window at x, y (its top left), drawn as style."""
    name, side, fill, hp, pcol, pw, ptext, level, has_crown, auras = case
    d = ImageDraw.Draw(img)
    w, hh, ph = W * S, HEALTH * S, POWER * S
    py = y + (HEALTH + SEAM) * S
    new = style != "today"
    # the window: a well, its gold edge from the console's art
    d.rectangle([x - 2 * S, y - 2 * S, x + w + 2 * S - 1, y + H * S + 2 * S - 1], fill=GOLD_D)
    d.rectangle([x - S, y - S, x + w + S - 1, y + H * S + S - 1], fill=INK)
    d.rectangle([x, y, x + w - 1, y + H * S - 1], fill=WELL)
    # health, filled from the outer end
    col = mul(fill, 0.8)
    fw = int(w * hp)
    hx0, hx1 = (x, x + fw) if side == -1 else (x + w - fw, x + w)
    d.rectangle([hx0, y, hx1 - 1, y + hh - 1], fill=col)
    # power
    pfw = int(w * pw)
    px0, px1 = (x, x + pfw) if side == -1 else (x + w - pfw, x + w)
    d.rectangle([px0, py, px1 - 1, py + ph - 1], fill=mul(pcol, 0.65 if new else 0.8))
    if new:
        vshade(img, x, y, x + w, y + hh, 0.0, 0.30)
        over(img, [hx0, y, hx1 - 1, y + S - 1], (255, 255, 255, 26))
        vshade(img, x, py, x + w, py + ph, 0.0, 0.35)
    d = ImageDraw.Draw(img)

    outer_x = x + 8 * S if side == -1 else x + w - 8 * S
    inner_x = x + w - 8 * S if side == -1 else x + 8 * S
    oa, ia = ("l", "r") if side == -1 else ("r", "l")
    mid = y + hh // 2
    pmid = py + ph // 2
    value = f"{int(hp * 100)}%"
    if not new:
        vs, ns_ = 11, 13
        text(d, (inner_x, mid), value, vs, DIM, ia + "m", False)
        room = w - 16 * S - width(d, value, vs) - 6 * S
        text(d, (outer_x, mid), fit(d, name, ns_, room), ns_, TEXT, oa + "m", False)
        text(d, (x + w // 2, pmid), ptext, 9, DIM, "mm", False)
        text(d, (outer_x, pmid), level, 9, (230, 40, 40) if level == "??" else TEXT, oa + "m", False)
        if has_crown:
            crown(d, x + 14 * S if side == -1 else x + w - 14 * S, y)
        if auras:
            # inside the health's foot: buffs from the outer corner, debuffs from the inner
            for i, c in enumerate(AURA):
                bx = x + (2 + i * 17) * S if side == -1 else x + w - (2 + 15 + i * 17) * S
                icon(img, bx, y + hh - 17 * S, c)
            dx = x + w - 17 * S if side == -1 else x + 2 * S
            icon(img, dx, y + hh - 17 * S, DEBUFF)
        return
    vs, nsz = 13, 15
    lvl_col = (230, 60, 50) if level == "??" else GOLD
    tx = outer_x
    if style == "A":
        text(d, (tx, mid), level, 11, lvl_col, oa + "m", True)
        lw = width(d, level, 11) + 5 * S
        tx = tx + lw if side == -1 else tx - lw
    room = abs(inner_x - tx) - width(d, value, vs) - 8 * S
    text(d, (inner_x, mid), value, vs, TEXT, ia + "m", True)
    text(d, (tx, mid), fit(d, name, nsz, room), nsz, TEXT, oa + "m", True)
    # power value at the power bar's inner end
    text(d, (inner_x, pmid), ptext, 10, TEXT, ia + "m", True)
    if style == "B":
        bw, bh = 20 * S, 13 * S
        bx = x - 3 * S if side == -1 else x + w - bw + 3 * S
        by = py - bh // 2 - S
        d.rectangle([bx, by, bx + bw - 1, by + bh - 1], fill=INK, outline=GOLD_D, width=S)
        text(d, (bx + bw // 2, by + bh // 2), level, 10, lvl_col, "mm", True)
    if has_crown:
        crown(d, x + 14 * S if side == -1 else x + w - 14 * S, y)
    if auras:
        # above the window: buffs from the outer end past the crown, debuffs from the inner
        ay = y - 2 * S - 17 * S
        for i, c in enumerate(AURA):
            bx = x + (26 + i * 17) * S if side == -1 else x + w - (26 + 15 + i * 17) * S
            icon(img, bx, ay, c)
        dx = x + w - 15 * S if side == -1 else x
        icon(img, dx, ay, DEBUFF)


def main():
    os.makedirs(OUT, exist_ok=True)
    cw, rh, top = (W + 30) * S, (H + 34) * S, 30 * S
    img = Image.new("RGBA", (cw * 3 + 20 * S, top + rh * len(CASES) + 10 * S), BG + (255,))
    d = ImageDraw.Draw(img)
    for c, (style, label) in enumerate((("today", "Today"), ("A", "A  Level by the name"),
                                         ("B", "B  Level badge on the corner"))):
        d.text((20 * S + c * cw, 8 * S), label, font=f(12), fill=TEXT)
        for r, case in enumerate(CASES):
            unit(img, 20 * S + c * cw, top + r * rh + 22 * S, case, style)
            d = ImageDraw.Draw(img)
    path = os.path.join(OUT, "units.png")
    img.convert("RGB").save(path)
    print(path, img.size)


if __name__ == "__main__":
    main()
