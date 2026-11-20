#!/usr/bin/env python3
"""The professions' Overview artwork (professions/window.lua), in three
styles the player chooses between (the Overview art option, 2026-11-20,
/workspace/profart-mock-all.png): Engraved (the default), Painted, Poster.

Each scene is built once, as layers back to front (a mask, a colour, a
depth, its texture, a rim light, a hatching angle) with glows among them
and point lights over them, then rendered three ways:

- painted: textured fills hazed by depth, lit by the lights, rim-lit,
  the nearest layer out of focus, a restrained bloom, grain, a vignette;
- engraved: the painted scene's light as gold hatching on ink, each layer
  at its own angle, the brightest cross-hatched, the outlines cut;
- poster: the painted scene's light posterized to six tones of the
  scene's four colours, rim edges, a paper grain.

The scenes:
- one for each primary profession, behind its pillar: its craft at the
  foot, fading out towards the top, where the icon, name and bar stand;
- the night behind the other three sections, rendered whole and cut in
  two so it never stretches: the sky (stars, the milky way, the moon),
  hung from the Secondary professions' heading, and the land (mountains,
  firs in the mist, the camp), standing on Camping's foot. The sky's foot
  and the land's top are both the style's horizon colour, which the code
  fills between them on a tall screen (HORIZON, printed for window.lua).

    python3 art/professions/gen_overview.py
        -> media/professions/<style>/<skillLine>.tga, sky.tga, land.tga,
           assets/professions/<style>/*.png,
           render/overview-<style>.png

Drawn at twice the texture's size and halved:
  a pillar's scene: 219 x 342 units, the bottom 256x400 of a 256x512;
  the sky: 444 x 300 units, the top 512x346 of a 512x512;
  the land: 444 x 348 units, the bottom 512x401 of a 512x512.
"""
import math
import os
import random
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
import export  # noqa: E402

MEDIA = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin", "media", "professions")
ASSETS = os.path.join(ROOT, "assets", "professions")
STYLES = ("engraved", "painted", "poster")
SS = 3                                  # masks drawn this much finer
PILLAR = (219, 342, 256, 400, 512)      # units w, h; texture w, h; the texture's height
SKY = (444, 300, 512, 346, 512)
LAND = (444, 348, 512, 401, 512)
S = 1.0                                 # pixels to a unit while a scene is drawn (set per scene)


# ----------------------------------------------------------------- toolkit
def noise(h, w, scale, seed, octaves=5):
    """Value noise, octaves summed, 0..1."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for _ in range(octaves):
        gh, gw = max(2, int(h / scale) + 2), max(2, int(w / scale) + 2)
        g = rng.random((gh, gw)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += amp * np.asarray(im, np.float32) / 255
        tot += amp
        amp *= 0.5
        scale /= 2
    return out / tot


def mask(h, w, draw):
    """A shape drawn finer and brought down: 0..1."""
    im = Image.new("L", (w * SS, h * SS), 0)
    draw(ImageDraw.Draw(im), SS)
    return np.asarray(im.resize((w, h), Image.LANCZOS), np.float32) / 255


def blur(a, r):
    if r <= 0:
        return a
    if a.ndim == 3:
        return np.stack([blur(a[..., i], r) for i in range(a.shape[2])], -1)
    m = max(float(a.max()), 1e-6)
    im = Image.fromarray(np.clip(a / m * 255, 0, 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255 * m


def hexc(s):
    if not isinstance(s, str):
        return np.asarray(s, np.float32)
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)


def shift(m, dx, dy):
    out = np.zeros_like(m)
    h, w = m.shape
    out[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = \
        m[max(-dy, 0):h + min(-dy, 0), max(-dx, 0):w + min(-dx, 0)]
    return out


def vgrad(h, w, stops):
    y = np.linspace(0, 1, h, dtype=np.float32)
    out = np.zeros((h, 3), np.float32)
    for (a0, c0), (a1, c1) in zip(stops, stops[1:]):
        t = np.clip((y - a0) / (a1 - a0), 0, 1)[:, None]
        sel = ((y >= a0) & (y <= a1))[:, None]
        out = np.where(sel, hexc(c0) * (1 - t) + hexc(c1) * t, out)
    return np.repeat(out[:, None, :], w, 1)


def grid(h, w):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return yy, xx


def P(*pts):
    """units to pixels, as a polygon's points (k: the mask's fineness, applied later)"""
    return [(x * S, y * S) for x, y in pts]


def kk(pts, k):
    return [(x * k, y * k) for x, y in pts]


def leaf(d, k, x, y, ln, wd, ang, curl=0.25):
    """A leaf (or a flame) from (x, y) in pixels, towards ang, its tip curling."""
    left, right = [], []
    for i in range(13):
        t = i / 12
        a = ang + curl * t * t
        cx, cy = x + math.cos(a) * ln * t, y + math.sin(a) * ln * t
        half = wd * math.sin(math.pi * t ** 0.8) * 0.5
        nx, ny = -math.sin(a), math.cos(a)
        left.append(((cx + nx * half) * k, (cy + ny * half) * k))
        right.append(((cx - nx * half) * k, (cy - ny * half) * k))
    d.polygon(left + right[::-1], fill=255)


def pine(d, k, x, base, h, w=None):
    """A fir in pixels: four tiers and a trunk."""
    w = w or h * 0.42
    for i in range(4):
        t0 = base - h * (0.18 + i * 0.2)
        ww = w * (1 - i * 0.22)
        d.polygon([((x - ww / 2) * k, (t0 + h * 0.22) * k), ((x + ww / 2) * k, (t0 + h * 0.22) * k),
                   (x * k, (t0 - h * 0.12) * k)], fill=255)
    d.rectangle([(x - w * 0.05) * k, (base - h * 0.2) * k, (x + w * 0.05) * k, base * k], fill=255)


def gear(d, k, cx, cy, r, teeth, hole=0.35, turn=0.0):
    pts = []
    for i in range(teeth * 4):
        a = turn + i / (teeth * 4) * 2 * math.pi
        rr = r if (i % 4) in (0, 1) else r * 0.8
        pts.append(((cx + math.cos(a) * rr) * k, (cy + math.sin(a) * rr) * k))
    d.polygon(pts, fill=255)
    d.ellipse([(cx - r * hole) * k, (cy - r * hole) * k, (cx + r * hole) * k, (cy + r * hole) * k], fill=0)


def dots(rng, n, box, r):
    x0, y0, x1, y1 = box
    return [(rng.uniform(x0, x1), rng.uniform(y0, y1), r * rng.uniform(0.6, 1.3)) for _ in range(n)]


def spots(h, w, pts):
    return mask(h, w, lambda d, k: [d.ellipse([(x - r) * k, (y - r) * k, (x + r) * k, (y + r) * k], fill=255)
                                    for x, y, r in pts])


def soft_ridge(w, base, amp, seed, scale):
    n = noise(1, w, scale, seed, 5)[0]
    n2 = noise(1, w, scale / 4, seed + 1, 3)[0]
    return [(x, base - amp * (n[x] - 0.5) * 2 - amp * 0.3 * (n2[x] - 0.5)) for x in range(0, w, 2)] + [(w, base)]


# ------------------------------------------------------------- the scene
class Scene:
    """Layers back to front, the glows among them; the lights; the backdrop;
    the haze far layers sink into; the poster's four colours."""

    def __init__(self, w, h, back, haze, palette):
        self.w, self.h = w, h
        self.back, self.haze, self.palette = back, hexc(haze), palette
        self.layers, self.lights = [], []

    def layer(self, m, col, depth, tex=0.25, rim=None, recv=1.0, angle=0.0, dof=0):
        if dof:
            m = blur(m, dof)
        self.layers.append(dict(kind="layer", m=m, col=hexc(col), depth=depth, tex=tex, rim=rim, recv=recv,
                                angle=angle))

    def glow(self, m, col, r, power=1.0):
        self.layers.append(dict(kind="glow", m=m, col=hexc(col), r=r, p=power))

    def light(self, x, y, col, r, power=1.0):
        self.lights.append((x, y, hexc(col), r, power))


