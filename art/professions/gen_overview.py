#!/usr/bin/env python3
"""The professions' Overview artwork (professions/window.lua), in the
layered, illustrated look the user chose (2026-11-17,
/workspace/professions-art-mock.png): soft gradients, silhouettes in ranks,
mist and glow, dark enough that the page's words read over it.

- A scene for each primary profession, behind its pillar: its craft at
  the foot (a meadow, a lamplit cave, a forge...), fading out to nothing
  towards the top, where the pillar's icon, name and bar stand.
- One scene behind the other three sections, in two pieces so it never
  stretches: the sky (stars, the milky way, a moon), hung from the
  Secondary professions' heading, and the land (mountains, ranks of firs,
  the forest floor and the camp), standing on Camping's foot. Between them,
  on a tall screen, the code fills the horizon's colour (HORIZON).

    python3 art/professions/gen_overview.py   -> assets/professions/*.png,
        media/professions/<skillLine>.tga, sky.tga and land.tga,
        render/overview.png

Drawn in "design" pixels, 1.35 to a UI unit (the screenshot's scale), and
rendered at the texture's own:
  a pillar's scene: 219 x 342 units, the bottom 256x400 of a 256x512;
  the sky: 444 x 300 units, the top 512x346 of a 512x512;
  the land: 444 x 348 units, the bottom 512x401 of a 512x512.
The code shows the part it has room for, by texture coordinates.
"""
import math
import os
import random
import subprocess
import sys
from io import BytesIO

from PIL import Image, ImageChops, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
import export  # noqa: E402

D = 1.35                                # design pixels to a unit
PILLAR = (296, 462, 256, 400, 512)      # design w, h; rendered w, h; the texture's height
SKY = (600, 405, 512, 346, 512)
LAND = (600, 470, 512, 401, 512)
HORIZON = "#232532"                     # the sky's foot; the code fills it between the sky and the land
GOLD = "#c4a557"


def render(defs, body, size):
    dw, dh, w, h, _ = size
    doc = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {dw} {dh}">'
           f'<defs>{defs}</defs>{body}</svg>')
    out = subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h)], input=doc.encode(), capture_output=True,
                         check=True).stdout
    return Image.open(BytesIO(out)).convert("RGBA")


def fade(img, top=None, foot=None):
    """Clear at the top, full from `top` (a fraction of the height) down;
    and clear at the foot over its last `foot` pixels."""
    w, h = img.size
    m = Image.new("L", (w, h), 255)
    d = ImageDraw.Draw(m)
    for y in range(h):
        a = 1.0
        if top:
            t = min(1.0, y / (h * top))
            a = t * t * (3 - 2 * t)
        if foot and h - y < foot:
            a = min(a, (h - y) / foot)
        d.line([(0, y), (w, y)], fill=int(255 * a))
    img.putalpha(ImageChops.multiply(img.split()[3], m))
    return img


# ----------------------------------------------------------------- shapes
def ridge(rnd, w, base, amp, step, jag=0.5):
    """A hill or mountain line, left to right."""
    pts, x = [], -10.0
    y = base - rnd.uniform(0, amp)
    while x < w + step:
        pts.append((x, y))
        x += step * rnd.uniform(0.6, 1.4)
        y = min(base, max(base - amp, y + rnd.uniform(-amp, amp) * jag))
    return pts


def poly(pts, foot):
    return (f"M{pts[0][0]:.1f} {foot} " + " ".join(f"L{x:.1f} {y:.1f}" for x, y in pts)
            + f" L{pts[-1][0]:.1f} {foot} Z")


def smooth(pts, foot):
    d = f"M{pts[0][0]:.1f} {foot} L{pts[0][0]:.1f} {pts[0][1]:.1f} "
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        d += f"Q{x0:.1f} {y0:.1f} {(x0 + x1) / 2:.1f} {(y0 + y1) / 2:.1f} "
    return d + f"L{pts[-1][0]:.1f} {pts[-1][1]:.1f} L{pts[-1][0]:.1f} {foot} Z"


def under(pts, x, fallback):
    near = [y for xx, y in pts if abs(xx - x) < 70]
    return min(near) if near else fallback


def pine(x, base, h):
    """A fir: three tiers and a trunk."""
    w = h * 0.42
    d = ""
    for t0, t1, sw in ((0.0, 0.42, 0.55), (0.25, 0.7, 0.8), (0.5, 0.95, 1.0)):
        top, bot = base - h + h * t0, base - h + h * t1
        hw = w / 2 * sw
        d += (f"M{x:.1f} {top:.1f} L{x + hw:.1f} {bot:.1f} L{x + hw * 0.35:.1f} {bot - 2:.1f} "
              f"L{x - hw * 0.35:.1f} {bot - 2:.1f} L{x - hw:.1f} {bot:.1f} Z ")
    return d + f"M{x - h * 0.03:.1f} {base - h * 0.08:.1f} h{h * 0.06:.1f} v{h * 0.1:.1f} h{-h * 0.06:.1f} Z "


def gear(cx, cy, r, teeth, hole=0.35):
    pts = []
    for i in range(teeth * 4):
        a = i / (teeth * 4) * 2 * math.pi
        rr = r if i % 4 in (1, 2) else r * 0.84
        pts.append(f"{cx + rr * math.cos(a):.1f} {cy + rr * math.sin(a):.1f}")
    d = "M" + " L".join(pts) + " Z"
    hr = r * hole
    return d + f" M{cx + hr:.1f} {cy} A{hr:.1f} {hr:.1f} 0 1 0 {cx - hr:.1f} {cy} A{hr:.1f} {hr:.1f} 0 1 0 " \
               f"{cx + hr:.1f} {cy} Z"


def motes(rnd, n, box, col, r=(0.8, 1.6), a=(0.3, 0.8), blur=False):
    x0, y0, x1, y1 = box
    out = ""
    for _ in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        rr = rnd.uniform(*r)
        f = ' filter="url(#b)"' if blur else ""
        out += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{rr:.1f}" fill="{col}" opacity="{rnd.uniform(*a):.2f}"{f}/>'
    return out


