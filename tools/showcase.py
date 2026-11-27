#!/usr/bin/env python3
"""MedalUI's showcase cards for the README: 1920x1080, ink and gold, a gold
label, a headline, a line or numbered lines, the screenshots with numbered
badges that match the lines, and the medal with its byline.

    python3 tools/showcase.py            -> showcase/cards/NN-key.png, every card
    python3 tools/showcase.py quests     -> that card only

The screenshots are the repo's own: showcase/src/ (the reel's, plain names)
and the older ones in showcase/.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, "WoW", "Interface", "AddOns", "MedalUI", "media", "fonts")
SERIF_CAPS = os.path.join(FONTS, "MarcellusSC-Regular.ttf")    # label, headline, badges
BODY = os.path.join(FONTS, "Forum-Regular.ttf")                # the lines
SHOW = os.path.join(ROOT, "showcase")
OUT = os.path.join(SHOW, "cards")
ICON = os.path.join(ROOT, "assets", "medalui-icon.png")

W, H = 1920, 1080
# MedalUI's golds (theme.lua ns.gold)
GOLD = (240, 212, 136)          # light: titles
BRIGHT = (224, 184, 74)         # bright: what is chosen
DARK = (138, 112, 52)           # dark: rules, rims
INK = (18, 17, 16)
WHITE = (244, 238, 226)
GREY = (196, 190, 178)
DIM = (140, 134, 122)
BYLINE = "for WoW Forever & Retail · Made by AhryMX"

TEXT_X, TEXT_W = 120, 680       # split: the text column
ART = (840, 70, 960, 930)       # split: the images' box (x, y, w, h)
TOP_ART = (120, 350, 1680, 660)  # top: the images' box under the text


def src(name):
    for p in (os.path.join(SHOW, "src", name), os.path.join(SHOW, name)):
        if os.path.exists(p):
            return p
    raise FileNotFoundError(name)


# ------------------------------------------------------------------ the cards
# img: (file, crop or None, badges [(n, x, y) in the file's pixels])
# place: row (side by side), column (one under another), fan (overlapping
# left to right, each a little lower), cascade (down and to the right)
CARDS = [
    dict(key="console", label="The console", title="One console, ink and gold",
         items=["Player and target on its wings, your action bars between them",
                "Focus and target-of-target overhead, the pet on a deck beneath; or undocked, "
                "each with a portrait",
                "Party, raid, boss and arena frames in boxes you can move"],
         imgs=[("console-bar.png", None, [(1, -6, 92)]), ("overhead.png", None, [(2, -6, 20)]),
               ("overhead-undocked.png", None, [(2, 24, 150)]), ("group-frames.png", None, [(3, -6, 150)])],
         place="column", most=1.3),
    dict(key="themes", label="Themes", title="A theme for every class", layout="top",
         sub="Every window takes your class's colour, or stays in ink and gold.",
         imgs=[("theme-gold.png", (0, 0, 582, 1000), []), ("theme-teal.png", (0, 0, 582, 1000), []),
               ("theme-violet.png", (0, 0, 582, 1000), [])], place="row"),
    dict(key="spellbook", label="Spellbook & macros", title="Every spell, every rank",
         items=["Spells not on your bars first, then the ones that are",
                "Each spell's ranks, cast time and mana, and its click-cast keys",
                "Macros written and kept beside it, on the same strip"],
         imgs=[("spellbook.png", None, []), ("macros.png", None, [])], place="row"),
    dict(key="quests", label="Quests", title="Your log, by zone",
         items=["The quest log on the right strip: each quest's XP, items and coin",
                "The tracker's full view above the chat, with every objective",
                "A quest's own page spells out its chain, step by step"],
         imgs=[("quest-log.png", None, [(1, -6, 700)]), ("quest-tracker.png", None, [(2, -6, 900)]),
               ("quest-page.png", None, [(3, -6, 300)])], place="fan"),
    dict(key="side-panel", label="Side panel", title="Your zone beside the map",
         items=["Zone: the minimap by the zone's quests, and a Guide to what's next",
                "Meter: the game's own damage meter, docked",
                "Loot: the group's drops and who won each roll"],
         imgs=[("side-zone.png", None, []), ("side-meter.png", None, []),
               ("side-panel-loot.png", None, [])], place="column"),
    dict(key="chat", label="Chat", title="Chat that stays out of the way",
         items=["Immersion Mode: each message on a band of its own, the box back when you type",
                "Speakers in their class colour, after their level",
                "Your last 500 lines back at your next login"],
         imgs=[("chat-immersion.png", None, []), ("chat.png", None, [])], place="column", most=1.3),
    dict(key="npc", label="NPC windows", title="Merchants and quests, docked",
         sub="Gossip, quest pages, vendors, trainers and the mailbox open in one box above the chat, "
             "the full height of the screen. The game's own ways in and out all still work.",
         imgs=[("npc-vendor.png", None, [])], place="row"),
    dict(key="rolls", label="Loot rolls", title="Every roll in one card",
         items=["The item, and Need, Greed or Pass with the time left",
                "Who rolled what, the leader first, as the rolls come in"],
         imgs=[("roll-window.png", None, [])], place="row", most=2.0),
    dict(key="character", label="Character & bags", title="Your gear and your bags",
         items=["Gear slots with item levels round your model, then your stats",
                "Bags in groups, with Alt+click to lock an item from selling"],
         imgs=[("character.png", None, []), ("bags.png", None, [])], place="row"),
    dict(key="talents", label="Talents", title="Plan every point",
         items=["Each tree on a wash of its own colour, under its console",
                "Draft a plan by level on a grid, checkpoint by checkpoint",
                "Follow stages the plan's next talents for you to apply"],
         imgs=[("talents.png", None, []), ("talent-planning.png", None, []),
               ("talent-plans.png", None, [])], place="fan"),
    dict(key="professions", label="Professions", title="Every trade at a glance",
         sub="Your professions with their skill, what is still to learn, and the cooldowns worth tracking.",
         imgs=[("professions.png", None, [])], place="row"),
    dict(key="game-menu", label="Game menu", title="A menu around your character", layout="top",
         sub="Esc opens your character, MedalUI's shortcuts and your friends. Left alone, it folds to a rail "
             "while the camera turns.",
         imgs=[("game-menu.png", None, []), ("game-menu-folded.png", None, [])], place="row"),
    dict(key="clickcast", label="Click casting", title="Spells on a frame's click",
         items=["Each binding a plate, its click as keys",
                "Lock a binding: no other can take its click",
                "The binder: pick a spell, click the pad, save"],
         imgs=[("clickcast.png", None, [(1, -6, 325), (2, 412, 386), (3, -6, 935)])], place="row"),
    dict(key="cooldowns", label="Cooldown Manager", title="The game's viewers, restyled",
         sub="Each Cooldown Manager viewer with its own layout, a bar or an arch, its shape, text and "
             "visibility, and a simulation to preview them out of a fight.",
         imgs=[("cooldown-manager.png", None, [])], place="row"),
    dict(key="tooltips", label="Tooltips", title="Every tooltip, ornamented",
         items=["Spells with their cost, cast and range in a strip, and your click-cast keys",
                "Quests with their level, XP and chain, the objectives ticked",
                "/mdltip sets each kind's look against a live sample"],
         imgs=[("tooltip-spell.png", None, []), ("tooltip-quest.png", None, [])], place="column", most=1.45),
    dict(key="settings", label="Settings", title="Every part, switchable",
         items=["Turn off any part you'd rather keep from another addon",
                "Shared settings in one place, a frame's own marked Own",
                "Profiles keep settings, bars and key bindings"],
         imgs=[("settings-general.png", None, []), ("settings-immersion.png", None, []),
               ("settings-paging.png", None, [])], place="cascade"),
    dict(key="radial", label="Companion · Radial menu", title="Hold, sweep, let go",
         sub="Spells, items, mounts, markers and emotes on a wheel, in combat too, built in an editor "
             "window. The optional mdlui_RadialMenu addon.",
         imgs=[("radialmenu-showcase/radial-every-radial.png", None, [])], place="row"),
]


# ------------------------------------------------------------------ drawing
def font(path, size):
    return ImageFont.truetype(path, size)


def wrap(draw, text, f, width):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=f) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def balanced(draw, text, f, width):
    """As few lines as wrap gives, each as even as can be (no lone last word)."""
    lines = wrap(draw, text, f, width)
    if len(lines) < 2:
        return lines
    lo, hi = 1, width
    while lo < hi:
        mid = (lo + hi) // 2
        if len(wrap(draw, text, f, mid)) <= len(lines):
            hi = mid
        else:
            lo = mid + 1
    return wrap(draw, text, f, lo)


def spaced(draw, xy, text, f, fill, spacing):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=f, fill=fill)
        x += draw.textlength(ch, font=f) + spacing
    return x


_GROUND = None


def ground():
    global _GROUND
    if _GROUND is None:
        _GROUND = _ground()
    return _GROUND.copy()


def _ground():
    # a faint fall from top to foot: one column, stretched
    col = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / H
        col.putpixel((0, y), tuple(int(INK[i] + (26 - INK[i]) * (1 - t) * 0.35) for i in range(3)))
    img = col.resize((W, H))
    glow = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(glow)
    gd.ellipse((1000, 80, 1900, 980), fill=60)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    img = Image.composite(Image.new("RGB", (W, H), (70, 56, 28)), img, glow)
    rings = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rings)
    cx, cy = 2050, 180
    for r in range(80, 2400, 62):
        rd.ellipse((cx - r, cy - r, cx + r, cy + r), outline=GOLD + (9,), width=1)
    img.paste(rings, (0, 0), rings)
    return img.convert("RGBA")


def badge(card, cx, cy, n, r=23):
    d = ImageDraw.Draw(card)
    sh = Image.new("RGBA", card.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((cx - r - 4, cy - r + 2, cx + r + 4, cy + r + 8), fill=(0, 0, 0, 150))
    sh = sh.filter(ImageFilter.GaussianBlur(5))
    card.alpha_composite(sh)
    d.ellipse((cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3), fill=DARK)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=BRIGHT)
    f = font(BODY, 32)
    d.text((cx, cy - 1), str(n), font=f, fill=INK, anchor="mm")


def shot(card, im, x, y):
    w, h = im.size
    sh = Image.new("RGBA", card.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rectangle((x - 6, y + 4, x + w + 6, y + h + 18), fill=(0, 0, 0, 170))
    sh = sh.filter(ImageFilter.GaussianBlur(18))
    card.alpha_composite(sh)
    card.paste(im.convert("RGB"), (x, y))
    ImageDraw.Draw(card).rectangle((x - 1, y - 1, x + w, y + h), outline=DARK, width=1)


def load(spec):
    name, crop, badges = spec
    im = Image.open(src(name)).convert("RGBA")
    if crop:
        im = im.crop(crop)
        badges = [(n, bx - crop[0], by - crop[1]) for n, bx, by in badges]
    return im, badges


def place(card, imgs, box, how, most):
    """Scale and place the images in box; returns each one's (x, y, scale)."""
    bx, by, bw, bh = box
    gap = 36
    sizes = [im.size for im, _ in imgs]
    n = len(sizes)
    spots = []
    if how == "row":
        # one height for all, as tall as fits
        hh = min(bh, (bw - gap * (n - 1)) / sum(w / h for w, h in sizes))
        s = [min(most, hh / h) for w, h in sizes]
        ws = [w * k for (w, h), k in zip(sizes, s)]
        x = bx + (bw - sum(ws) - gap * (n - 1)) / 2
        for (w, h), k, ww in zip(sizes, s, ws):
            spots.append((x, by + (bh - h * k) / 2, k))
            x += ww + gap
    elif how == "column":
        k = min(most, min(bw / w for w, h in sizes), (bh - gap * (n - 1)) / sum(h for w, h in sizes))
        y = by + (bh - sum(h * k for w, h in sizes) - gap * (n - 1)) / 2
        for w, h in sizes:
            spots.append((bx + (bw - w * k) / 2, y, k))
            y += h * k + gap
    elif how == "fan":
        drop = 50
        k = min(most, min((bh - drop * (n - 1)) / h for w, h in sizes))
        ws = [w * k for w, h in sizes]
        step = (bw - ws[-1]) / (n - 1)
        step = min(step, max(ws) + gap)
        x0 = bx + (bw - step * (n - 1) - ws[-1]) / 2
        for i, (w, h) in enumerate(sizes):
            spots.append((x0 + step * i, by + drop * i, k))
    elif how == "cascade":
        k = min(most, min(bw * 0.78 / w for w, h in sizes), min(bh * 0.62 / h for w, h in sizes))
        ws, hs = [w * k for w, h in sizes], [h * k for w, h in sizes]
        dx = (bw - ws[-1]) / (n - 1)
        dy = (bh - hs[-1]) / (n - 1)
        for i in range(n):
            spots.append((bx + dx * i, by + dy * i, k))
    for (im, badges), (x, y, k) in zip(imgs, spots):
        w, h = im.size
        scaled = im.resize((round(w * k), round(h * k)), Image.LANCZOS)
        shot(card, scaled, round(x), round(y))
    # badges last, over every image
    for (im, badges), (x, y, k) in zip(imgs, spots):
        for nb, px_, py_ in badges:
            badge(card, round(x + px_ * k), round(y + py_ * k), nb)