def lightmap(sc):
    yy, xx = grid(sc.h, sc.w)
    L = np.zeros((sc.h, sc.w, 3), np.float32)
    for x, y, col, r, p in sc.lights:
        d = np.sqrt((xx - x) ** 2 + (yy - y) ** 2) / r
        L += (p / (1 + 6 * d * d))[..., None] * col
    return L


def rim_edge(m, rim):
    dx, dy = int(round(rim[0] * S / 1.6)), int(round(rim[1] * S / 1.6))
    return np.clip(m - shift(m, dx, dy), 0, 1)


LUM = np.array([0.3, 0.55, 0.15], np.float32)


def paint(sc, seed, flat=False):
    """flat: the textures and the vignette left out (the poster's light)"""
    h, w = sc.h, sc.w
    tx = 0.15 if flat else 1.0
    img = sc.back.copy()
    L = lightmap(sc)
    for i, ly in enumerate(sc.layers):
        m = ly["m"]
        if ly["kind"] == "glow":
            img = img + blur(m, ly["r"])[..., None] * ly["col"] * ly["p"] * 0.7 + m[..., None] * ly["col"] * ly["p"] * 0.35
            continue
        tex = noise(h, w, (10 + 30 * ly["depth"]) * S / 1.6, seed + i, 6)
        tex2 = noise(h, w, 3 * S / 1.6, seed + 50 + i, 2)
        col = ly["col"] * (1 + tx * ly["tex"] * ((tex - 0.5) * 1.6 + (tex2 - 0.5) * 0.5))[..., None]
        col = col * (1 - ly["depth"] * 0.6) + sc.haze * ly["depth"] * 0.6
        col = col * (1 + L * ly["recv"] * 0.9)
        if ly["rim"]:
            edge = blur(rim_edge(m, ly["rim"]), 0.7 * S / 1.6) * (0.4 + 0.6 * np.clip(L.mean(-1) * 2, 0, 1))
            col = col + (edge * ly["rim"][3] * 0.55)[..., None] * hexc(ly["rim"][2])
        img = img * (1 - m[..., None]) + col * m[..., None]
    bright = np.clip(img - 0.7, 0, None)
    img += blur(bright, 5 * S / 1.6) * 0.5 + blur(bright, 16 * S / 1.6) * 0.35
    if flat:
        return np.clip(img, 0, 1)
    img += (noise(h, w, 1.2 * S / 1.6, seed + 99, 1) - 0.5)[..., None] * 0.035
    yy, xx = grid(h, w)
    v = 1 - 0.35 * (((xx / w - 0.5) * 1.6) ** 2 + ((yy / h - 0.55) * 1.2) ** 2)
    img *= np.clip(v, 0.5, 1)[..., None]
    return np.clip(img, 0, 1)


GOLD = hexc("#d9b768")
INK = hexc("#15120d")


def engrave(sc, seed, lit=None):
    h, w = sc.h, sc.w
    lum = (paint(sc, seed) if lit is None else lit) @ LUM
    lum = np.clip((lum - 0.03) / 0.55, 0, 1) ** 1.1
    yy, xx = grid(h, w)
    out = np.zeros((h, w), np.float32)
    per = 4.2 * S / 1.6
    regions = [(None, 0.6)] + [(ly["m"], ly["angle"]) for ly in sc.layers if ly["kind"] == "layer"]
    for k, (m, ang) in enumerate(regions):
        wob = noise(h, w, 40 * S / 1.6, seed + k, 2) * 4 * S / 1.6
        line = 0.5 + 0.5 * np.cos(2 * math.pi * (xx * math.cos(ang) + yy * math.sin(ang) + wob) / per)
        hatch = np.clip((lum * 0.95 - line) * 3, 0, 1)
        line2 = 0.5 + 0.5 * np.cos(2 * math.pi * (xx * math.cos(ang + 1.2) + yy * math.sin(ang + 1.2)) / per)
        hatch = np.maximum(hatch, np.clip((lum - 0.55 - line2 * 0.6) * 4, 0, 1))
        a = np.ones((h, w), np.float32) if m is None else m
        out = out * (1 - a) + hatch * a
        if m is not None:
            o = max(1, int(round(S / 1.6)))
            edge = np.clip(m - shift(m, o, o), 0, 1) + np.clip(m - shift(m, -o, -o), 0, 1)
            out = np.maximum(out, np.clip(edge * 0.9, 0, 1) * (0.35 + 0.65 * np.clip(lum * 1.5, 0, 1)))
    out *= 0.85
    img = INK[None, None] * (1 - out[..., None]) + (GOLD * (0.6 + 0.4 * lum)[..., None]) * out[..., None]
    for ly in sc.layers:
        if ly["kind"] == "glow":
            img += blur(ly["m"], ly["r"])[..., None] * (ly["col"] * 0.4 + GOLD * 0.6) * ly["p"] * 0.3
    img += (noise(h, w, 1.2 * S / 1.6, seed + 99, 1) - 0.5)[..., None] * 0.03
    return np.clip(img, 0, 1)


def poster(sc, seed, lit=None):
    h, w = sc.h, sc.w
    # (its own light, untextured and softened: posterized, a texture's
    # grain would break into blots)
    lum = blur(paint(sc, seed, flat=True) @ LUM, 1.5 * S / 1.6)
    ink, mid, acc, top = [hexc(c) for c in sc.palette]
    q = np.round(np.clip(lum / 0.6, 0, 1) * 5) / 5
    img = np.zeros((h, w, 3), np.float32)
    for (a0, c0), (a1, c1) in zip(((0, ink), (0.35, mid), (0.7, acc)), ((0.35, mid), (0.7, acc), (1.0, top))):
        t = np.clip((q - a0) / (a1 - a0), 0, 1)[..., None]
        sel = ((q >= a0) & (q <= a1))[..., None]
        img = np.where(sel, c0 * (1 - t) + c1 * t, img)
    for ly in sc.layers:
        if ly["kind"] == "layer" and ly["rim"]:
            img += (rim_edge(ly["m"], ly["rim"]) * ly["rim"][3] * 0.5)[..., None] * top
        elif ly["kind"] == "glow":
            img += blur(ly["m"], ly["r"])[..., None] * ly["col"] * ly["p"] * 0.4
    img *= (0.94 + 0.08 * noise(h, w, 2 * S / 1.6, seed + 7, 2))[..., None]
    return np.clip(img, 0, 1)


RENDER = {"painted": paint, "engraved": engrave, "poster": poster}


# ------------------------------------------------------------ the pillars
def pillar_scene(back, haze, palette):
    global S
    S = PILLAR[2] * 2 / PILLAR[0]
    w, h = PILLAR[2] * 2, PILLAR[3] * 2
    return Scene(w, h, vgrad(h, w, back), haze, palette), w, h


