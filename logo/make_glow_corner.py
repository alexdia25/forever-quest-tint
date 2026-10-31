"""Renders the corner art for the glow on dark panels and pages: the bottom-left of a white shape with a soft edge,
on a 64x64 canvas. The addon tints it at draw time.
  rounded   Media/GlowCorner.tga: a rounded rectangle (Immersion, Storyline, ClassicUI Forever's quest log).
  chamfer   Media/GlowChamfer.tga: a rectangle with its corners cut off at 45 degrees (Lorewalker's page).

Both share one layout, so the addon draws them the same way: the shape's body starts FEATHER pixels in from the
left and bottom edges, and everything above and right of (32, 32) is solid. The addon draws
  - the corner from the bottom-left 32x32 quadrant (mirrored for the bottom-right corner),
  - the bottom edge from a column at x = 48 (straight there), stretched sideways,
  - the side edges from a row at y = 48 (straight there), stretched upwards.
Alpha falls from 1 at the body's edge to 0 over FEATHER pixels, with a smoothstep so the edge has no hard line.
Usage: python make_glow_corner.py rounded|chamfer <output .tga>"""
import math
import sys
from PIL import Image

STYLE, OUT = sys.argv[1], sys.argv[2]
SIZE = 64
# rounded: body from 10, corner radius 22 (centre at 32, 32). chamfer: body from 5, cut 22 along each side.
FEATHER = {"rounded": 10, "chamfer": 5}[STYLE]
RADIUS, CUT = 22, 22


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def outside(x, y):
    """Distance outside the body (<= 0 inside), from the bottom-left corner."""
    if STYLE == "rounded":
        centre = FEATHER + RADIUS
        return math.hypot(max(0.0, centre - x), max(0.0, centre - y)) - RADIUS
    # Intersection of three half-planes: right of x = FEATHER, above y = FEATHER, above the 45 degree cut.
    return max(FEATHER - x, FEATHER - y, (2 * FEATHER + CUT - x - y) / math.sqrt(2))


canvas = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
px = canvas.load()
for row in range(SIZE):
    for x in range(SIZE):
        # Pixel centre, measured from the bottom-left corner (rows run top to bottom in the image).
        d = outside(x + 0.5, SIZE - row - 0.5)
        alpha = 1.0 if d <= 0 else 1 - smoothstep(d / FEATHER)
        px[x, row] = (255, 255, 255, round(alpha * 255))
canvas.save(OUT)
print("ok", STYLE, OUT, "feather", FEATHER)