def ground(top, bottom, glow=None, cy=0.8):
    """A scene's ground: clear at the top, its colour at the foot; glow, a
    soft pool of light low in it."""
    g = (f'<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
         f'<stop offset="0" stop-color="{top}" stop-opacity="0"/>'
         f'<stop offset="0.45" stop-color="{top}" stop-opacity="0.9"/>'
         f'<stop offset="1" stop-color="{bottom}"/></linearGradient>'
         '<filter id="b"><feGaussianBlur stdDeviation="1.6"/></filter>'
         '<filter id="g"><feGaussianBlur stdDeviation="4"/></filter>'
         '<filter id="gg"><feGaussianBlur stdDeviation="10"/></filter>')
    if glow:
        g += (f'<radialGradient id="glow" cx="0.5" cy="{cy}"><stop offset="0" stop-color="{glow}" '
              f'stop-opacity="0.26"/><stop offset="1" stop-color="{glow}" stop-opacity="0"/></radialGradient>')
    w, h = PILLAR[0], PILLAR[1]
    body = f'<rect width="{w}" height="{h}" fill="url(#bg)"/>'
    if glow:
        body += f'<rect width="{w}" height="{h}" fill="url(#glow)"/>'
    return g, body


# ------------------------------------------------------- the pillars' scenes
# Each 296x462 design pixels; the craft low, under the pillar's spells.
def herbalism(rnd, w, h):
    defs, body = ground("#16201a", "#1c2a1e", "#9ccf7a")
    for base, amp, col in ((h * 0.72, 30, "#1a2a20"), (h * 0.84, 22, "#18271c"), (h * 0.94, 14, "#121c14")):
        body += f'<path d="{smooth(ridge(rnd, w, base, amp, 70, 0.6), h)}" fill="{col}"/>'
    for _ in range(9):
        x = rnd.uniform(8, w - 8)
        top = h - rnd.uniform(70, 170)
        bend = rnd.uniform(-14, 14)
        body += (f'<path d="M{x:.1f} {h} Q{x + bend:.1f} {(h + top) / 2:.1f} {x + bend * 0.6:.1f} {top:.1f}" '
                 f'stroke="#203a26" stroke-width="2.2" fill="none"/>')
        for k in range(3):
            ly = top + (h - top) * (0.25 + 0.22 * k)
            side = 1 if k % 2 else -1
            lx = x + bend * (1 - (ly - top) / (h - top)) * 0.8
            body += (f'<path d="M{lx:.1f} {ly:.1f} q{side * 14:.1f} -12 {side * 26:.1f} -6 '
                     f'q{-side * 12:.1f} 10 {-side * 26:.1f} 6 Z" fill="#24442b"/>')
        if rnd.random() < 0.6:
            fx, fy = x + bend * 0.6, top
            col = rnd.choice(["#e6d39a", "#c9a0d8", "#f0e8d0"])
            for p in range(6):
                a = p / 6 * 2 * math.pi
                px, py = fx + 5 * math.cos(a), fy + 5 * math.sin(a)
                body += (f'<ellipse cx="{px:.1f}" cy="{py:.1f}" rx="4" ry="2.2" transform="rotate('
                         f'{math.degrees(a):.0f} {px:.1f} {py:.1f})" fill="{col}" opacity="0.75"/>')
            body += f'<circle cx="{fx:.1f}" cy="{fy:.1f}" r="2.4" fill="#e8b84a"/>'
    body += motes(rnd, 22, (0, h * 0.45, w, h * 0.95), "#e8f0a0", (1.2, 1.8), (0.2, 0.6), True)
    return defs, body


def mining(rnd, w, h):
    defs, body = ground("#1c1a1c", "#211d1c", "#ffb860", 0.78)
    defs += ('<linearGradient id="cr" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#9fd8ff" '
             'stop-opacity="0.9"/><stop offset="1" stop-color="#3a6fa0" stop-opacity="0.8"/></linearGradient>')
    for base, amp, col in ((h * 0.64, 26, "#2a2526"), (h * 0.78, 22, "#221e1e"), (h * 0.92, 16, "#191616")):
        body += f'<path d="{poly(ridge(rnd, w, base, amp, 40, 0.9), h)}" fill="{col}"/>'
        for _ in range(3):
            x, y = rnd.uniform(10, w - 50), base + rnd.uniform(6, 26)
            body += f'<ellipse cx="{x + 20:.1f}" cy="{y:.1f}" rx="16" ry="7" fill="#ffcf6a" opacity="0.16" ' \
                    f'filter="url(#g)"/>'
            for _ in range(4):
                ox, oy, r = x + rnd.uniform(6, 34), y + rnd.uniform(-5, 5), rnd.uniform(1.6, 3.2)
                body += (f'<path d="M{ox - r:.1f} {oy:.1f} L{ox:.1f} {oy - r:.1f} L{ox + r:.1f} {oy:.1f} '
                         f'L{ox:.1f} {oy + r * 0.8:.1f} Z" fill="#e8b14a" opacity="0.85"/>')
    cx, cy = w * 0.78, h - 18
    body += f'<ellipse cx="{cx}" cy="{cy - 20}" rx="50" ry="40" fill="#6ab0e8" opacity="0.14" filter="url(#g)"/>'
    for dx, ht, wd, ang in ((-18, 44, 10, -18), (0, 64, 13, 0), (16, 50, 11, 16), (30, 30, 8, 30), (-32, 26, 8, -32)):
        x = cx + dx
        rot = f'transform="rotate({ang} {x:.1f} {cy})"'
        body += (f'<path d="M{x - wd / 2:.1f} {cy} L{x - wd / 2:.1f} {cy - ht * 0.75:.1f} L{x:.1f} {cy - ht:.1f} '
                 f'L{x + wd / 2:.1f} {cy - ht * 0.75:.1f} L{x + wd / 2:.1f} {cy} Z" fill="url(#cr)" {rot} '
                 f'opacity="0.8"/><path d="M{x:.1f} {cy - ht:.1f} L{x:.1f} {cy}" stroke="#e6f6ff" '
                 f'stroke-width="0.8" {rot} opacity="0.6"/>')
    px, py = w * 0.26, h - 24
    body += (f'<path d="M{px} {py} L{px + 46} {py - 86}" stroke="#4a3220" stroke-width="5" stroke-linecap="round"/>'
             f'<path d="M{px + 22} {py - 92} Q{px + 46} {py - 104} {px + 74} {py - 84} Q{px + 48} {py - 92} '
             f'{px + 22} {py - 86} Z" fill="#8c8a90"/>'
             f'<circle cx="{px - 14}" cy="{py - 30}" r="26" fill="#ffb860" opacity="0.22" filter="url(#g)"/>'
             f'<rect x="{px - 20}" y="{py - 40}" width="12" height="16" rx="2" fill="#ffcf7a" opacity="0.85"/>'
             f'<path d="M{px - 22} {py - 40} h16 M{px - 14} {py - 40} v-6" stroke="#3a2a18" stroke-width="2"/>')
    body += motes(rnd, 18, (0, h * 0.55, w, h * 0.95), "#ffe6a0", (0.8, 1.0))
    return defs, body