def herbalism(rng):
    sc, w, h = pillar_scene([(0, "#0f1612"), (0.45, "#1d3326"), (0.8, "#2c4a35"), (1, "#16231a")],
                            "#22362b", ("#0d1410", "#25402e", "#7fa067", "#e9e3b0"))
    shafts = mask(h, w, lambda d, k: [d.polygon(kk([(w * f, 0), (w * f + 26 * S, 0), (w * f - 70 * S, h),
                                                    (w * f - 110 * S, h)], k), fill=int(255 * a))
                                      for f, a in ((0.55, 0.5), (0.78, 0.35), (0.95, 0.25))])
    sc.glow(blur(shafts, 10 * S) * 0.18, "#d9e8a8", 4 * S, 0.4)

    def far(d, k):
        for _ in range(9):
            x, r = rng.uniform(-20, w + 20), rng.uniform(26, 44) * S
            y = h * 0.52 + rng.uniform(-10, 10) * S
            d.ellipse([(x - r) * k, (y - r) * k, (x + r) * k, (y + r * 2.4) * k], fill=255)
    sc.layer(blur(mask(h, w, far), 2.5 * S), "#1c3524", 0.85, tex=0.3, angle=1.2)
    hill = mask(h, w, lambda d, k: d.polygon(kk([(-5, h * 0.7)] + [(x, h * 0.68 - 22 * S * math.sin(x / w * 2.4 + 0.4))
                                                                     for x in range(0, w + 6, 6)]
                                                 + [(w + 5, h), (-5, h)], k), fill=255))
    sc.layer(hill, "#1d3020", 0.45, tex=0.35, rim=(0, 2, "#c9d98a", 0.35), angle=0.2)

    def stems(d, k, n, top, size):
        for _ in range(n):
            x0, ht, bend = rng.uniform(0, w), rng.uniform(*top) * S, rng.uniform(-18, 18) * S
            pts = [(x0 + bend * (t / 10) ** 2, h + 4 - ht * t / 10) for t in range(11)]
            d.line(kk(pts, k), fill=255, width=max(1, int(1.6 * S * k)))
            for j in range(2, 10, 2):
                x, y = pts[j]
                side = 1 if j % 4 else -1
                leaf(d, k, x, y, size * S * (1.1 - j / 14), size * S * 0.35, -math.pi / 2 + side * 1.0, side * 0.5)

    def clump(d, k, n, y0, size):
        for _ in range(n):
            x, base = rng.uniform(-10, w + 10), h * y0 + rng.uniform(-8, 14) * S
            for _ in range(rng.randint(4, 7)):
                leaf(d, k, x, base, size * S * rng.uniform(0.7, 1.2), size * S * rng.uniform(0.28, 0.4),
                     -math.pi / 2 + rng.uniform(-1.1, 1.1), rng.choice((-1, 1)) * rng.uniform(0.3, 0.8))
    sc.layer(mask(h, w, lambda d, k: clump(d, k, 10, 0.78, 34)), "#4a7a45", 0.3, tex=0.35,
             rim=(-1, 1, "#d7e59a", 0.5), angle=-0.6)
    flowers = [(rng.uniform(25, w - 25), h - rng.uniform(80, 125) * S) for _ in range(5)]
    sc.layer(mask(h, w, lambda d, k: stems(d, k, 7, (70, 120), 14)), "#3b6236", 0.15, tex=0.3,
             rim=(-1, 1, "#e8f0b0", 0.6), angle=0.9)
    pet = mask(h, w, lambda d, k: [[d.ellipse([(x + 5 * S * math.cos(a) - 3.4 * S) * k, (y + 5 * S * math.sin(a) - 3.4 * S) * k,
                                               (x + 5 * S * math.cos(a) + 3.4 * S) * k, (y + 5 * S * math.sin(a) + 3.4 * S) * k],
                                              fill=255) for a in np.linspace(0, 2 * math.pi, 6)[:-1]] for x, y in flowers])
    sc.layer(pet, "#cfcdb4", 0.05, tex=0.1, recv=0.3)
    sc.glow(spots(h, w, [(x, y, 2 * S) for x, y in flowers]), "#f2d36b", 2 * S, 0.6)
    sc.glow(pet * 0.3, "#f0f5d0", 7 * S, 0.3)
    yy, _ = grid(h, w)
    sc.layer(np.clip((yy / h - 0.75) * 4, 0, 1) * 0.75, "#070b08", 0.0, tex=0.1, recv=0.0)
    sc.layer(mask(h, w, lambda d, k: clump(d, k, 5, 1.02, 70)), "#132617", 0.0, tex=0.3,
             rim=(-1, 1, "#c9dc8a", 0.4), angle=1.3, dof=2.2 * S)
    sc.glow(spots(h, w, dots(rng, 26, (0, h * 0.35, w, h * 0.9), 1.2 * S)), "#d8f08a", 3 * S, 0.8)
    sc.light(w * 0.8, h * 0.3, "#d8e8a0", w * 0.9, 0.5)
    return sc


def mining(rng):
    sc, w, h = pillar_scene([(0, "#121010"), (0.5, "#1e1915"), (1, "#141110")],
                            "#2b2622", ("#100d0b", "#3a2a1e", "#b0753a", "#f6d79a"))
    yy, xx = grid(h, w)
    cx = w * 0.42
    tunnel = ((xx - cx) / (w * 0.32)) ** 2 + ((yy - h * 0.72) / (h * 0.36)) ** 2
    rock = np.clip((tunnel - 1 + (noise(h, w, 50 * S, 5, 5) - 0.5) * 0.9) * 6, 0, 1) * np.clip((yy / h - 0.25) * 4, 0, 1)
    sc.layer(rock, "#4a4038", 0.25, tex=0.8, rim=(2, -2, "#ffb46a", 0.4), angle=0.7)
    sc.glow(np.clip(1 - tunnel * 1.4, 0, 1) * np.clip((yy / h - 0.45) * 5, 0, 1) * 0.25, "#5a3a20", 10 * S, 0.6)

    def timber(d, k):
        x0, x1, top = cx - w * 0.27, cx + w * 0.27, h * 0.5
        for x in (x0, x1):
            d.rectangle([(x - 5 * S) * k, top * k, (x + 5 * S) * k, h * k], fill=255)
        d.rectangle([(x0 - 12 * S) * k, (top - 6 * S) * k, (x1 + 12 * S) * k, (top + 5 * S) * k], fill=255)
    sc.layer(mask(h, w, timber), "#4a3322", 0.4, tex=0.5, rim=(2, 0, "#ffb46a", 0.6), angle=-0.4)

    def rails(d, k):
        vx, vy = cx, h * 0.72
        for off in (-1, 1):
            d.line([(vx + off * 6 * S) * k, vy * k, (vx + off * 70 * S) * k, h * k], fill=255, width=int(2.4 * S * k))
        for i in range(8):
            t = (i / 7) ** 1.7
            y, hw = vy + (h - vy) * t, 6 * S + 74 * S * t
            d.rectangle([(vx - hw) * k, y * k, (vx + hw) * k, (y + (1.5 + 5 * t) * S) * k], fill=255)
    sc.layer(mask(h, w, rails), "#2d241c", 0.1, tex=0.4, rim=(0, -1, "#ffcf8a", 0.5), angle=0.0)
    vein = np.clip((noise(h, w, 9 * S, 8, 3) - 0.68) * 8, 0, 1) * rock * ((xx < w * 0.25) | (xx > w * 0.68))
    sc.glow(vein * 0.6, "#ffbf55", 1.5 * S, 0.6)
    shards = []

    def crystals(d, k):
        bx, by = w * 0.8, h * 0.94
        for dx, ht, lean in ((-22, 46, -0.35), (-8, 74, -0.1), (6, 92, 0.05), (20, 60, 0.3), (32, 38, 0.5)):
            x = bx + dx * S
            top = (x + lean * ht * S, by - ht * S)
            wd = 7 * S
            d.polygon(kk([(x - wd, by), (top[0] - 1, top[1] + 10 * S), top, (top[0] + 1, top[1] + 10 * S), (x + wd, by)], k),
                      fill=255)
            shards.append((x, top))
    cm = mask(h, w, crystals)
    sc.layer(cm, "#4d84c4", 0.0, tex=0.15, recv=0.2, rim=(-2, 0, "#d7f0ff", 0.9), angle=1.1)
    half = mask(h, w, lambda d, k: [d.polygon(kk([(x, h * 0.94), t, (x + 7 * S, h * 0.94)], k), fill=255) for x, t in shards])
    sc.glow(half * 0.35, "#9fd0ff", 1, 0.5)
    sc.glow(cm * 0.5, "#5aa8ff", 14 * S, 0.5)

    def pick(d, k):
        x0, y0, x1, y1 = w * 0.12, h * 0.98, w * 0.3, h * 0.66
        d.line([x0 * k, y0 * k, x1 * k, y1 * k], fill=255, width=int(3.2 * S * k))
        d.arc([(x1 - 30 * S) * k, (y1 - 14 * S) * k, (x1 + 26 * S) * k, (y1 + 26 * S) * k], 200, 330,
              fill=255, width=int(4.5 * S * k))
    sc.layer(mask(h, w, pick), "#5a4232", 0.0, tex=0.3, rim=(2, -1, "#ffd08a", 0.8), angle=-0.9)
    lx, ly = cx - w * 0.27 + 12 * S, h * 0.56
    sc.glow(mask(h, w, lambda d, k: d.rounded_rectangle([(lx - 4 * S) * k, (ly - 6 * S) * k, (lx + 4 * S) * k, (ly + 6 * S) * k],
                                                         radius=2 * S * k, fill=255)), "#ffd690", 3 * S, 1.4)
    sc.light(lx, ly, "#ffae55", w * 0.6, 0.9)
    sc.light(w * 0.8, h * 0.85, "#5fa0ff", w * 0.3, 0.5)
    sc.glow(spots(h, w, dots(rng, 30, (0, h * 0.4, w, h), S)), "#ffc66a", 2 * S, 0.6)
    return sc