def byline(card, x, y, right=False):
    d = ImageDraw.Draw(card)
    icon = Image.open(ICON).convert("RGBA").resize((64, 64), Image.LANCZOS)
    name_f, by_f = font(SERIF_CAPS, 36), font(BODY, 28)
    total = 64 + 16 + d.textlength("MedalUI", font=name_f) + 22 + d.textlength(BYLINE, font=by_f)
    if right:
        x -= total
    card.alpha_composite(icon, (round(x), round(y - 32)))
    x += 64 + 16
    d.text((x, y), "MedalUI", font=name_f, fill=WHITE, anchor="lm")
    x += d.textlength("MedalUI", font=name_f) + 22
    d.text((x, y + 2), BYLINE, font=by_f, fill=DIM, anchor="lm")


def text_block(card, c, x, width, measure=False):
    """The label, headline and line(s) from y 0; returns its height."""
    d = ImageDraw.Draw(card)
    label_f = font(SERIF_CAPS, 34)
    title_f = font(SERIF_CAPS, 86 if c.get("layout") != "top" else 84)
    body_f = font(BODY, 36)
    parts = []                                   # (dy, draw(y))
    y = 0
    parts.append((y, lambda yy: spaced(d, (x, yy), c["label"].upper(), label_f, BRIGHT, 6)))
    y += 34 + 26
    for line in balanced(d, c["title"], title_f, width):
        parts.append((y, lambda yy, line=line: d.text((x - 4, yy), line, font=title_f, fill=WHITE)))
        y += int(title_f.size * 1.08)
    y += 30
    if c.get("sub"):
        for line in wrap(d, c["sub"], body_f, width):
            parts.append((y, lambda yy, line=line: d.text((x, yy), line, font=body_f, fill=GREY)))
            y += 46
    for i, item in enumerate(c.get("items", [])):
        lines = wrap(d, item, body_f, width - 70)
        parts.append((y, lambda yy, i=i: badge(card, x + 23, yy + 22, i + 1)))
        for line in lines:
            parts.append((y, lambda yy, line=line: d.text((x + 70, yy), line, font=body_f, fill=GREY)))
            y += 46
        y += 26
    return y, parts


def render(n, c):
    card = ground()
    imgs = [load(s) for s in c["imgs"]]
    if c.get("layout") == "top":
        h, parts = text_block(card, c, TEXT_X, 1680)
        for dy, fn in parts:
            fn(70 + dy)
        place(card, imgs, TOP_ART, c["place"], c.get("most", 1.0))
        byline(card, W - 120, 104, right=True)
    else:
        h, parts = text_block(card, c, TEXT_X, TEXT_W)
        top = max(90, (H - 120 - h) / 2)
        for dy, fn in parts:
            fn(round(top + dy))
        place(card, imgs, ART, c["place"], c.get("most", 1.0))
        byline(card, TEXT_X, 990)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "%02d-%s.png" % (n, c["key"]))
    # 256 colours, dithered: under half the size, no banding on the ground
    card.convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT,
                                 dither=Image.Dither.FLOYDSTEINBERG).save(path, optimize=True)
    return path


def main(keys):
    for n, c in enumerate(CARDS, 1):
        if keys and c["key"] not in keys:
            continue
        path = render(n, c)
        print("%s  %d KB" % (os.path.relpath(path, ROOT), os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main(sys.argv[1:])
