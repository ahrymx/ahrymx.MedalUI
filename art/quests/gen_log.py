#!/usr/bin/env python3
"""The quest log's look (quests/log.lua, 2026-11-27, the user's pick D on
the canvas "Quest log: a new look": C's ledger on leather, A's plates, each
zone a glass card).

    python3 art/quests/gen_log.py   -> media/quests/{leather,plate,rail,knob}.tga

leather  256x256, tiling: a dark pebbled hide (cells with dark seams, lit
         from the top), a fine grain and a slow mottle. Opaque.
plate    64x32: a zone's bronze plate, its corners cut (8 px of 32), a
         rim lit along its top. Three slices: 16 | 32 (stretched) | 16.
rail     64x32: the search's pill, sunk: a dark well, its top in shadow,
         a dark rim and a light lip under it. Three slices: 16 | 32 | 16.
knob     32x32: the fold-all's round button: a bronze dome, a gold rim
         (theme.lua tints it as drawn gold), a shadow under it.

Drawn at 4x and reduced, so the curves and cuts are smooth.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
import export  # noqa: E402

OUT = os.path.join(ROOT, "WoW", "Interface", "AddOns", "MedalUI", "media", "quests")
K = 4


def leather(size=256, seed=11):
    rng = np.random.default_rng(seed)

    def blur(a, r):
        return ndimage.gaussian_filter(a, r, mode="wrap")

    def norm(a):
        return (a - a.min()) / (a.max() - a.min())

    pts = rng.random((150, 2)) * size
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    d1 = np.full((size, size), 1e9)
    d2 = np.full((size, size), 1e9)
    for p in pts:
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d = np.hypot(xx - p[0] - ox, yy - p[1] - oy)
                near = d < d1
                d2 = np.where(near, d1, np.minimum(d2, d))
                d1 = np.where(near, d, d1)
    seam = np.clip((d2 - d1) / 4, 0, 1)
    bump = blur(seam, 1.2)
    light = np.roll(bump, 1, 0) - bump
    grain = blur(rng.random((size, size)), 0.6)
    v = bump * 7 + light * 10 + (grain - grain.mean()) * 20 + (norm(blur(rng.random((size, size)), 22)) - 0.5) * 8
    rgb = np.array([20, 16, 13]) + v[..., None] * np.array([1, 0.85, 0.72])
    a = np.full((size, size, 1), 255)
    return Image.fromarray(np.concatenate([rgb.clip(0, 255), a], 2).astype(np.uint8), "RGBA")


def vgrad(h, top, bottom):
    t = np.linspace(0, 1, h)[:, None]
    return np.array(top) * (1 - t) + np.array(bottom) * t


def plate():
    W, H, C = 64 * K, 32 * K, 8 * K

    def cut(inset):
        i, c = inset, C - inset * 0.6
        return [(i + c, i), (W - i - c, i), (W - i, i + c), (W - i, H - i - c), (W - i - c, H - i),
                (i + c, H - i), (i, H - i - c), (i, i + c)]

    def fill(poly, top, bottom):
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).polygon(poly, fill=255)
        g = vgrad(H, top, bottom)[:, None, :].repeat(W, 1)
        return np.asarray(m).astype(float) / 255, g

    outer, go = fill(cut(0), (74, 60, 34), (34, 27, 16))
    inner, gi = fill(cut(1 * K), (58, 47, 27), (35, 28, 17))
    rgb = go * (1 - inner[..., None]) + gi * inner[..., None]
    # the lit line under its top, inside the rim
    lit, _ = fill(cut(1 * K), (0, 0, 0), (0, 0, 0))
    below, _ = fill([(x, y + 1 * K) for x, y in cut(1 * K)], (0, 0, 0), (0, 0, 0))
    line = np.clip(lit - below, 0, 1)
    line[H // 2:] = 0
    rgb = rgb + line[..., None] * np.array([255, 232, 170]) * 0.22
    a = (outer * 255)[..., None]
    img = Image.fromarray(np.concatenate([rgb.clip(0, 255), a], 2).astype(np.uint8), "RGBA")
    return img.resize((64, 32), Image.LANCZOS)


def rail():
    W, H = 64 * K, 32 * K
    r = H / 2 - 1 * K

    def pill(inset):
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).rounded_rectangle((inset, inset, W - 1 - inset, H - 1 - inset), radius=r - inset + 1 * K,
                                            fill=255)
        return np.asarray(m).astype(float) / 255

    lip = pill(0)                       # the light lip, a pixel round it (shows below)
    rim = pill(1 * K)                   # the dark rim
    well = pill(2 * K)                  # the well inside
    g = vgrad(H, (12, 10, 8), (23, 19, 16))[:, None, :].repeat(W, 1)
    # the well's top in shadow: darker down from its top edge
    shade = np.clip(1 - (np.arange(H) - 2 * K) / (5 * K), 0, 1)[:, None] * 0.75
    gw = g * (1 - shade[..., None])
    rgb = np.zeros((H, W, 3))
    a = np.zeros((H, W))
    lipc = np.array([240, 212, 136])
    low = (np.arange(H) > H / 2)[:, None].astype(float)
    rgb += (lip - rim)[..., None] * lipc * low[..., None]
    a += (lip - rim) * 0.14 * low[:, 0][:, None] * 255
    rgb += (rim - well)[..., None] * np.array([58, 47, 30])
    a += (rim - well) * 255
    rgb += well[..., None] * gw
    a += well * 255
    img = Image.fromarray(np.concatenate([rgb.clip(0, 255), a.clip(0, 255)[..., None]], 2).astype(np.uint8), "RGBA")
    return img.resize((64, 32), Image.LANCZOS)


def knob():
    S = 32 * K
    yy, xx = np.mgrid[0:S, 0:S].astype(float) + 0.5
    c = S / 2
    d = np.hypot(xx - c, yy - (c - 1 * K))
    R = 14 * K
    dome = np.clip((R - d) / K, 0, 1)
    rim = np.clip((R - d) / K, 0, 1) - np.clip((R - 1.2 * K - d) / K, 0, 1)
    # the dome: light from the top
    t = np.clip(np.hypot(xx - c, yy - (c - 6 * K)) / (R * 1.3), 0, 1)[..., None]
    body = np.array([58, 47, 28]) * (1 - t) + np.array([21, 17, 11]) * t
    rgb = body * (dome - rim)[..., None] + np.array([150, 120, 63]) * rim[..., None]
    sh = np.clip((R + 2 * K - np.hypot(xx - c, yy - (c + 1 * K))) / (3 * K), 0, 1) * 0.7
    a = np.maximum(dome, sh * (1 - dome))
    rgb = rgb * dome[..., None]
    img = Image.fromarray(np.concatenate([rgb.clip(0, 255), (a * 255)[..., None]], 2).astype(np.uint8), "RGBA")
    return img.resize((32, 32), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, img in (("leather", leather()), ("plate", plate()), ("rail", rail()), ("knob", knob())):
        path = os.path.join(OUT, name + ".tga")
        export.to_tga(img, path)
        print(path)


if __name__ == "__main__":
    main()