def alchemy(rng):
    sc, w, h = pillar_scene([(0, "#110f16"), (0.5, "#1c1a26"), (1, "#121016")],
                            "#28243a", ("#0e0c13", "#2c2440", "#5aa878", "#e6f4c8"))
    # the wall's stones, the shelf and its bottles
    yy, xx = grid(h, w)
    stones = np.clip((noise(h, w, 24 * S, 21, 3) - 0.35) * 3, 0, 1) * np.clip((yy / h - 0.3) * 3, 0, 1)
    sc.layer(stones * 0.6, "#2a2636", 0.6, tex=0.5, angle=0.3)
    sy = h * 0.6

    def shelf(d, k):
        d.rectangle([0, sy * k, w * k, (sy + 4 * S) * k], fill=255)
        x = 8 * S
        while x < w - 12 * S:
            bw, bh = rng.uniform(7, 13) * S, rng.uniform(16, 34) * S
            neck = bw * 0.35
            d.rectangle([x * k, (sy - bh) * k, (x + bw) * k, sy * k], fill=255)
            d.rectangle([(x + bw / 2 - neck / 2) * k, (sy - bh - 6 * S) * k, (x + bw / 2 + neck / 2) * k, (sy - bh) * k], fill=255)
            x += bw + rng.uniform(3, 9) * S
    sc.layer(mask(h, w, shelf), "#3a3048", 0.35, tex=0.35, rim=(-1, 1, "#9fe0b0", 0.5), angle=-0.5)
    # the bench
    by = h * 0.88
    sc.layer(mask(h, w, lambda d, k: d.rectangle([0, by * k, w * k, h * k], fill=255)), "#2b2230", 0.1, tex=0.5,
             rim=(0, 2, "#cfe8b8", 0.5), angle=0.0)
    # the flask: a round belly, a neck, its liquid glowing
    fx, fr = w * 0.62, 30 * S
    fy = by - fr

    def flask(d, k):
        d.ellipse([(fx - fr) * k, (fy - fr) * k, (fx + fr) * k, (fy + fr) * k], fill=255)
        d.rectangle([(fx - 6 * S) * k, (fy - fr - 30 * S) * k, (fx + 6 * S) * k, fy * k], fill=255)
    fm = mask(h, w, flask)
    sc.layer(fm, "#283a34", 0.0, tex=0.2, recv=0.6, rim=(-2, 1, "#d8ffe0", 0.9), angle=1.0)
    liquid = fm * (yy > fy - fr * 0.1) * (((xx - fx) ** 2 + (yy - fy) ** 2) < (fr * 0.88) ** 2)
    sc.glow(liquid * 0.6, "#48c078", 2 * S, 0.6)
    sc.glow(liquid * 0.5, "#40c070", 24 * S, 0.7)
    sc.glow(spots(h, w, dots(rng, 9, (fx - fr * 0.6, fy, fx + fr * 0.6, fy + fr * 0.6), 2.2 * S)), "#e8ffd0", 1 * S, 0.7)
    # smoke curling up from the neck
    smoke = mask(h, w, lambda d, k: d.line(kk([(fx + math.sin(t / 7) * 8 * S * (1 + t / 30), fy - fr - 30 * S - t * 2.4 * S)
                                               for t in range(40)], k), fill=255, width=int(3 * S * k)))
    sc.glow(blur(smoke, 2 * S) * 0.5, "#b8c8c0", 4 * S, 0.5)
    # a candle at the left
    cx, cyy = w * 0.18, by
    sc.layer(mask(h, w, lambda d, k: d.rectangle([(cx - 4 * S) * k, (cyy - 26 * S) * k, (cx + 4 * S) * k, cyy * k], fill=255)),
             "#d8ccb0", 0.0, tex=0.15, recv=1.0, angle=0.5)
    flame = mask(h, w, lambda d, k: leaf(d, k, cx, cyy - 26 * S, 11 * S, 5 * S, -math.pi / 2, 0.2))
    sc.glow(flame, "#ffd27a", 2 * S, 1.3)
    sc.light(cx, cyy - 32 * S, "#ffb860", w * 0.4, 0.8)
    sc.light(fx, fy, "#50e080", w * 0.5, 0.9)
    return sc


def blacksmithing(rng):
    sc, w, h = pillar_scene([(0, "#120f0d"), (0.5, "#1f1712"), (1, "#120e0b")],
                            "#2e241c", ("#100c09", "#3c2416", "#c8642a", "#ffe0a0"))
    yy, xx = grid(h, w)
    # the brick wall
    def bricks(d, k):
        bh = 11 * S
        for r in range(int(h / bh) + 1):
            y = h * 0.35 + r * bh
            off = (r % 2) * 12 * S
            for c in range(-1, int(w / (24 * S)) + 2):
                x = c * 24 * S + off
                d.rectangle([(x + S) * k, (y + S) * k, (x + 23 * S) * k, (y + bh - S) * k], fill=255)
    br = mask(h, w, bricks) * np.clip((yy / h - 0.35) * 5, 0, 1)
    sc.layer(br, "#3a261c", 0.5, tex=0.5, rim=(1, -1, "#ff9a50", 0.3), angle=0.0)
    # the forge's mouth, glowing
    fx, fy, fw = w * 0.72, h * 0.72, 34 * S
    mouth = mask(h, w, lambda d, k: (d.ellipse([(fx - fw) * k, (fy - fw) * k, (fx + fw) * k, (fy + fw) * k], fill=255),
                                     d.rectangle([(fx - fw) * k, fy * k, (fx + fw) * k, (fy + 34 * S) * k], fill=255)))
    yy2 = yy
    coals = np.clip(1 - (yy2 - (fy - fw)) / (fw + 34 * S), 0, 1)
    sc.layer(mouth, "#5a1e0c", 0.0, tex=0.5, recv=0.4, angle=0.4)
    sc.layer(mouth * (1 - coals) * 0.9, "#e0782c", 0.0, tex=0.6, recv=0.3, angle=0.4)
    sc.glow(mouth * (1 - coals) * 0.35, "#ffcf70", 4 * S, 0.6)
    sc.glow(mouth * 0.4, "#ff7a2a", 40 * S, 0.7)
    # the floor, the anvil, the hammer on it
    floor = mask(h, w, lambda d, k: d.rectangle([0, h * 0.9 * k, w * k, h * k], fill=255))
    sc.layer(floor, "#1c1410", 0.1, tex=0.4, rim=(0, 2, "#ffb070", 0.4), angle=0.2)
    ax, ay = w * 0.34, h * 0.9

    def anvil(d, k):
        d.polygon(kk([(ax - 44 * S, ay - 40 * S), (ax + 30 * S, ay - 40 * S), (ax + 30 * S, ay - 30 * S),
                      (ax + 12 * S, ay - 24 * S), (ax + 12 * S, ay - 12 * S), (ax + 24 * S, ay),
                      (ax - 30 * S, ay), (ax - 18 * S, ay - 12 * S), (ax - 18 * S, ay - 26 * S),
                      (ax - 30 * S, ay - 30 * S), (ax - 58 * S, ay - 36 * S)], k), fill=255)
        d.line(kk([(ax - 6 * S, ay - 46 * S), (ax + 26 * S, ay - 66 * S)], k), fill=255, width=int(3 * S * k))
        d.polygon(kk([(ax - 14 * S, ay - 50 * S), (ax + 2 * S, ay - 52 * S), (ax - 2 * S, ay - 40 * S), (ax - 14 * S, ay - 41 * S)], k),
                  fill=255)
    sc.layer(mask(h, w, anvil), "#2c2a2a", 0.0, tex=0.35, rim=(2, -1, "#ffb060", 1.0), angle=-0.7)
    # sparks off the anvil
    sp = [(ax + rng.gauss(0, 18) * S, ay - 44 * S - abs(rng.gauss(0, 30)) * S, rng.uniform(0.6, 1.3) * S) for _ in range(40)]
    sc.glow(spots(h, w, sp), "#ffd070", 1.5 * S, 0.9)
    sc.light(fx, fy, "#ff8a3a", w * 0.7, 1.1)
    return sc


