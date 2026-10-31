"""Renders Media/GlowCorner.tga: the bottom-left of a white rounded rectangle with a soft edge, on a 64x64
canvas, used to shape the glow on dark panels (Immersion, Storyline). The addon tints it at draw time.

The shape's body starts FEATHER pixels in from the left and bottom edges, with a corner of radius RADIUS, so the
corner circle's centre is at (32, 32) and everything above and right of it is solid. The addon draws:
  - the corner from the bottom-left 32x32 quadrant (mirrored for the bottom-right corner),
  - the bottom edge from a column at x = 48 (straight there), stretched sideways,
  - the side edges from a row at y = 48 (straight there), stretched upwards.
Alpha falls from 1 at the body's edge to 0 over FEATHER pixels, with a smoothstep so the edge has no hard line.
Usage: python make_glow_corner.py <output .tga>"""
import math
import sys
from PIL import Image

OUT = sys.argv[1]
SIZE, FEATHER, RADIUS = 64, 10, 22
CENTRE = FEATHER + RADIUS  # 32


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


canvas = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
px = canvas.load()
for row in range(SIZE):
    for x in range(SIZE):
        # Pixel centre, measured from the bottom-left corner (rows run top to bottom in the image).
        cx, cy = x + 0.5, SIZE - row - 0.5
        dx, dy = max(0.0, CENTRE - cx), max(0.0, CENTRE - cy)
        outside = math.hypot(dx, dy) - RADIUS  # distance outside the body; <= 0 inside
        alpha = 1.0 if outside <= 0 else 1 - smoothstep(outside / FEATHER)
        px[x, row] = (255, 255, 255, round(alpha * 255))
canvas.save(OUT)
print("ok", OUT, "feather", FEATHER, "radius", RADIUS)