def alchemy(rnd, w, h):
    defs, body = ground("#1a1626", "#211a2c", "#5ad08a", 0.82)
    # a shelf of bottles behind, a table in front
    sy = h - 150
    body += f'<rect x="0" y="{sy}" width="{w}" height="6" fill="#2a2030"/>'
    x = 10
    while x < w - 20:
        bw, bh = rnd.uniform(10, 18), rnd.uniform(22, 44)
        neck = bw * 0.4
        body += (f'<path d="M{x:.1f} {sy} L{x:.1f} {sy - bh * 0.7:.1f} Q{x:.1f} {sy - bh * 0.8:.1f} '
                 f'{x + (bw - neck) / 2:.1f} {sy - bh * 0.82:.1f} L{x + (bw - neck) / 2:.1f} {sy - bh:.1f} '
                 f'L{x + (bw + neck) / 2:.1f} {sy - bh:.1f} L{x + (bw + neck) / 2:.1f} {sy - bh * 0.82:.1f} '
                 f'Q{x + bw:.1f} {sy - bh * 0.8:.1f} {x + bw:.1f} {sy - bh * 0.7:.1f} L{x + bw:.1f} {sy} Z" '
                 f'fill="#17121e"/>')
        if rnd.random() < 0.4:
            col = rnd.choice(["#7a5ad0", "#d05a7a", "#5ab0d0"])
            body += f'<rect x="{x + 2:.1f}" y="{sy - bh * 0.4:.1f}" width="{bw - 4:.1f}" height="{bh * 0.38:.1f}" ' \
                    f'fill="{col}" opacity="0.35"/>'
        x += bw + rnd.uniform(4, 12)
    ty = h - 40
    body += f'<rect x="0" y="{ty}" width="{w}" height="40" fill="#15111a"/>'
    body += f'<rect x="0" y="{ty}" width="{w}" height="2" fill="#3a2e44"/>'
    # the flask, its brew glowing green, vapour over it
    fx, fy, r = w * 0.62, ty - 30, 30
    body += f'<circle cx="{fx}" cy="{fy}" r="{r + 26}" fill="#5ad08a" opacity="0.18" filter="url(#gg)"/>'
    body += (f'<path d="M{fx - 7} {fy - r - 30} L{fx - 7} {fy - r + 4} A{r} {r} 0 1 0 {fx + 7} {fy - r + 4} '
             f'L{fx + 7} {fy - r - 30} Z" fill="#20302a" opacity="0.7" stroke="#a8e0c0" stroke-width="1.2" '
             f'stroke-opacity="0.5"/>')
    body += (f'<path d="M{fx - r + 2} {fy + 2} A{r - 2} {r - 2} 0 0 0 {fx + r - 2} {fy + 2} Z" fill="#5ad08a" '
             f'opacity="0.75"/>')
    body += motes(rnd, 8, (fx - 16, fy - 10, fx + 16, fy + 20), "#d8ffe6", (1.2, 2.4), (0.5, 0.9))
    for k in range(3):
        sx = fx + rnd.uniform(-4, 4)
        body += (f'<path d="M{sx:.1f} {fy - r - 32} q{-10 + k * 8} -20 {4 + k * 2} -40 q{12 - k * 6} -18 '
                 f'{-2 + k * 3} -36" stroke="#a8e0c0" stroke-width="2.2" fill="none" opacity="0.22" '
                 f'filter="url(#b)"/>')
    # a candle at the left
    cx = w * 0.18
    body += (f'<circle cx="{cx}" cy="{ty - 34}" r="20" fill="#ffb860" opacity="0.2" filter="url(#g)"/>'
             f'<rect x="{cx - 5}" y="{ty - 26}" width="10" height="26" fill="#d8ccb0" opacity="0.8"/>'
             f'<path d="M{cx} {ty - 38} q4 6 0 10 q-4 -4 0 -10 Z" fill="#ffd27a"/>')
    return defs, body