def enchanting(rng):
    sc, w, h = pillar_scene([(0, "#0f0c16"), (0.5, "#1e1430"), (1, "#110c18")],
                            "#2a2040", ("#0d0a14", "#2e2050", "#8a6ad0", "#f0e2ff"))
    yy, xx = grid(h, w)
    cx, gy = w * 0.5, h * 0.88
    # the beam rising from the circle
    beam = mask(h, w, lambda d, k: d.polygon(kk([(cx - 26 * S, h * 0.45), (cx + 26 * S, h * 0.45), (cx + 70 * S, gy), (cx - 70 * S, gy)], k),
                                             fill=255)) * np.clip((yy / h - 0.45) * 3, 0, 1)
    sc.glow(blur(beam, 6 * S) * 0.35, "#a080ff", 6 * S, 0.6)
    # the floor and the runic circle on it
    sc.layer(mask(h, w, lambda d, k: d.rectangle([0, (gy - 6 * S) * k, w * k, h * k], fill=255)), "#1a1426", 0.2, tex=0.4,
             rim=(0, 2, "#c0a0ff", 0.3), angle=0.1)

    def circle(d, k):
        for rx, wd in ((88, 2.0), (74, 1.2), (52, 1.0)):
            ry = rx * 0.26
            d.ellipse([(cx - rx * S) * k, (gy - ry * S) * k, (cx + rx * S) * k, (gy + ry * S) * k], outline=255, width=int(wd * S * k))
        for i in range(12):
            a = i / 12 * 2 * math.pi
            x, y = cx + math.cos(a) * 81 * S, gy + math.sin(a) * 81 * 0.26 * S
            d.polygon(kk([(x, y - 3 * S), (x + 2 * S, y), (x, y + 3 * S), (x - 2 * S, y)], k), fill=255)
    ring = mask(h, w, circle)
    sc.glow(ring, "#c8a8ff", 2.5 * S, 1.0)
    # the crystal floating over it
    ky = h * 0.62
    crystal = mask(h, w, lambda d, k: d.polygon(kk([(cx, ky - 30 * S), (cx + 13 * S, ky - 4 * S), (cx, ky + 22 * S), (cx - 13 * S, ky - 4 * S)], k),
                                                fill=255))
    sc.layer(crystal, "#8a68e0", 0.0, tex=0.1, recv=0.3, rim=(-2, 1, "#ffffff", 1.0), angle=0.8)
    facet = mask(h, w, lambda d, k: d.polygon(kk([(cx, ky - 30 * S), (cx + 13 * S, ky - 4 * S), (cx, ky + 22 * S)], k), fill=255))
    sc.glow(facet * 0.3, "#e8dcff", 1, 0.6)
    sc.glow(crystal * 0.6, "#9a70ff", 22 * S, 0.8)
    sc.glow(spots(h, w, dots(rng, 34, (0, h * 0.35, w, gy), 1.1 * S)), "#e0d0ff", 2 * S, 0.8)
    sc.light(cx, ky, "#9a7aff", w * 0.7, 1.0)
    return sc


def engineering(rng):
    sc, w, h = pillar_scene([(0, "#0c1015"), (0.5, "#142030"), (1, "#0d1218")],
                            "#1e2a3a", ("#0a0e13", "#1c3048", "#5c90c0", "#e4f2ff"))
    gy = h * 0.88
    sc.layer(mask(h, w, lambda d, k: [gear(d, k, w * 0.22, h * 0.7, 52 * S, 12, turn=0.2),
                                      gear(d, k, w * 0.86, h * 0.62, 40 * S, 10, turn=0.5)]),
             "#26384c", 0.55, tex=0.45, rim=(-1, 1, "#8ec8ff", 0.4), angle=0.7)
    sc.layer(mask(h, w, lambda d, k: [gear(d, k, w * 0.58, h * 0.76, 34 * S, 9, turn=0.1),
                                      gear(d, k, w * 0.36, h * 0.6, 22 * S, 8, turn=0.3)]),
             "#3a4a5c", 0.25, tex=0.4, rim=(-2, 1, "#c8e4ff", 0.6), angle=-0.4)
    # the bench, and a lamp on it
    sc.layer(mask(h, w, lambda d, k: d.rectangle([0, gy * k, w * k, h * k], fill=255)), "#1e242c", 0.05, tex=0.45,
             rim=(0, 2, "#a8d0ff", 0.5), angle=0.0)
    # a spark jumping between two posts
    p1, p2 = (w * 0.62, gy - 40 * S), (w * 0.86, gy - 46 * S)
    sc.layer(mask(h, w, lambda d, k: [d.rectangle([(x - 2.5 * S) * k, y * k, (x + 2.5 * S) * k, gy * k], fill=255) for x, y in (p1, p2)]),
             "#4a4038", 0.0, tex=0.3, rim=(1, 0, "#ffffff", 0.6), angle=0.9)
    pts = [p1]
    for i in range(1, 9):
        t = i / 9
        pts.append((p1[0] + (p2[0] - p1[0]) * t, p1[1] + (p2[1] - p1[1]) * t + rng.uniform(-9, 9) * S))
    pts.append(p2)
    arc = mask(h, w, lambda d, k: d.line(kk(pts, k), fill=255, width=int(1.6 * S * k)))
    sc.glow(arc, "#d8f0ff", 2 * S, 1.3)
    sc.glow(arc * 0.6, "#5aa8ff", 18 * S, 0.8)
    # a gauge
    gx, gyy = w * 0.2, gy - 14 * S
    sc.layer(mask(h, w, lambda d, k: d.ellipse([(gx - 12 * S) * k, (gyy - 12 * S) * k, (gx + 12 * S) * k, (gyy + 12 * S) * k], fill=255)),
             "#5a4a30", 0.0, tex=0.2, rim=(1, -1, "#ffe0a0", 0.8), angle=0.3)
    sc.glow(mask(h, w, lambda d, k: d.line([gx * k, gyy * k, (gx + 7 * S) * k, (gyy - 6 * S) * k], fill=255, width=int(1.5 * S * k))),
            "#ff8a50", 1 * S, 0.8)
    sc.light((p1[0] + p2[0]) / 2, p1[1], "#7ab8ff", w * 0.6, 1.1)
    return sc


