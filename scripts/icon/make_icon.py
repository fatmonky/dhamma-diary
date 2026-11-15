"""Draw the Dhamma Diary app icon: a white stone resting on an open book.

Usage (from the repo root):

    python3 -I scripts/icon/make_icon.py

Writes DhammaDiary/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024x1024).
Needs Pillow. Drawn at 4x and scaled down for smooth edges.
The background is the app's robe brown, #894E26 (see ColorHelpers.accent).
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
OUTPUT = os.path.join(REPO, "DhammaDiary", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")

S = 4  # supersampling
W = 1024 * S

ROBE = (137, 78, 38)        # #894E26
ROBE_DARK = (104, 56, 26)
PAGE = (247, 240, 227)
PAGE_SHADE = (226, 214, 194)
EDGE = (205, 190, 166)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def background():
    img = Image.new("RGB", (W, W))
    px = img.load()
    # Gentle vertical gradient, lighter at the top.
    for y in range(W):
        c = lerp(ROBE, ROBE_DARK, y / W)
        for x in range(W):
            px[x, y] = c
    return img


def page_outline(side, top_y, bottom_y, inner_x, outer_x, lift):
    """One page as a polygon. The top and bottom edges curve: low at the
    gutter, rising toward the outer edge, as an open book's pages do."""
    pts = []
    n = 60
    for i in range(n + 1):
        t = i / n
        x = inner_x + (outer_x - inner_x) * t
        y = top_y - lift * math.sin(t * math.pi / 2) + lift * 0.35 * (1 - t) ** 3
        pts.append((x, y))
    for i in range(n, -1, -1):
        t = i / n
        x = inner_x + (outer_x - inner_x) * t
        y = bottom_y - lift * 0.6 * math.sin(t * math.pi / 2)
        pts.append((x, y))
    return pts


def draw_book(img):
    d = ImageDraw.Draw(img)
    cx = W // 2
    top, bottom = 330 * S, 700 * S
    half = 370 * S
    lift = 34 * S

    # Soft shadow under the book.
    shadow = Image.new("L", (W, W), 0)
    ImageDraw.Draw(shadow).ellipse([cx - half - 10 * S, bottom - 30 * S, cx + half + 10 * S, bottom + 70 * S], fill=120)
    shadow = shadow.filter(ImageFilter.GaussianBlur(30 * S))
    img.paste((60, 30, 12), (0, 0), shadow)

    # Page stack edges below each page.
    for k in range(3, 0, -1):
        off = k * 9 * S
        for side in (-1, 1):
            pts = page_outline(side, top + off, bottom + off, cx, cx + side * (half + k * 4 * S), lift)
            d.polygon(pts, fill=EDGE if k % 2 else PAGE_SHADE)

    # The two open pages.
    for side in (-1, 1):
        d.polygon(page_outline(side, top, bottom, cx, cx + side * half, lift), fill=PAGE)

    # Gutter shading.
    gutter = Image.new("L", (W, W), 0)
    ImageDraw.Draw(gutter).rectangle([cx - 26 * S, top - 10 * S, cx + 26 * S, bottom + 10 * S], fill=90)
    gutter = gutter.filter(ImageFilter.GaussianBlur(18 * S))
    mask = Image.new("L", (W, W), 0)
    for side in (-1, 1):
        ImageDraw.Draw(mask).polygon(page_outline(side, top, bottom, cx, cx + side * half, lift), fill=255)
    gutter = Image.composite(gutter, Image.new("L", (W, W), 0), mask)
    img.paste((150, 120, 90), (0, 0), gutter)
    d.line([(cx, top + 4 * S), (cx, bottom - 4 * S)], fill=(205, 188, 162), width=2 * S)

    # A few faint lines of text on each page.
    for side in (-1, 1):
        for row in range(6):
            y = top + 70 * S + row * 48 * S
            x0 = cx + side * 60 * S
            x1 = cx + side * (half - 50 * S - (90 * S if row == 5 else 0))
            a, b = sorted((x0, x1))
            d.line([(a, y), (b, y)], fill=(229, 219, 202), width=5 * S)


def draw_stone(img):
    cx, cy = W // 2, 505 * S
    rx, ry = 160 * S, 92 * S

    # Shadow on the page.
    sh = Image.new("L", (W, W), 0)
    ImageDraw.Draw(sh).ellipse([cx - rx + 10 * S, cy + ry - 40 * S, cx + rx + 20 * S, cy + ry + 22 * S], fill=160)
    sh = sh.filter(ImageFilter.GaussianBlur(22 * S))
    img.paste((120, 95, 70), (0, 0), sh)

    # Stone body: radial shading from a light at upper left.
    stone = Image.new("RGB", (2 * rx, 2 * ry))
    spx = stone.load()
    lx, ly = -0.35, -0.45
    for y in range(2 * ry):
        for x in range(2 * rx):
            nx, ny = (x - rx) / rx, (y - ry) / ry
            r = nx * nx + ny * ny
            if r > 1:
                continue
            light = max(0.0, 1 - math.hypot(nx - lx, ny - ly) / 1.6)
            v = 0.80 + 0.20 * light
            v -= 0.06 * r ** 3  # darker toward the rim
            c = lerp((196, 188, 176), (255, 255, 253), max(0.0, min(1.0, (v - 0.74) / 0.26)))
            spx[x, y] = c
    mask = Image.new("L", (2 * rx, 2 * ry), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, 2 * rx - 1, 2 * ry - 1], fill=255)
    img.paste(stone, (cx - rx, cy - ry), mask)

    # Highlight.
    hl = Image.new("L", (W, W), 0)
    ImageDraw.Draw(hl).ellipse([cx - 100 * S, cy - 68 * S, cx - 20 * S, cy - 32 * S], fill=160)
    hl = hl.filter(ImageFilter.GaussianBlur(16 * S))
    img.paste((255, 255, 255), (0, 0), hl)


def main():
    img = background()
    draw_book(img)
    draw_stone(img)
    img = img.resize((1024, 1024), Image.LANCZOS)
    img.save(OUTPUT, optimize=True)
    print(f"wrote {os.path.relpath(OUTPUT, REPO)}")


if __name__ == "__main__":
    main()