def blacksmithing(rnd, w, h):
    defs, body = ground("#1e1814", "#231a14", "#ff7a2a", 0.85)
    # a stone wall, the forge's mouth glowing in it at the right
    for row in range(5):
        y = h - 200 + row * 26
        off = 0 if row % 2 else 18
        for x in range(-18 + off, w, 36):
            body += f'<rect x="{x + 1}" y="{y + 1}" width="34" height="24" rx="3" fill="#221b17"/>'
    mx, my = w * 0.8, h - 70
    body += (f'<ellipse cx="{mx}" cy="{my}" rx="70" ry="60" fill="#ff7a2a" opacity="0.32" filter="url(#gg)"/>'
             f'<path d="M{mx - 36} {my + 30} L{mx - 36} {my - 6} A36 36 0 0 1 {mx + 36} {my - 6} L{mx + 36} '
             f'{my + 30} Z" fill="#ff8a2a" opacity="0.85"/>'
             f'<path d="M{mx - 26} {my + 30} L{mx - 26} {my} A26 26 0 0 1 {mx + 26} {my} L{mx + 26} {my + 30} Z" '
             f'fill="#ffd27a" opacity="0.8"/>')
    body += motes(rnd, 14, (mx - 30, my + 14, mx + 30, my + 30), "#fff0b0", (1.4, 2.6), (0.6, 1))
    body += f'<rect x="0" y="{h - 34}" width="{w}" height="34" fill="#161210"/>'
    # the anvil on its block, a hammer leaning on it
    ax, ay = w * 0.34, h - 34
    body += (f'<rect x="{ax - 16}" y="{ay - 26}" width="32" height="26" fill="#1a1412"/>'
             f'<path d="M{ax - 44} {ay - 46} L{ax + 34} {ay - 46} Q{ax + 52} {ay - 46} {ax + 62} {ay - 40} '
             f'L{ax + 30} {ay - 34} L{ax + 14} {ay - 34} L{ax + 10} {ay - 26} L{ax - 10} {ay - 26} '
             f'L{ax - 14} {ay - 34} L{ax - 36} {ay - 34} Q{ax - 44} {ay - 38} {ax - 44} {ay - 46} Z" fill="#141012"/>'
             f'<path d="M{ax - 44} {ay - 46} L{ax + 34} {ay - 46} Q{ax + 52} {ay - 46} {ax + 62} {ay - 40}" '
             f'stroke="#c47a3a" stroke-width="1.4" fill="none" opacity="0.7"/>'
             f'<path d="M{ax - 70} {ay} L{ax - 40} {ay - 60}" stroke="#3a2818" stroke-width="5" '
             f'stroke-linecap="round"/><rect x="{ax - 52}" y="{ay - 72}" width="26" height="12" rx="2" '
             f'fill="#5a5258" transform="rotate(26 {ax - 40} {ay - 66})"/>')
    # sparks thrown up from the anvil: short streaks, fanning out
    for _ in range(16):
        a = rnd.uniform(-2.5, -0.65)
        r0, r1 = rnd.uniform(10, 30), rnd.uniform(4, 9)
        sx, sy = ax + 6 + math.cos(a) * r0, ay - 50 + math.sin(a) * r0
        body += (f'<path d="M{sx:.1f} {sy:.1f} l{math.cos(a) * r1:.1f} {math.sin(a) * r1:.1f}" stroke="#ffc060" '
                 f'stroke-width="1.3" stroke-linecap="round" opacity="{rnd.uniform(0.5, 1):.2f}"/>')
    return defs, body


def enchanting(rnd, w, h):
    defs, body = ground("#1b1530", "#1d1630", "#b88cff", 0.86)
    defs += ('<linearGradient id="beam" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#c8a8ff" '
             'stop-opacity="0.32"/><stop offset="1" stop-color="#c8a8ff" stop-opacity="0"/></linearGradient>'
             '<linearGradient id="gem" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f0d8ff"/>'
             '<stop offset="1" stop-color="#7a4ad0"/></linearGradient>')
    cx, cy = w / 2, h - 44
    body += f'<path d="M{cx - 90} {cy} L{cx - 50} {cy - 210} L{cx + 50} {cy - 210} L{cx + 90} {cy} Z" ' \
            f'fill="url(#beam)"/>'
    for rx, ry, a in ((110, 28, 0.55), (84, 21, 0.4), (58, 14, 0.35)):
        body += (f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="none" stroke="#b88cff" stroke-width="5" '
                 f'opacity="{a * 0.4}" filter="url(#g)"/><ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" '
                 f'fill="none" stroke="#d8c0ff" stroke-width="1.2" opacity="{a}"/>')
    for k in range(16):
        a = k / 16 * 2 * math.pi
        x, y = cx + 97 * math.cos(a), cy + 24.5 * math.sin(a)
        body += f'<path d="M{x - 3:.1f} {y:.1f} L{x:.1f} {y - 4:.1f} L{x + 3:.1f} {y:.1f} L{x:.1f} {y + 4:.1f} Z" ' \
                f'fill="#e8d8ff" opacity="0.6"/>'
    gy = cy - 96
    body += (f'<ellipse cx="{cx}" cy="{gy}" rx="34" ry="34" fill="#b88cff" opacity="0.25" filter="url(#gg)"/>'
             f'<path d="M{cx} {gy - 30} L{cx + 14} {gy - 6} L{cx} {gy + 30} L{cx - 14} {gy - 6} Z" fill="url(#gem)" '
             f'opacity="0.9"/><path d="M{cx} {gy - 30} L{cx} {gy + 30} M{cx - 14} {gy - 6} L{cx + 14} {gy - 6}" '
             f'stroke="#fff" stroke-width="0.7" opacity="0.5"/>')
    body += motes(rnd, 30, (10, h * 0.5, w - 10, h - 20), "#e0c8ff", (0.8, 2), (0.3, 0.9), True)
    body += motes(rnd, 12, (10, h * 0.55, w - 10, h - 20), "#a8f0ff", (0.8, 1.4), (0.4, 0.9))
    return defs, body


def engineering(rnd, w, h):
    defs, body = ground("#141b22", "#141c24", "#6ab8ff", 0.8)
    body += f'<path d="{gear(w * 0.16, h - 40, 74, 12)}" fill="#18212b" fill-rule="evenodd"/>'
    body += f'<path d="{gear(w * 0.74, h - 70, 54, 10)}" fill="#1d2833" fill-rule="evenodd"/>'
    body += f'<path d="{gear(w * 0.46, h - 120, 30, 8)}" fill="none" stroke="{GOLD}" stroke-width="1.6" ' \
            f'opacity="0.55"/>'
    body += f'<path d="{gear(w * 0.92, h - 150, 20, 7)}" fill="none" stroke="{GOLD}" stroke-width="1.2" ' \
            f'opacity="0.4"/>'
    # pipes along the foot, a joint and a gauge
    py = h - 26
    body += (f'<rect x="0" y="{py}" width="{w}" height="12" fill="#26313c"/><rect x="0" y="{py}" width="{w}" '
             f'height="2" fill="#4a5a68"/><rect x="{w * 0.55}" y="{py - 4}" width="16" height="20" rx="2" '
             f'fill="#323e4a"/><circle cx="{w * 0.36}" cy="{py - 16}" r="12" fill="#1a222a" stroke="{GOLD}" '
             f'stroke-width="1.2" stroke-opacity="0.6"/><path d="M{w * 0.36} {py - 16} l6 -6" stroke="#ff8a5a" '
             f'stroke-width="1.4"/>')
    # a spark arcing between two posts
    x0, x1, y = w * 0.5, w * 0.68, h - 160
    body += (f'<rect x="{x0 - 3}" y="{y}" width="6" height="40" fill="#2a3440"/><rect x="{x1 - 3}" y="{y}" '
             f'width="6" height="40" fill="#2a3440"/>')
    pts, x = [], x0
    while x < x1:
        pts.append(f"{x:.1f} {y + rnd.uniform(-8, 8):.1f}")
        x += 6
    pts.append(f"{x1:.1f} {y}")
    bolt = "M" + " L".join(pts)
    body += (f'<path d="{bolt}" stroke="#8fd8ff" stroke-width="5" fill="none" opacity="0.4" filter="url(#g)"/>'
             f'<path d="{bolt}" stroke="#e8f8ff" stroke-width="1.2" fill="none"/>')
    body += motes(rnd, 16, (10, h * 0.55, w - 10, h - 30), "#a8e0ff", (0.8, 1.4), (0.3, 0.8))
    return defs, body