def leatherworking(rng):
    sc, w, h = pillar_scene([(0, "#120e0b"), (0.5, "#221810"), (1, "#130e0a")],
                            "#2e2216", ("#100b08", "#3e2818", "#a8703c", "#f4dcb0"))
    cx, cy = w * 0.5, h * 0.68
    fw, fh = 84 * S, 62 * S

    def frame(d, k):
        for x0, y0, x1, y1 in ((cx - fw, cy - fh, cx + fw, cy - fh + 7 * S), (cx - fw, cy + fh - 7 * S, cx + fw, cy + fh),
                               (cx - fw, cy - fh, cx - fw + 7 * S, h), (cx + fw - 7 * S, cy - fh, cx + fw, h)):
            d.rectangle([x0 * k, y0 * k, x1 * k, y1 * k], fill=255)
    sc.layer(mask(h, w, frame), "#4a3220", 0.3, tex=0.5, rim=(2, -1, "#ffc070", 0.6), angle=-0.3)
    # the hide stretched in it, laced to the frame
    hide_pts = []
    for i in range(24):
        a = i / 24 * 2 * math.pi
        r = 1 + 0.12 * math.sin(a * 3 + 0.5) + 0.06 * math.sin(a * 7)
        hide_pts.append((cx + math.cos(a) * fw * 0.72 * r, cy + math.sin(a) * fh * 0.7 * r))
    hide = mask(h, w, lambda d, k: d.polygon(kk(hide_pts, k), fill=255))
    sc.layer(hide, "#5e3e24", 0.05, tex=0.55, recv=1.0, rim=(1, -1, "#ffd8a0", 0.6), angle=0.9)
    lace = mask(h, w, lambda d, k: [d.line(kk([p, (cx + (p[0] - cx) * 1.32, cy + (p[1] - cy) * 1.36)], k), fill=255, width=int(1 * S * k))
                                    for p in hide_pts[::2]])
    sc.layer(lace, "#d0b080", 0.1, tex=0.1, angle=0.0)
    stitch = mask(h, w, lambda d, k: [d.line(kk([(cx + (p[0] - cx) * 0.82, cy + (p[1] - cy) * 0.82),
                                                  (cx + (q[0] - cx) * 0.82, cy + (q[1] - cy) * 0.82)], k), fill=255, width=int(1 * S * k))
                                      for p, q in zip(hide_pts[::2], hide_pts[1::2])])
    sc.glow(stitch * 0.5, "#ffe0b0", 0.5 * S, 0.5)
    # a lamp at the left
    lx, ly = w * 0.1, h * 0.55
    sc.glow(spots(h, w, [(lx, ly, 6 * S)]), "#ffd080", 4 * S, 1.2)
    sc.light(lx, ly, "#ffa050", w * 0.8, 1.1)
    sc.layer(mask(h, w, lambda d, k: d.rectangle([0, h * 0.94 * k, w * k, h * k], fill=255)), "#1a120c", 0.0, tex=0.4,
             rim=(0, 2, "#ffc080", 0.4), angle=0.2)
    return sc


def skinning(rng):
    sc, w, h = pillar_scene([(0, "#0d1014"), (0.5, "#1a222c"), (1, "#0f1215")],
                            "#28323e", ("#0b0e12", "#222e3a", "#7a8a96", "#f0e4cc"))
    sc.layer(mask(h, w, lambda d, k: [pine(d, k, (i + rng.uniform(-0.3, 0.3)) * w / 9, h * 0.68, rng.uniform(50, 80) * S)
                                      for i in range(10)]), "#1f2a34", 0.7, tex=0.3, rim=(-1, 1, "#9ab0c0", 0.3), angle=1.2)
    sc.layer(mask(h, w, lambda d, k: d.rectangle([0, h * 0.86 * k, w * k, h * k], fill=255)), "#161c20", 0.2, tex=0.4,
             rim=(0, 2, "#b8c8d0", 0.3), angle=0.0)
    # the drying rack: two A-frames, a pole, two hides hung on it
    ry = h * 0.6

    def rack(d, k):
        for x in (w * 0.14, w * 0.86):
            d.line(kk([(x - 16 * S, h * 0.9), (x, ry - 6 * S), (x + 16 * S, h * 0.9)], k), fill=255, width=int(3 * S * k))
        d.line(kk([(w * 0.1, ry), (w * 0.9, ry)], k), fill=255, width=int(3 * S * k))
    sc.layer(mask(h, w, rack), "#3a2c20", 0.1, tex=0.4, rim=(1, -1, "#ffc890", 0.5), angle=-0.6)

    def hides(d, k):
        for x0, x1, drop in ((w * 0.22, w * 0.47, 78), (w * 0.53, w * 0.78, 66)):
            m = (x0 + x1) / 2
            pts = [(x0, ry), (x1, ry), (x1 + 4 * S, ry + drop * 0.45 * S), (x1 - 8 * S, ry + drop * 0.8 * S),
                   (m + 6 * S, ry + drop * S), (m, ry + drop * 0.86 * S), (m - 6 * S, ry + drop * S),
                   (x0 + 8 * S, ry + drop * 0.8 * S), (x0 - 4 * S, ry + drop * 0.45 * S)]
            d.polygon(kk(pts, k), fill=255)
    sc.layer(mask(h, w, hides), "#7a5636", 0.0, tex=0.55, rim=(1, -1, "#ffd8a8", 0.6), angle=0.8)
    # a knife in a stump
    sx, sy = w * 0.2, h * 0.94
    sc.layer(mask(h, w, lambda d, k: d.rectangle([(sx - 12 * S) * k, (sy - 16 * S) * k, (sx + 12 * S) * k, sy * k], fill=255)),
             "#3a2a1c", 0.0, tex=0.4, rim=(1, -1, "#ffc080", 0.5), angle=0.3)
    sc.glow(mask(h, w, lambda d, k: d.polygon(kk([(sx - 1 * S, sy - 16 * S), (sx + 2 * S, sy - 40 * S), (sx + 4 * S, sy - 16 * S)], k),
                                              fill=255)), "#c8d8e8", 1 * S, 0.7)
    sc.light(w * 0.5, h * 0.3, "#9ab4d0", w * 0.9, 0.5)
    sc.light(w * 0.95, h * 0.9, "#ff9a50", w * 0.5, 0.7)
    return sc


