#!/usr/bin/env python3
"""The companions' marks: MedalUI's medal (assets/medalui-icon.svg, the
minimap button's), its gold turned to each companion's colour, the rest
(the dark face, the letters' blue light) as it is. Each is the companion's
minimap button and its icon in the game's AddOns list.

    python3 art/companions/gen_logos.py   -> mdlui_RadialMenu/art/logo.tga (red),
                                             mdlui_Tooltips/art/logo.tga (blue),
                                             assets/companions/*.png

Rendered at 64 pixels, twice the button's 32, as MedalUI's own is
(art/strips/gen_sidepanel.py); its letters want the Cinzel fonts installed.
A colour is "gold" when its hue is warm (15 to 65 degrees) and it has some
saturation; it keeps its lightness and saturation and takes the new hue.
"""
import colorsys
import os
import re
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
import export  # noqa: E402

SVG = os.path.join(ROOT, "assets", "medalui-icon.svg")
ADDONS = os.path.join(ROOT, "WoW", "Interface", "AddOns")
ASSETS = os.path.join(ROOT, "assets", "companions")

# each companion: its hue (degrees), and how much of the gold's saturation it keeps
MARKS = {
    "mdlui_RadialMenu": (356, 1.0),     # red
    "mdlui_Tooltips": (212, 0.9),       # blue
}


def recolour(svg, hue, keep):
    def one(m):
        hexa = m.group(1)
        r, g, b = (int(hexa[i:i + 2], 16) / 255 for i in (0, 2, 4))
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        if not (15 / 360 <= h <= 65 / 360 and s > 0.25):
            return m.group(0)
        r, g, b = colorsys.hls_to_rgb(hue / 360, l, min(1, s * keep))
        return "#%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))
    return re.sub(r"#([0-9A-Fa-f]{6})\b", one, svg)


def main():
    os.makedirs(ASSETS, exist_ok=True)
    svg = open(SVG, encoding="utf-8").read()
    for addon, (hue, keep) in MARKS.items():
        png = os.path.join(ASSETS, addon + ".png")
        subprocess.run(["rsvg-convert", "-w", "64", "-h", "64", "-o", png],
                       input=recolour(svg, hue, keep).encode(), check=True)
        export.to_tga(Image.open(png).convert("RGBA"), os.path.join(ADDONS, addon, "art", "logo.tga"))
        print(addon, png)


if __name__ == "__main__":
    main()