def leatherworking(rnd, w, h):
    defs, body = ground("#1f1610", "#22180f", "#ffb060", 0.8)
    defs += ('<radialGradient id="hide" cx="0.5" cy="0.45"><stop offset="0" stop-color="#7a5232"/>'
             '<stop offset="1" stop-color="#3e2a19"/></radialGradient>')
    # a frame, a hide laced into it
    fx0, fx1, fy0, fy1 = w * 0.2, w * 0.86, h - 190, h - 26
    body += (f'<rect x="{fx0 - 4}" y="{fy0 - 10}" width="8" height="{fy1 - fy0 + 30}" fill="#2c1f13"/>'
             f'<rect x="{fx1 - 4}" y="{fy0 - 10}" width="8" height="{fy1 - fy0 + 30}" fill="#2c1f13"/>'
             f'<rect x="{fx0 - 12}" y="{fy0}" width="{fx1 - fx0 + 24}" height="7" fill="#33241a"/>'
             f'<rect x="{fx0 - 12}" y="{fy1 - 14}" width="{fx1 - fx0 + 24}" height="7" fill="#33241a"/>')
    cx, cy = (fx0 + fx1) / 2, (fy0 + fy1) / 2 - 4
    pts = []
    for k in range(18):
        a = k / 18 * 2 * math.pi
        rx, ry = (fx1 - fx0) / 2 - 20, (fy1 - fy0) / 2 - 22
        bump = 1 + (0.18 if k % 3 == 0 else 0) - (0.08 if k % 3 == 1 else 0)
        pts.append((cx + rx * bump * math.cos(a), cy + ry * bump * math.sin(a)))
    d = f"M{pts[0][0]:.1f} {pts[0][1]:.1f} " + " ".join(
        f"Q{pts[i][0]:.1f} {pts[i][1]:.1f} {(pts[i][0] + pts[(i + 1) % 18][0]) / 2:.1f} "
        f"{(pts[i][1] + pts[(i + 1) % 18][1]) / 2:.1f}" for i in range(18)) + " Z"
    body += f'<path d="{d}" fill="url(#hide)" opacity="0.95"/>'
    body += f'<path d="{d}" fill="none" stroke="#c9a26a" stroke-width="1.2" stroke-dasharray="4 4" ' \
            f'opacity="0.5" transform="translate({cx} {cy}) scale(0.9) translate({-cx} {-cy})"/>'
    for k in range(0, 18, 2):
        x, y = pts[k]
        tx = fx0 if x < cx - 20 else fx1 if x > cx + 20 else x
        ty = fy0 + 4 if y < cy - 20 else fy1 - 10 if y > cy + 20 else y
        body += f'<path d="M{x:.1f} {y:.1f} L{tx:.1f} {ty:.1f}" stroke="#8a6a44" stroke-width="1" opacity="0.7"/>'
    # a knife and an awl on the floor, a lantern's light from the left
    body += (f'<circle cx="{w * 0.06}" cy="{h - 120}" r="40" fill="#ffb060" opacity="0.16" filter="url(#gg)"/>'
             f'<rect x="0" y="{h - 14}" width="{w}" height="14" fill="#18110b"/>')
    return defs, body


def skinning(rnd, w, h):
    defs, body = ground("#151a1e", "#151a1e", "#a8c0d8", 0.6)
    for base, th, col, gap in ((h - 150, 40, "#1b2228", 14), (h - 100, 56, "#161c21", 20)):
        d, x = "", rnd.uniform(-10, 0)
        while x < w + 10:
            d += pine(x, base + rnd.uniform(0, 8), th * rnd.uniform(0.75, 1.15))
            x += gap * rnd.uniform(0.8, 1.6)
        body += f'<path d="{d}" fill="{col}"/>'
    body += f'<path d="{smooth(ridge(rnd, w, h - 40, 10, 60, 0.5), h)}" fill="#111518"/>'
    # a drying rack, two pelts on it
    rx0, rx1, ry = w * 0.22, w * 0.78, h - 150
    body += (f'<path d="M{rx0 - 20} {h - 30} L{rx0} {ry - 10} L{rx0 + 20} {h - 30} M{rx1 - 20} {h - 30} '
             f'L{rx1} {ry - 10} L{rx1 + 20} {h - 30}" stroke="#2e241c" stroke-width="5" fill="none"/>'
             f'<path d="M{rx0 - 10} {ry} L{rx1 + 10} {ry}" stroke="#3a2c20" stroke-width="5"/>')
    for px, pw, col in ((w * 0.38, 54, "#4a3626"), (w * 0.62, 46, "#5a4632")):
        body += (f'<path d="M{px - pw / 2:.1f} {ry} Q{px - pw / 2 - 8:.1f} {ry + 40} {px - pw / 2 + 4:.1f} '
                 f'{ry + 70} L{px - 8:.1f} {ry + 84} L{px:.1f} {ry + 100} L{px + 8:.1f} {ry + 84} '
                 f'L{px + pw / 2 - 4:.1f} {ry + 70} Q{px + pw / 2 + 8:.1f} {ry + 40} {px + pw / 2:.1f} {ry} Z" '
                 f'fill="{col}"/><path d="M{px - pw / 2 + 6:.1f} {ry + 6} L{px + pw / 2 - 6:.1f} {ry + 6}" '
                 f'stroke="#c9a26a" stroke-width="1" stroke-dasharray="3 3" opacity="0.5"/>')
    # a knife in a stump
    sx = w * 0.1
    body += (f'<rect x="{sx - 16}" y="{h - 44}" width="32" height="30" rx="3" fill="#2a2018"/>'
             f'<ellipse cx="{sx}" cy="{h - 44}" rx="16" ry="5" fill="#4a3a28"/>'
             f'<path d="M{sx + 2} {h - 46} L{sx + 8} {h - 78} L{sx + 12} {h - 76} L{sx + 6} {h - 46} Z" '
             f'fill="#b8c0c8" opacity="0.85"/><rect x="{sx + 7}" y="{h - 92}" width="6" height="16" rx="2" '
             f'fill="#3a2818" transform="rotate(10 {sx + 10} {h - 84})"/>')
    body += motes(rnd, 26, (0, h * 0.45, w, h - 20), "#e8f0ff", (0.8, 1.6), (0.2, 0.6), True)
    return defs, body