def tailoring(rng):
    sc, w, h = pillar_scene([(0, "#120d12"), (0.5, "#24152a"), (1, "#130c13")],
                            "#33223a", ("#100a10", "#3c1e3a", "#b0507a", "#f8e0d0"))
    yy, xx = grid(h, w)
    # the cloth draped in folds
    def cloth(d, k):
        top = [(x, h * 0.74 - 16 * S * math.sin(x / w * 5 + 0.6) - 8 * S * math.sin(x / w * 11)) for x in range(0, w + 4, 4)]
        d.polygon(kk(top + [(w, h), (0, h)], k), fill=255)
    cm = mask(h, w, cloth)
    folds = (0.5 + 0.5 * np.sin(xx / w * 5 * math.pi + yy / h * 3)) * 0.5
    sc.layer(cm, "#56203e", 0.1, tex=0.25, recv=1.0, rim=(0, 2, "#ffc0d8", 0.6), angle=0.5)
    sc.layer(cm * folds * np.clip((yy / h - 0.74) * 6, 0, 1), "#3a1028", 0.0, tex=0.2, angle=0.5)
    # pins in it
    pins = [(rng.uniform(20, w - 20), h - rng.uniform(16, 50) * S) for _ in range(5)]
    sc.glow(spots(h, w, [(x, y, 2 * S) for x, y in pins]), "#ff7a9a", 1 * S, 0.8)
    # the spool
    sx, sy = w * 0.74, h * 0.6
    spool = mask(h, w, lambda d, k: (d.rectangle([(sx - 18 * S) * k, (sy - 30 * S) * k, (sx + 18 * S) * k, (sy + 30 * S) * k], fill=255),))
    sc.layer(spool, "#d8c49a", 0.0, tex=0.15, recv=1.0, rim=(-1, 0, "#ffffff", 0.5), angle=0.0)
    thread = spool * (0.5 + 0.5 * np.sin(yy / (1.6 * S) * math.pi))
    sc.layer(thread * 0.4, "#a08868", 0.0, tex=0.1)
    sc.layer(mask(h, w, lambda d, k: [d.ellipse([(sx - 24 * S) * k, (y - 5 * S) * k, (sx + 24 * S) * k, (y + 5 * S) * k], fill=255)
                                      for y in (sy - 32 * S, sy + 32 * S)]), "#4a3020", 0.0, tex=0.4, rim=(-1, 1, "#ffd0a0", 0.6),
             angle=0.4)
    # the needle, its thread curling to the spool
    n0, n1 = (w * 0.12, h * 0.66), (w * 0.44, h * 0.46)
    sc.glow(mask(h, w, lambda d, k: d.line(kk([n0, n1], k), fill=255, width=int(1.8 * S * k))), "#e8eef8", 1 * S, 1.0)
    curve = [(n1[0] + (sx - 18 * S - n1[0]) * t + math.sin(t * math.pi) * 30 * S, n1[1] - math.sin(t * math.pi * 1.4) * 40 * S
              + (sy - n1[1]) * t) for t in np.linspace(0, 1, 30)]
    sc.glow(mask(h, w, lambda d, k: d.line(kk(curve, k), fill=255, width=int(1 * S * k))), "#f0d8a0", 0.8 * S, 0.7)
    sc.light(w * 0.6, h * 0.4, "#ff9ac0", w * 0.8, 0.7)
    return sc


PRIMARIES = {
    171: ("Alchemy", alchemy), 164: ("Blacksmithing", blacksmithing), 333: ("Enchanting", enchanting),
    202: ("Engineering", engineering), 182: ("Herbalism", herbalism), 165: ("Leatherworking", leatherworking),
    186: ("Mining", mining), 393: ("Skinning", skinning), 197: ("Tailoring", tailoring),
}


# ---------------------------------------------------------------- the night
def night(rng):
    """The whole night, sky over land, 444 x 648 units."""
    global S
    S = SKY[2] * 2 / SKY[0]
    w, h = SKY[2] * 2, int(round((SKY[1] + LAND[1]) * S))
    sc = Scene(w, h, vgrad(h, w, [(0, "#090b14"), (0.3, "#141a30"), (0.5, "#2a2f4c"), (0.58, "#3a3550"), (1, "#0e0f16")]),
               "#2a3048", ("#0b0d16", "#232a44", "#6d6f9a", "#f1d9a0"))
    yy, xx = grid(h, w)
    sky_h = SKY[1] * S                              # the sky's height in pixels
    band = np.exp(-(((yy - (h * 0.02 + xx * 0.36)) / (h * 0.07)) ** 2))
    sc.back = sc.back + (band * noise(h, w, 30 * S, 11, 6) ** 2 * (yy < sky_h * 1.4) * 0.55)[..., None] * hexc("#8f88b8")
    st = [(rng.uniform(0, w), rng.uniform(0, sky_h * 1.3), rng.random() ** 3) for _ in range(420)]
    sc.glow(mask(h, w, lambda d, k: [d.ellipse([(x - (0.4 + 1.3 * b) * S) * k, (y - (0.4 + 1.3 * b) * S) * k,
                                                (x + (0.4 + 1.3 * b) * S) * k, (y + (0.4 + 1.3 * b) * S) * k],
                                               fill=int(120 + 135 * b)) for x, y, b in st]), "#e8e6ff", 1.0 * S, 0.7)
    mx, my = w * 0.72, sky_h * 0.3
    moon = mask(h, w, lambda d, k: d.ellipse([(mx - 13 * S) * k, (my - 13 * S) * k, (mx + 13 * S) * k, (my + 13 * S) * k], fill=255))
    bite = mask(h, w, lambda d, k: d.ellipse([(mx - 7 * S) * k, (my - 17 * S) * k, (mx + 19 * S) * k, (my + 9 * S) * k], fill=255))
    sc.glow(np.clip(moon - bite, 0, 1), "#f3e6c0", 4 * S, 1.2)
    sc.glow(moon * 0.25, "#a8a8d8", 30 * S, 0.8)
    sc.light(mx, my, "#8f9ad8", w * 0.9, 0.35)
    # the land starts at sky_h; its top band (LAND_TOP) is left to the horizon
    land0 = sky_h + LAND_TOP * S
    for i, (base, amp, col, dep) in enumerate([(land0 + 34 * S, 30, "#363c5c", 0.75), (land0 + 58 * S, 20, "#262b45", 0.55)]):
        pts = soft_ridge(w, base, amp * S, 41 + i, 160 * S)
        m = mask(h, w, lambda d, k, pts=pts: d.polygon(kk(pts + [(w, h), (0, h)], k), fill=255))
        snow = np.clip((noise(h, w, 6 * S, 50 + i, 3) - 0.45) * 3, 0, 1) * np.clip(m - shift(m, -6, 10), 0, 1)
        sc.layer(m, col, dep, tex=0.45, rim=(-2, 2, "#c9cdf0", 0.45), angle=0.9 - i * 0.5)
        sc.glow(blur(snow, 1.5) * 0.25, "#aab4e8", 1, 0.4)
    for k_, y in enumerate((land0 + 80 * S, land0 + 150 * S, land0 + 230 * S)):
        mist = np.exp(-(((yy - y) / (14 * S)) ** 2)) * noise(h, w, 50 * S, 60 + k_, 3)
        sc.glow(mist * 0.6, "#5c6080", 4 * S, 0.35)
    for i, (base, size, n, col, dep) in enumerate([(land0 + 96 * S, 26, 70, "#262b40", 0.65),
                                                   (land0 + 170 * S, 40, 46, "#1b1f2e", 0.45),
                                                   (land0 + 262 * S, 62, 26, "#12141e", 0.2)]):
        def firs(d, k, base=base, size=size, n=n):
            for j in range(n):
                pine(d, k, (j + rng.uniform(-0.4, 0.4)) * w / (n - 1), base + rng.uniform(-4, 6) * S, size * S * rng.uniform(0.7, 1.25))
            d.rectangle([0, base * k, w * k, h * k], fill=255)
        sc.layer(mask(h, w, firs), col, dep, tex=0.3, rim=(-2, 2, "#8a92c8", 0.35 - i * 0.08), angle=1.4 - i * 0.6)
    gy = h - 26 * S

    def framing(d, k):
        for x, hh in ((w * 0.03, 230), (w * 0.1, 170), (w * 0.96, 250), (w * 0.88, 180)):
            pine(d, k, x, h + 4, hh * S)
        d.polygon(kk([(0, gy + 2 * S), (w * 0.3, gy), (w * 0.7, gy + S), (w, gy), (w, h), (0, h)], k), fill=255)
    sc.layer(mask(h, w, framing), "#0c0d13", 0.0, tex=0.25, rim=(2, -1, "#ff9a4a", 0.6), angle=-0.5)
    fx, tx = w * 0.56, w * 0.36

    def tent(d, k):
        d.polygon(kk([(tx - 34 * S, gy), (tx, gy - 46 * S), (tx + 34 * S, gy)], k), fill=255)
        d.line(kk([(tx, gy - 46 * S), (tx, gy - 56 * S)], k), fill=255, width=int(1.5 * S * k))
        d.polygon(kk([(tx, gy - 56 * S), (tx + 9 * S, gy - 53 * S), (tx, gy - 50 * S)], k), fill=255)
        d.rectangle(kk([(fx - 34 * S, gy - 4 * S), (fx - 16 * S, gy)], k), fill=255)
    sc.layer(mask(h, w, tent), "#2e2118", 0.0, tex=0.3, recv=0.8, rim=(2, 0, "#ffb060", 0.7), angle=0.4)
    sc.glow(mask(h, w, lambda d, k: d.polygon(kk([(tx - 3 * S, gy), (tx + 2 * S, gy - 30 * S), (tx + 12 * S, gy)], k), fill=255)) * 0.6,
            "#ff9a40", 2 * S, 0.7)
    fire = mask(h, w, lambda d, k: [leaf(d, k, fx + dx, gy, hh * S, 9 * S, -math.pi / 2 + lean, curl)
                                    for dx, hh, lean, curl in ((-4 * S, 15, -0.2, 0.5), (0, 24, 0.0, -0.4), (5 * S, 17, 0.25, -0.6))])
    sc.glow(fire, "#ffb050", 3 * S, 1.6)
    sc.glow(fire * 0.4, "#ff7a2a", 26 * S, 1.2)
    sc.glow(spots(h, w, [(fx + rng.gauss(0, 9) * S, gy - rng.uniform(20, 70) * S, 0.8 * S) for _ in range(22)]), "#ffc070", 1.5 * S, 0.9)
    sc.light(fx, gy - 10 * S, "#ff9040", w * 0.45, 1.1)
    return sc, int(round(sky_h))


