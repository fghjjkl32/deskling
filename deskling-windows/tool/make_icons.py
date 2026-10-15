"""Draws the paw icon used for the tray and the app. Usage: python3 -I tool/make_icons.py <out.ico>"""
import sys

from PIL import Image, ImageDraw

FILL = (242, 140, 40, 255)
EDGE = (90, 45, 10, 255)


def paw(size):
    scale = 8
    big = size * scale
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    width = max(scale, big // 16)

    def ellipse(cx, cy, rx, ry):
        box = [(cx - rx) * big, (cy - ry) * big, (cx + rx) * big, (cy + ry) * big]
        draw.ellipse(box, fill=FILL, outline=EDGE, width=width)

    ellipse(0.50, 0.66, 0.27, 0.23)
    for cx, cy in [(0.18, 0.40), (0.38, 0.22), (0.62, 0.22), (0.82, 0.40)]:
        ellipse(cx, cy, 0.12, 0.14)
    return image.resize((size, size), Image.LANCZOS)


sizes = [16, 20, 24, 32, 40, 48, 64, 256]
images = [paw(size) for size in sizes]
images[-1].save(sys.argv[1], format="ICO", sizes=[(s, s) for s in sizes], append_images=images[:-1])