def tailoring(rnd, w, h):
    defs, body = ground("#1f151c", "#22161e", "#e090b0", 0.8)
    defs += ('<linearGradient id="cloth" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#4a2234"/>'
             '<stop offset="0.5" stop-color="#7a3a52"/><stop offset="1" stop-color="#4a2234"/></linearGradient>')
    # cloth draped across the foot, in folds
    body += (f'<path d="M0 {h - 90} Q{w * 0.3} {h - 130} {w * 0.55} {h - 96} Q{w * 0.8} {h - 64} {w} {h - 104} '
             f'L{w} {h} L0 {h} Z" fill="url(#cloth)"/>')
    for k in range(5):
        x = w * (0.1 + k * 0.2)
        body += (f'<path d="M{x:.1f} {h} Q{x + 10:.1f} {h - 50} {x - 4:.1f} {h - 100 + k * 6}" stroke="#2e1420" '
                 f'stroke-width="3" fill="none" opacity="0.6"/>')
    body += (f'<path d="M0 {h - 90} Q{w * 0.3} {h - 130} {w * 0.55} {h - 96} Q{w * 0.8} {h - 64} {w} {h - 104}" '
             f'stroke="#e0a0b8" stroke-width="1.2" fill="none" opacity="0.45"/>')
    # a spool, its thread
    sx, sy = w * 0.76, h - 150
    body += (f'<rect x="{sx - 20}" y="{sy - 40}" width="40" height="56" fill="#c9b48a" opacity="0.85"/>')
    for k in range(9):
        body += f'<path d="M{sx - 20} {sy - 36 + k * 6} L{sx + 20} {sy - 34 + k * 6}" stroke="#8a7650" ' \
                f'stroke-width="1" opacity="0.6"/>'
    body += (f'<ellipse cx="{sx}" cy="{sy - 42}" rx="28" ry="7" fill="#3a2418"/>'
             f'<ellipse cx="{sx}" cy="{sy + 18}" rx="28" ry="7" fill="#2c1a12"/>')
    # a needle, its thread looping from the spool
    nx0, ny0, nx1, ny1 = w * 0.14, h - 120, w * 0.44, h - 190
    body += (f'<path d="M{nx0} {ny0} L{nx1} {ny1}" stroke="#d8dce0" stroke-width="2.4" stroke-linecap="round"/>'
             f'<ellipse cx="{nx1 - 4}" cy="{ny1 + 2}" rx="3" ry="1.4" fill="#22161e" '
             f'transform="rotate(-24 {nx1 - 4} {ny1 + 2})"/>'
             f'<path d="M{nx1 - 4} {ny1 + 2} C{w * 0.6} {h - 240} {w * 0.5} {h - 120} {sx - 20} {sy - 10}" '
             f'stroke="#e8d8b0" stroke-width="1.2" fill="none" opacity="0.7"/>')
    for _ in range(5):
        x, y = rnd.uniform(20, w - 20), rnd.uniform(h - 60, h - 20)
        body += (f'<path d="M{x:.1f} {y:.1f} l10 -6" stroke="#d8dce0" stroke-width="1" opacity="0.7"/>'
                 f'<circle cx="{x:.1f}" cy="{y:.1f}" r="2" fill="#e05a7a"/>')
    body += motes(rnd, 14, (0, h * 0.5, w, h - 30), "#ffd8e8", (0.8, 1.4), (0.2, 0.6), True)
    return defs, body


PRIMARIES = {
    171: ("Alchemy", alchemy), 164: ("Blacksmithing", blacksmithing), 333: ("Enchanting", enchanting),
    202: ("Engineering", engineering), 182: ("Herbalism", herbalism), 165: ("Leatherworking", leatherworking),
    186: ("Mining", mining), 393: ("Skinning", skinning), 197: ("Tailoring", tailoring),
}


