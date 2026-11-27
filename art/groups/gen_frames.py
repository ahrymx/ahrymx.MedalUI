r"""Mockup: the group boxes' border and grip title (2026-11-27), around the
new cells (gen_cells.py). Today: a 2 px gold edge, a dark line inside it, a
tab of art standing on the top edge. Three readings:

  A  Hairline + caption: a 1 px dark-gold hairline, no tab; the title as
     plain small caps over the box's left, a short gold rule after it.
  B  Header strip: the title inside the box, on a thin ink strip across its
     top with a gold underline; a 1 px dark rim and a soft shadow.
  C  Corner marks: no full edge, gold L-marks at the corners; the title
     centred above between two fading rules.

Drawn at 2x -> render/frames.png
"""
import os

from PIL import Image, ImageDraw, ImageFilter

import gen_cells as gc
from gen_cells import S, f, cell, PARTY, RAID, MANA, TEXT, INK, GOLD, GOLD_D, GOLD_B, DIM

OUT = gc.OUT
BG = (52, 58, 66)
PAD = 4


def shadow(img, box, r=8 * S, a=150):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rectangle(box, fill=(0, 0, 0, a))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(r)))


def ink(img, box, a=235):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rectangle(box, fill=INK + (a,))
    img.alpha_composite(layer)


def spaced(d, xy, s, size, fill, track=1.5, anchor_right=False):
    x, y = xy
    w = sum(d.textlength(ch, font=f(size)) + track * S for ch in s) - track * S
    if anchor_right:
        x -= w
    for ch in s:
        d.text((x + S, y + S), ch, font=f(size), fill=(0, 0, 0), anchor="lm")
        d.text((x, y), ch, font=f(size), fill=fill, anchor="lm")
        x += d.textlength(ch, font=f(size)) + track * S
    return w


def fade_rule(img, x0, x1, y, col, reverse=False):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    n = max(1, x1 - x0)
    for i in range(n):
        t = i / n
        a = int(255 * ((t if reverse else 1 - t)))
        d.line([(x0 + i, y), (x0 + i, y + S - 1)], fill=col + (a,))
    img.alpha_composite(layer)


def frame(img, style, x, y, w, h, title):
    """The box around cells of w x h (cell area) at x, y; returns the cells' origin."""
    d = ImageDraw.Draw(img)
    p = PAD * S
    W, H = w * S + 2 * p, h * S + 2 * p
    if style == "today":
        ink(img, [x, y, x + W, y + H])
        d.rectangle([x, y, x + W, y + H], outline=GOLD, width=2 * S)
        d.rectangle([x + 2 * S, y + 2 * S, x + W - 2 * S, y + H - 2 * S], outline=GOLD_D, width=S)
        tw = int(d.textlength(title, font=f(12))) + 20 * S
        tx = x + W // 2 - tw // 2
        d.rectangle([tx, y - 20 * S, tx + tw, y], fill=INK, outline=GOLD, width=S)
        d.text((tx + tw // 2, y - 10 * S), title, font=f(12), fill=GOLD_B, anchor="mm")
    elif style == "A":
        shadow(img, [x, y, x + W, y + H], a=110)
        ink(img, [x, y, x + W, y + H], 225)
        d = ImageDraw.Draw(img)
        d.rectangle([x, y, x + W, y + H], outline=GOLD_D, width=S)
        ty = y - 9 * S
        tw = spaced(d, (x + 2 * S, ty), title.upper(), 11, GOLD_B)
        fade_rule(img, int(x + tw + 10 * S), int(x + W), ty, GOLD_D)
    elif style == "B":
        head = 18 * S
        y0 = y - head
        shadow(img, [x, y0, x + W, y + H], a=150)
        ink(img, [x, y0, x + W, y + H], 235)
        d = ImageDraw.Draw(img)
        d.rectangle([x, y0, x + W, y + H], outline=(8, 8, 8), width=S)
        d.rectangle([x + S, y0 + S, x + W - S, y0 + head - S], fill=(28, 26, 22))
        fade_rule(img, x + S, x + W - S, y0 + head - S, GOLD)
        spaced(d, (x + 7 * S, y0 + head // 2), title.upper(), 10, GOLD_B)
        # the grip's dots at the right end
        for i in range(3):
            cx = x + W - 10 * S - i * 5 * S
            d.ellipse([cx - S, y0 + head // 2 - S, cx + S, y0 + head // 2 + S], fill=GOLD_D)
    elif style == "C":
        ink(img, [x, y, x + W, y + H], 200)
        d = ImageDraw.Draw(img)
        L, t = 10 * S, 2 * S
        for cx, cy, sx, sy in ((x, y, 1, 1), (x + W, y, -1, 1), (x, y + H, 1, -1), (x + W, y + H, -1, -1)):
            d.rectangle([min(cx, cx + sx * L), min(cy, cy + sy * t), max(cx, cx + sx * L), max(cy, cy + sy * t)],
                        fill=GOLD)
            d.rectangle([min(cx, cx + sx * t), min(cy, cy + sy * L), max(cx, cx + sx * t), max(cy, cy + sy * L)],
                        fill=GOLD)
        ty = y - 10 * S
        tw = d.textlength(title.upper(), font=f(11)) + 4 * S * len(title) / 3
        mid = x + W // 2
        spaced(d, (mid - tw / 2, ty), title.upper(), 11, GOLD_B)
        fade_rule(img, int(x), int(mid - tw / 2 - 8 * S), ty, GOLD_D, reverse=True)
        fade_rule(img, int(mid + tw / 2 + 8 * S), int(x + W), ty, GOLD_D)
    return x + p, y + p


def panel(style, label):
    img = Image.new("RGBA", (420 * S, 330 * S), BG + (255,))
    d = ImageDraw.Draw(img)
    d.text((10 * S, 10 * S), label, font=f(15), fill=TEXT)
    ox, oy = frame(img, style, 12 * S, 66 * S, 160, 5 * 43 - 3, "Party")
    for i, (n, c, r, hp, pw, pc, lv, dead) in enumerate(PARTY):
        cell(img, ox, oy + i * 43 * S, 160, 40, n, c, r, hp, pw, pc, lv, dead, True)
    ox, oy = frame(img, style, 206 * S, 66 * S, 112, 5 * 39 - 3, "Group 1")
    for i, (n, c, hp) in enumerate(RAID):
        cell(img, ox, oy + i * 39 * S, 112, 36, n, c, None, hp, 0.8, MANA, 60, False, True, small=True)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    panels = [panel("today", "Today"), panel("A", "A  Hairline + caption"),
              panel("B", "B  Header strip"), panel("C", "C  Corner marks")]
    w, h = panels[0].size
    out = Image.new("RGBA", (w * 2, h * 2), BG + (255,))
    for i, p in enumerate(panels):
        out.paste(p, ((i % 2) * w, (i // 2) * h))
    path = os.path.join(OUT, "frames.png")
    out.convert("RGB").save(path)
    print(path, out.size)


if __name__ == "__main__":
    main()
