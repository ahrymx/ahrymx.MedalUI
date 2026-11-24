"""The radial editor's category tiles' glyphs and the sidebar's cog (2026-11-22), white on clear, 32x32
TGAs, tinted in game. Usage: python3 tools/radial_glyphs.py WoW/Interface/AddOns/mdlui_RadialMenu/art/ui

Drawn at 8x on a 14-unit grid (the mockup's SVG viewBox), then reduced."""
import math
import sys
from PIL import Image, ImageDraw

OUT = sys.argv[1]
SS, SIZE, UNIT = 8, 32, 14
K = SIZE * SS / UNIT
W = 1.5 * K  # stroke


def pt(x, y):
    return (x * K, y * K)


def line(d, pts, closed=False):
    pts = [pt(*p) for p in pts]
    if closed:
        pts = pts + [pts[0]]
    d.line(pts, fill=255, width=int(W), joint="curve")
    for p in pts:
        r = W / 2
        d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=255)


def circle(d, cx, cy, r):
    cx, cy, r = cx * K, cy * K, r * K
    d.ellipse((cx - r - W / 2, cy - r - W / 2, cx + r + W / 2, cy + r + W / 2), fill=255)
    d.ellipse((cx - r + W / 2, cy - r + W / 2, cx + r - W / 2, cy + r - W / 2), fill=0)


def arc(d, cx, cy, r, a0, a1):
    n = 24
    line(d, [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
              cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)])


def combat(d):
    # two blades crossed, each with its guard and grip
    line(d, [(2, 2), (9.5, 9.5)])
    line(d, [(12, 2), (4.5, 9.5)])
    line(d, [(8, 11), (11, 8)])
    line(d, [(6, 11), (3, 8)])
    line(d, [(9.5, 9.5), (12, 12)])
    line(d, [(4.5, 9.5), (2, 12)])


def healing(d):
    line(d, [(7, 2), (7, 12)])
    line(d, [(2, 7), (12, 7)])


def social(d):
    line(d, [(2, 3.5), (12, 3.5), (12, 9.5), (6.5, 9.5), (3.5, 12), (3.5, 9.5), (2, 9.5)], True)


def group(d):
    line(d, [(3.5, 12.5), (3.5, 1.5)])
    line(d, [(3.5, 2), (11.5, 2), (9.5, 4.75), (11.5, 7.5), (3.5, 7.5)])


def items(d):
    line(d, [(2.5, 5), (11.5, 5), (10.5, 12.5), (3.5, 12.5)], True)
    arc(d, 7, 5, 2, 180, 360)


def travel(d):
    circle(d, 7, 7, 5.5)
    line(d, [(7, 3.5), (8.4, 7), (7, 10.5), (5.6, 7)], True)


def unfiled(d):
    # (2026-11-24) an inbox tray: the radials in no category
    line(d, [(2, 8), (3.5, 3), (10.5, 3), (12, 8)])
    line(d, [(2, 8), (2, 12), (12, 12), (12, 8)])
    line(d, [(2, 8), (5, 8), (5.75, 9.75), (8.25, 9.75), (9, 8), (12, 8)])


def cog(d):
    circle(d, 7, 7, 2.3)
    for a in range(0, 360, 45):
        c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
        line(d, [(7 + 4.3 * c, 7 + 4.3 * s), (7 + 6 * c, 7 + 6 * s)])


for name, draw in [("CatCombat", combat), ("CatHealing", healing), ("CatSocial", social), ("CatGroup", group),
                   ("CatItems", items), ("CatTravel", travel), ("CatUnfiled", unfiled), ("Cog", cog)]:
    mask = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    draw(ImageDraw.Draw(mask))
    # the 14-unit grid centred in 32 px with a 1-unit margin each side is built in: K spans the
    # whole tile, so shrink toward the centre a little for breathing room
    mask = mask.resize((SIZE, SIZE), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    out.putalpha(mask)
    out.save(f"{OUT}/{name}.tga")
    print(name, mask.getextrema())
