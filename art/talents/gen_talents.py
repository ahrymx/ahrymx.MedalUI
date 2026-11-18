#!/usr/bin/env python3
"""The talents window's effects (spells/talents.lua), white, their alpha
soft, tinted and sized by the code:

- sheen.tga (64x64): a diagonal band of light across a maxed talent's icon,
  from its lower left to its upper right, nearer the top-left corner;
- beam.tga (64x16): a lit line's halo, soft across its height and even
  along it (a Line's texture runs along its length, its height across the
  line's thickness);
- glow.tga (128x128): the glow behind a talent, shown two icons wide:
  full round the icon's square (its middle third), then fading softly to
  nothing at the edge, so most of it shows past the icon (the character
  window's glow, faint from its middle out, all but hid under it).

- clouds.tga (256x256): the tree's ground, a soft cloudy wash, white, its
  alpha the clouds (tinted the tree's colour, and faint, by the code);
- vignette.tga (128x128): black, clear in the middle and darkening to the
  edges, over the clouds;
- grid.tga (128x128): the plan mode's drafting grid, white, its alpha the
  lines: a faint one every 32 px, a stronger one along the top and left
  edges, so tiled it has a major line every fourth cell (the code tiles
  it so a cell is an icon wide).

    python3 art/talents/gen_talents.py   -> media/talents/sheen, beam, glow, clouds, vignette, grid (.tga)
"""
import os
import random
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
import export  # noqa: E402

OUT = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin", "media", "talents")


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def sheen(n=64):
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    px = img.load()
    for y in range(n):
        for x in range(n):
            # distance from the band's middle, the diagonal x + y = 0.55 n, in a share of n
            d = abs((x + y) / n - 0.55)
            a = 1 - smooth(d / 0.2)
            px[x, y] = (255, 255, 255, int(round(255 * a)))
    return img


def beam(w=64, h=16):
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    px = img.load()
    for y in range(h):
        t = 1 - abs((y + 0.5) / h * 2 - 1)        # 1 in the middle, 0 at the edges
        a = smooth(t) ** 1.5
        for x in range(w):
            px[x, y] = (255, 255, 255, int(round(255 * a)))
    return img


def glow(n=128, core=0.5, corner=0.25):
    """core: the icon's half size, as a share of the texture's half; corner: its rounding,
    as a share of the core."""
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    px = img.load()
    c = (n - 1) / 2
    r = core * corner
    for y in range(n):
        for x in range(n):
            u, v = abs(x - c) / (n / 2), abs(y - c) / (n / 2)
            # the distance out from a rounded square of half size core
            qx, qy = max(u - (core - r), 0), max(v - (core - r), 0)
            d = max(0.0, (qx * qx + qy * qy) ** 0.5 - r)
            t = d / (1 - core)
            a = (1 - smooth(t)) ** 1.1
            px[x, y] = (255, 255, 255, int(round(255 * a)))
    return img


def clouds(n=256, seed=7):
    """Octaves of random value noise, smoothed up from small grids, summed; then
    pushed apart so there are clouds and clear gaps between them."""
    rnd = random.Random(seed)
    total, weight = None, 0.0
    amp = 1.0
    for cells in (4, 8, 16, 32, 64):
        small = Image.new("L", (cells, cells))
        small.putdata([rnd.randrange(256) for _ in range(cells * cells)])
        layer = small.resize((n, n), Image.BICUBIC)
        if total is None:
            total = [v * amp for v in layer.tobytes()]
        else:
            total = [t + v * amp for t, v in zip(total, layer.tobytes())]
        weight += amp
        amp *= 0.55
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    a = []
    for v in total:
        t = v / weight / 255                    # 0..1, about 0.5
        a.append(int(round(255 * smooth((t - 0.32) / 0.4))))
    img.putalpha(Image.frombytes("L", (n, n), bytes(a)))
    return img


def vignette(n=128):
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()
    c = (n - 1) / 2
    for y in range(n):
        for x in range(n):
            r = (((x - c) / c) ** 2 + ((y - c) / c) ** 2) ** 0.5
            px[x, y] = (0, 0, 0, int(round(255 * smooth((r - 0.35) / 0.95))))
    return img


def grid(n=128, cell=32, faint=0.55):
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    px = img.load()
    for y in range(n):
        for x in range(n):
            a = 0.0
            if x == 0 or y == 0:
                a = 1.0
            elif x % cell == 0 or y % cell == 0:
                a = faint
            px[x, y] = (255, 255, 255, int(round(255 * a)))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, img in (("sheen", sheen()), ("beam", beam()), ("glow", glow()),
                      ("clouds", clouds()), ("vignette", vignette()),
                      ("grid", grid())):
        export.to_tga(img, os.path.join(OUT, name + ".tga"))
        print(os.path.join(OUT, name + ".tga"))


if __name__ == "__main__":
    main()