LAND_TOP = 40           # units at the land's top left to the horizon (the mountains below it)
SEAM = 40               # units over which the sky's foot and the land's top become the horizon colour


# ------------------------------------------------------------------ output
def half(a):
    """Twice the texture's size down to it."""
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    return im.resize((im.width // 2, im.height // 2), Image.LANCZOS)


def alpha_fade(im, top=None, foot=None):
    """Clear at the top, full from `top` (a fraction of the height) down;
    clear at the foot over its last `foot` pixels."""
    w, h = im.size
    y = np.arange(h, dtype=np.float32)
    a = np.ones(h, np.float32)
    if top:
        t = np.clip(y / (h * top), 0, 1)
        a = t * t * (3 - 2 * t)
    if foot:
        a = np.minimum(a, np.clip((h - y) / foot, 0, 1))
    rgba = im.convert("RGBA")
    arr = np.asarray(rgba).copy()
    arr[..., 3] = (a[:, None] * 255).astype(np.uint8)
    return Image.fromarray(arr)


def save(style, name, art, size, bottom):
    """The art on a texture of its height, at its top or its foot."""
    _, _, w, h, th = size
    tex = Image.new("RGBA", (w, th), (0, 0, 0, 0))
    tex.paste(art, (0, th - h if bottom else 0))
    os.makedirs(os.path.join(ASSETS, style), exist_ok=True)
    tex.save(os.path.join(ASSETS, style, f"{name}.png"))
    os.makedirs(os.path.join(MEDIA, style), exist_ok=True)
    export.to_tga(tex, os.path.join(MEDIA, style, f"{name}.tga"))


def split_night(img, sky_px):
    """The night cut into the sky and the land, both meeting the horizon's
    colour (the mean of the cut's rows) over SEAM units, so the code's fill
    between them, on a tall screen, joins them unseen."""
    seam = int(SEAM * S)
    land_top = int(LAND_TOP * S)
    # (the median: an engraving's lines would lift a mean off its ink)
    hz = np.median(img[sky_px - seam // 2:sky_px + seam // 2].reshape(-1, 3), 0)
    sky = img[:sky_px].copy()
    land = img[sky_px:].copy()
    t = np.clip((np.arange(seam, dtype=np.float32) / seam), 0, 1) ** 1.5
    sky[-seam:] = sky[-seam:] * (1 - t)[:, None, None] + hz * t[:, None, None]
    t2 = np.clip(np.arange(land_top, dtype=np.float32) / land_top, 0, 1) ** 1.5
    land[:land_top] = hz * (1 - t2)[:, None, None] + land[:land_top] * t2[:, None, None]
    return sky, land, hz


def land_alpha(im):
    """The land's top clear, over its first LAND_TOP units (there the
    horizon's colour), so on a short screen it laps over the sky softly."""
    arr = np.asarray(im.convert("RGBA")).copy()
    n = int(LAND_TOP * S / 2)
    t = np.clip(np.arange(n, dtype=np.float32) / n, 0, 1)
    arr[:n, :, 3] = (t * t * (3 - 2 * t) * 255).astype(np.uint8)[:, None]
    return Image.fromarray(arr)


def sheet(style, pillars, sky_im, land_im, hz):
    """render/overview-<style>.png: the nine scenes, then the night tall and short."""
    pad, cols = 16, 5
    pw, ph = PILLAR[2], PILLAR[3]
    rows = (len(pillars) + cols - 1) // cols
    tw, tall, short = SKY[2], 900, 620
    W = max(cols * (pw + pad) + pad, 2 * (tw + pad) + pad)
    H = rows * (ph + pad + 20) + pad + tall + 40
    img = Image.new("RGBA", (W, H), (21, 18, 13, 255))
    d = ImageDraw.Draw(img)
    for i, (label, art) in enumerate(pillars):
        x = pad + (i % cols) * (pw + pad)
        y = pad + (i // cols) * (ph + pad + 20)
        img.alpha_composite(art, (x, y))
        d.text((x, y + ph + 4), label, fill=(240, 212, 136))
    y0 = pad + rows * (ph + pad + 20)
    fill = tuple(int(c * 255) for c in hz) + (255,)
    for k, tot in enumerate((tall, short)):
        x = pad + k * (tw + pad)
        if tot > SKY[3] + LAND[3]:
            d.rectangle([x, y0 + SKY[3], x + tw - 1, y0 + tot - LAND[3]], fill=fill)
        img.alpha_composite(sky_im, (x, y0))
        img.alpha_composite(land_im, (x, y0 + tot - LAND[3]))
        d.text((x, y0 + tot + 4), f"the night, {tot}px tall", fill=(240, 212, 136))
    os.makedirs(os.path.join(HERE, "render"), exist_ok=True)
    path = os.path.join(HERE, "render", f"overview-{style}.png")
    img.convert("RGB").save(path)
    print(path)


def main(styles):
    horizons = {}
    pillars = {s: [] for s in styles}
    for skill, (label, fn) in PRIMARIES.items():
        sc = fn(random.Random(skill))
        lit = paint(sc, skill)
        for style in styles:
            art = lit if style == "painted" else RENDER[style](sc, skill, lit)
            im = alpha_fade(half(art), top=0.5, foot=24)
            save(style, str(skill), im, PILLAR, True)
            pillars[style].append((f"{label} ({skill})", im))
        print(label, flush=True)
    sc, sky_px = night(random.Random(11))
    lit = paint(sc, 11)
    for style in styles:
        art = lit if style == "painted" else RENDER[style](sc, 11, lit)
        sky, land, hz = split_night(art, sky_px)
        sky_im = alpha_fade(half(sky), top=0.08)
        land_im = land_alpha(half(land))
        save(style, "sky", sky_im, SKY, False)
        save(style, "land", land_im, LAND, True)
        horizons[style] = hz
        sheet(style, pillars[style], sky_im, land_im, hz)
    # the flat art these replaced
    for f in os.listdir(MEDIA):
        if f.endswith(".tga"):
            os.remove(os.path.join(MEDIA, f))
    for f in os.listdir(ASSETS):
        if f.endswith(".png"):
            os.remove(os.path.join(ASSETS, f))
    old = os.path.join(HERE, "render", "overview.png")
    if os.path.exists(old):
        os.remove(old)
    for style, hz in horizons.items():
        print(f"HORIZON {style} = {{ {hz[0]:.3f}, {hz[1]:.3f}, {hz[2]:.3f} }}")


if __name__ == "__main__":
    main(sys.argv[1:] or STYLES)
