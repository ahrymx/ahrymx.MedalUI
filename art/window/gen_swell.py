#!/usr/bin/env python3
"""A docked window's swell (window/shell.lua; 2026-11-26, the user's idea,
/workspace/swell-mock-2.png): the window's inner edge swelling out round its
head's medallion and back, the step's foot under the medallion running on
round the swell's foot into the edge.

    python3 art/window/gen_swell.py   -> media/window/swell-line.tga, swell-fill.tga (256x256)

Both white on clear, for the window to colour (the line its edge's gold,
the fill its ink). Drawn for a window whose inner edge is its right (the
left strip's); the right strip's mirror them by tex coords.

The box is 64 x 64 points, a texel a quarter point, its top the window's
top and its middle (x = 0) the window's right side: the inner edge is the
point-wide column just inside it (x -1..0). In points, as shell.lua has
them: the medallion MEDAL = 46 across, its middle MEDAL / 4 in from the
side and MEDAL / 2 down; the swell SWELL = MEDAL / 2 + 5 round it, its
lowest point (MEDAL / 2 + SWELL down) the step's foot. The line:
  the step's foot carried on, straight, from below the middle to where it
  meets the edge's ease (one line: 2026-11-26, the user's screenshot
  showed a round foot beside the ease, doubled);
  the edge, from below, eased (FILLET) out into the swell, up round it
  and off the top (the screen's).
The fill is the swell's inside from the edge's column out, under the line
(the window's own ink is inside the column).
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "art", "console"))
import export  # noqa: E402

BOX, K = 64, 4                       # the box in points; texels a point
SIZE = BOX * K
MEDAL = 46.0
CX, CY = -MEDAL / 4, MEDAL / 2       # the medallion's middle
SWELL = MEDAL / 2 + 5                # the swell's radius
FILLET = 9.0                         # the ease from the edge into the swell, along each
EDGE = -0.5                          # the edge's middle (its column, -1..0)
SS = 4                               # oversampling


def at(a, r=SWELL):
    """a point on the swell at angle a (degrees, 0 = outward, 90 = down)"""
    return CX + r * math.cos(math.radians(a)), CY + r * math.sin(math.radians(a))


def bez(p0, p1, p2, n=40):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in (i / n for i in range(n + 1))]


def arc(a0, a1, n=120):
    return [at(a0 + (a1 - a0) * i / n) for i in range(n + 1)]


def shapes():
    # where the swell crosses the edge, below
    cross = math.degrees(math.acos((EDGE - CX) / SWELL))
    cy_cross = CY + SWELL * math.sin(math.radians(cross))
    # the ease: from the edge FILLET below the crossing to the swell FILLET round from it
    ease_end = cross - math.degrees(FILLET / SWELL)
    ease = bez((EDGE, cy_cross + FILLET), (EDGE, cy_cross), at(ease_end))
    bulge = arc(ease_end, -120)                       # up round it and off the top
    # the step's foot (a point-wide line on the step's last row: its middle
    # half a point up) carried on to the ease, where it crosses that row
    fy = CY + SWELL - 0.5
    meet = min(ease, key=lambda p: abs(p[1] - fy))
    foot = [(CX, fy), (meet[0], fy)]
    below = [(EDGE, BOX + 1), (EDGE, cy_cross + FILLET)]
    return foot, below + ease + bulge, cy_cross


def tex(points):
    return [((x + BOX / 2) * K * SS, y * K * SS) for x, y in points]


def render(foot, outline, cy_cross):
    big = SIZE * SS
    line = Image.new("L", (big, big), 0)
    fill = Image.new("L", (big, big), 0)
    dl, df = ImageDraw.Draw(line), ImageDraw.Draw(fill)
    # the fill: from the edge's column (x -1) out to the outline, for the swell's span
    poly = [(-1, BOX + 1)] + [(max(-1, x), y) for x, y in outline[1:]] + [(-1, -8)]
    df.polygon(tex(poly), fill=255)
    # the line, a point wide: the outline, and the foot (inside the window)
    w = K * SS
    dl.line(tex(outline), fill=255, width=w, joint="curve")
    dl.line(tex(foot), fill=255, width=w, joint="curve")
    # the edge's column, below the ease, exactly on it (no blur against the window's own)
    dl.rectangle([((-1) + BOX / 2) * K * SS, (cy_cross + FILLET) * K * SS, (0 + BOX / 2) * K * SS - 1, big], fill=255)
    out = []
    for m in (line, fill):
        a = m.resize((SIZE, SIZE), Image.LANCZOS)
        img = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
        img.putalpha(a)
        out.append(img)
    return out


def main():
    foot, outline, cy_cross = shapes()
    line, fill = render(foot, outline, cy_cross)
    out = os.path.join(ROOT, "WoW", "Interface", "AddOns", "MedalUI", "media", "window")
    os.makedirs(out, exist_ok=True)
    for name, img in (("swell-line", line), ("swell-fill", fill)):
        export.to_tga(img, os.path.join(out, name + ".tga"))
        print(os.path.join(out, name + ".tga"))


if __name__ == "__main__":
    main()