# ------------------------------------------------------- the night's scene
def sky():
    """Stars, the milky way, the moon; clear at its top, the horizon's
    colour at its foot."""
    w, h = SKY[0], SKY[1]
    rnd = random.Random(11)
    defs = f'''
      <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#0d1020" stop-opacity="0"/>
        <stop offset="0.10" stop-color="#0d1020" stop-opacity="1"/>
        <stop offset="0.55" stop-color="#161a2c"/>
        <stop offset="1" stop-color="{HORIZON}"/>
      </linearGradient>
      <radialGradient id="moonglow"><stop offset="0" stop-color="#e8dcb8" stop-opacity="0.35"/>
        <stop offset="1" stop-color="#e8dcb8" stop-opacity="0"/></radialGradient>
      <linearGradient id="milky" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#b8b4d8" stop-opacity="0"/>
        <stop offset="0.5" stop-color="#b8b4d8" stop-opacity="0.10"/>
        <stop offset="1" stop-color="#b8b4d8" stop-opacity="0"/></linearGradient>
      <filter id="soft"><feGaussianBlur stdDeviation="6"/></filter>'''
    body = f'<rect width="{w}" height="{h}" fill="url(#sky)"/>'
    body += (f'<path d="M-40 {h * 0.7} Q{w * 0.4} {h * 0.15} {w + 40} {-20} L{w + 40} 50 Q{w * 0.45} {h * 0.35} '
             f'-40 {h * 0.9} Z" fill="url(#milky)" filter="url(#soft)"/>')
    for _ in range(200):
        x = rnd.uniform(0, w)
        y = 20 + (h * 0.8) * (rnd.random() ** 1.4)
        r = rnd.choice([0.5, 0.6, 0.7, 0.9, 1.1, 1.4])
        a = rnd.uniform(0.25, 0.9) * (1 - 0.7 * y / h)
        col = rnd.choice(["#fff4d6", "#e8e6ff", "#ffe6b0"])
        body += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{col}" opacity="{a:.2f}"/>'
    for _ in range(8):
        x, y = rnd.uniform(20, w - 20), rnd.uniform(30, h * 0.5)
        body += (f'<path d="M{x:.1f} {y - 5:.1f} L{x + 1:.1f} {y - 1:.1f} L{x + 5:.1f} {y:.1f} L{x + 1:.1f} '
                 f'{y + 1:.1f} L{x:.1f} {y + 5:.1f} L{x - 1:.1f} {y + 1:.1f} L{x - 5:.1f} {y:.1f} L{x - 1:.1f} '
                 f'{y - 1:.1f} Z" fill="#fff1c8" opacity="0.75"/>')
    # the moon, between the second and third medallions
    mx, my = w * 0.67, 78
    body += f'<circle cx="{mx}" cy="{my}" r="46" fill="url(#moonglow)"/>'
    body += (f'<path d="M{mx - 2} {my - 13} A13 13 0 1 0 {mx + 9} {my + 9} A10 10 0 1 1 {mx - 2} {my - 13} Z" '
             f'fill="#efe2bd" opacity="0.85"/>')
    return render(defs, body, SKY)


def land():
    """Far mountains, ranks of firs in the mist, down to the forest floor
    and the camp in its clearing; clear above the mountains."""
    w, h = LAND[0], LAND[1]
    rnd = random.Random(23)
    defs = '''
      <radialGradient id="fire"><stop offset="0" stop-color="#ff9a3c" stop-opacity="0.5"/>
        <stop offset="0.45" stop-color="#d0601c" stop-opacity="0.18"/>
        <stop offset="1" stop-color="#d0601c" stop-opacity="0"/></radialGradient>
      <linearGradient id="mist" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#8f8fa6" stop-opacity="0"/>
        <stop offset="0.5" stop-color="#8f8fa6" stop-opacity="0.16"/>
        <stop offset="1" stop-color="#8f8fa6" stop-opacity="0"/></linearGradient>
      <linearGradient id="floor" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#121410"/><stop offset="1" stop-color="#0f0d0a"/></linearGradient>
      <filter id="b"><feGaussianBlur stdDeviation="2"/></filter>'''
    body = ""
    far = ridge(rnd, w, 96, 70, 46, 0.9)
    body += f'<path d="{poly(far, h)}" fill="#262b3d"/>'
    body += f'<rect x="0" y="70" width="{w}" height="60" fill="url(#mist)"/>'
    # ranks of firs, nearer ones darker and larger, down to the floor
    floor_y = h - 150
    ranks = [(128, 34, "#1d2230", 12), (176, 48, "#181b24", 17), (236, 66, "#14161c", 22),
             (floor_y + 10, 92, "#101216", 28)]
    for i, (base, th, col, gap) in enumerate(ranks):
        hill = ridge(rnd, w, base, 10, 60, 0.6)
        body += f'<path d="{smooth(hill, h)}" fill="{col}"/>'
        d, x = "", rnd.uniform(-gap, 0)
        while x < w + gap:
            d += pine(x, under(hill, x, base) + 6, th * rnd.uniform(0.7, 1.15))
            x += gap * rnd.uniform(0.7, 1.5)
        body += f'<path d="{d}" fill="{col}"/>'
        if i in (0, 1):
            body += f'<rect x="0" y="{base - 24}" width="{w}" height="54" fill="url(#mist)"/>'
    # the forest floor, the nearest firs at its edges, the camp in the middle
    fl = ridge(rnd, w, floor_y + 34, 12, 80, 0.5)
    body += f'<path d="{smooth(fl, h)}" fill="url(#floor)"/>'
    d = ""
    for x in (-6, 20, 44, w - 40, w - 14, w + 8):
        d += pine(x, h - rnd.uniform(4, 30), rnd.uniform(150, 200))
    body += f'<path d="{d}" fill="#0b0c0e"/>'
    fx, fy = w * 0.52, h - 34
    body += f'<ellipse cx="{fx}" cy="{fy}" rx="190" ry="120" fill="url(#fire)"/>'
    # undergrowth along the floor: ferns and grass, lit near the fire
    for _ in range(46):
        x = rnd.uniform(0, w)
        y = under(fl, x, floor_y + 34) + rnd.uniform(4, 60)
        near = max(0.0, 1 - abs(x - fx) / 180)
        col = "#2a1e12" if near > 0.4 else "#141310"
        ht = rnd.uniform(6, 14)
        body += (f'<path d="M{x - 5:.1f} {y:.1f} Q{x - 4:.1f} {y - ht:.1f} {x - 8:.1f} {y - ht - 3:.1f} M{x:.1f} '
                 f'{y:.1f} L{x + 1:.1f} {y - ht - 4:.1f} M{x + 4:.1f} {y:.1f} Q{x + 6:.1f} {y - ht:.1f} '
                 f'{x + 10:.1f} {y - ht - 2:.1f}" stroke="{col}" stroke-width="1.6" fill="none"/>')
    # the tent, lit inside, its door open to the fire
    tx, ty = w * 0.34, h - 16
    body += (f'<path d="M{tx - 56} {ty} L{tx} {ty - 76} L{tx + 56} {ty} Z" fill="#2a1e14"/>'
             f'<path d="M{tx} {ty - 76} L{tx + 56} {ty} L{tx + 18} {ty} Z" fill="#3a2716"/>'
             f'<path d="M{tx - 12} {ty} L{tx} {ty - 36} L{tx + 12} {ty} Z" fill="#e08a3a" opacity="0.75"/>'
             f'<path d="M{tx} {ty - 76} L{tx} {ty - 88} L{tx + 13} {ty - 84} Z" fill="{GOLD}" opacity="0.7"/>'
             f'<path d="M{tx - 56} {ty} L{tx - 70} {ty + 2} M{tx + 56} {ty} L{tx + 70} {ty + 2}" stroke="#3a2a1a" '
             f'stroke-width="1.2"/>')
    # the fire: stones, logs, flame, sparks rising
    for k in range(8):
        a = k / 8 * math.pi
        body += f'<ellipse cx="{fx + 22 * math.cos(a):.1f}" cy="{fy + 10 + 4 * math.sin(a):.1f}" rx="5" ry="3.5" ' \
                f'fill="#2a241e"/>'
    body += (f'<path d="M{fx - 18} {fy + 8} L{fx + 18} {fy + 2}" stroke="#3a2614" stroke-width="5" '
             f'stroke-linecap="round"/><path d="M{fx - 16} {fy + 2} L{fx + 16} {fy + 9}" stroke="#2c1d10" '
             f'stroke-width="5" stroke-linecap="round"/>'
             f'<path d="M{fx - 10} {fy + 2} Q{fx - 12} {fy - 14} {fx - 3} {fy - 26} Q{fx - 2} {fy - 12} {fx + 3} '
             f'{fy - 20} Q{fx + 12} {fy - 8} {fx + 9} {fy + 2} Z" fill="#ff8a2a"/>'
             f'<path d="M{fx - 5} {fy + 2} Q{fx - 6} {fy - 8} {fx} {fy - 15} Q{fx + 6} {fy - 6} {fx + 4} {fy + 2} Z" '
             f'fill="#ffd27a"/>')
    body += motes(rnd, 14, (fx - 14, fy - 90, fx + 18, fy - 28), "#ffb45a", (0.7, 1.4), (0.4, 0.9))
    # a log to sit on, a pack by the tent, a pot by the fire
    body += (f'<rect x="{fx - 76}" y="{fy + 4}" width="36" height="9" rx="4" fill="#24180e"/>'
             f'<rect x="{tx - 86}" y="{ty - 14}" width="16" height="14" rx="3" fill="#20160e"/>'
             f'<path d="M{fx + 30} {fy + 12} q0 -12 10 -12 q10 0 10 12 Z" fill="#1c1814"/>')
    # fireflies among the firs
    for _ in range(16):
        x, y = rnd.uniform(10, w - 10), rnd.uniform(110, floor_y)
        body += (f'<circle cx="{x:.1f}" cy="{y:.1f}" r="1.6" fill="#e8d27a" opacity="{rnd.uniform(0.3, 0.7):.2f}" '
                 f'filter="url(#b)"/><circle cx="{x:.1f}" cy="{y:.1f}" r="0.7" fill="#fff0b0"/>')
    return render(defs, body, LAND)


# ------------------------------------------------------------------ output
def save(name, art, size, bottom):
    """The art on a texture of its height, at its top or its foot."""
    _, _, w, h, th = size
    tex = Image.new("RGBA", (w, th), (0, 0, 0, 0))
    tex.paste(art, (0, th - h if bottom else 0))
    parts = os.path.join(ROOT, "assets", "professions")
    os.makedirs(parts, exist_ok=True)
    tex.save(os.path.join(parts, f"{name}.png"))
    media = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin", "media", "professions")
    export.to_tga(tex, os.path.join(media, f"{name}.tga"))


def sheet(pillars, sky_art, land_art):
    """render/overview.png: the nine scenes, then the night's two heights."""
    pad, cols = 16, 5
    pw, ph = PILLAR[2], PILLAR[3]
    rows = (len(pillars) + cols - 1) // cols
    tw, tall, short = SKY[2], 620, 440
    W = max(cols * (pw + pad) + pad, 2 * (tw + pad) + pad)
    H = rows * (ph + pad + 20) + pad + tall + 40
    img = Image.new("RGBA", (W, H), (25, 23, 18, 255))
    d = ImageDraw.Draw(img)
    for i, (label, art) in enumerate(pillars):
        x = pad + (i % cols) * (pw + pad)
        y = pad + (i // cols) * (ph + pad + 20)
        img.alpha_composite(art, (x, y))
        d.text((x, y + ph + 4), label, fill=(240, 212, 136))
    y0 = pad + rows * (ph + pad + 20)
    hz = tuple(int(HORIZON[i:i + 2], 16) for i in (1, 3, 5)) + (255,)
    for k, tot in enumerate((tall, short)):
        x = pad + k * (tw + pad)
        if tot > SKY[3] + LAND[3]:
            d.rectangle([x, y0 + SKY[3], x + tw - 1, y0 + tot - LAND[3]], fill=hz)
        img.alpha_composite(sky_art, (x, y0))
        img.alpha_composite(land_art, (x, y0 + tot - LAND[3]))
        d.text((x, y0 + tot + 4), f"the night, {tot}px tall", fill=(240, 212, 136))
    out = os.path.join(HERE, "render")
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "overview.png")
    img.convert("RGB").save(path)
    print(path)


def main():
    pillars = []
    for skill, (label, fn) in PRIMARIES.items():
        rnd = random.Random(skill)
        defs, body = fn(rnd, PILLAR[0], PILLAR[1])
        art = fade(render(defs, body, PILLAR), top=0.5, foot=24)
        save(str(skill), art, PILLAR, True)
        pillars.append((f"{label} ({skill})", art))
    s, l_ = sky(), land()
    save("sky", s, SKY, False)
    save("land", l_, LAND, True)
    old = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin", "media", "professions", "camp.tga")
    if os.path.exists(old):
        os.remove(old)
    sheet(pillars, s, l_)


if __name__ == "__main__":
    main()
