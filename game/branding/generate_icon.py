#!/usr/bin/env python3
"""Generate SolidExpress app icon PNGs from the brand palette (ui_icons.gd)."""
from __future__ import annotations

from PIL import Image, ImageDraw, ImageFilter
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SIZES = {
    "game/icon.png": 128,
    "game/branding/icon-512.png": 512,
    "docs/branding/logo.png": 512,
}

BG1 = (18, 26, 38)
BG2 = (10, 16, 26)
ACCENT_TOP = (155, 205, 255)
ACCENT_FRONT = (88, 158, 228)
ACCENT_SIDE = (52, 108, 175)
ACCENT_LEFT = (38, 82, 140)
STROKE = (230, 235, 245)
PLANE = (64, 200, 200)


def iso(x: float, y: float, z: float, cx: float, cy: float, s: float) -> tuple[float, float]:
    return (cx + (x - y) * s * 0.8660254, cy - z * s + (x + y) * s * 0.5)


def poly(draw: ImageDraw.ImageDraw, pts, fill, outline=None, width=1) -> None:
    draw.polygon(pts, fill=fill)
    if outline:
        for i in range(len(pts)):
            draw.line([pts[i], pts[(i + 1) % len(pts)]], fill=outline, width=width)


def make_icon(n: int) -> Image.Image:
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    pad = n * 0.08
    r = n * 0.2

    grad = Image.new("RGBA", (n, n))
    gd = ImageDraw.Draw(grad)
    for y in range(n):
        t = y / (n - 1)
        c = tuple(int(BG1[i] * (1 - t) + BG2[i] * t) for i in range(3))
        gd.line([(0, y), (n, y)], fill=c + (255,))
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([pad, pad, n - pad, n - pad], radius=r, fill=255)
    img = Image.composite(grad, img, mask)

    vig = Image.new("L", (n, n), 0)
    vd = ImageDraw.Draw(vig)
    vd.ellipse([n * 0.1, n * 0.05, n * 0.95, n * 0.85], fill=28)
    vig = vig.filter(ImageFilter.GaussianBlur(n * 0.08))
    dark = Image.new("RGBA", (n, n), (0, 0, 0, 255))
    img = Image.composite(img, dark, Image.eval(vig, lambda p: 255 - p))

    draw = ImageDraw.Draw(img)
    lw = max(1, n // 72)
    cx, cy = n * 0.5, n * 0.54
    s = n * 0.108

    pw = 3.6
    plane = [
        iso(-pw, -pw, 0, cx, cy + n * 0.06, s),
        iso(pw, -pw, 0, cx, cy + n * 0.06, s),
        iso(pw, pw, 0, cx, cy + n * 0.06, s),
        iso(-pw, pw, 0, cx, cy + n * 0.06, s),
    ]
    poly(draw, plane, (*PLANE, 22), (*PLANE, 70), max(1, n // 320))

    z0, z1 = 0.0, 2.65
    W, H, T = 2.8, 2.8, 0.95

    def P(x, y, z):
        return iso(x, y, z, cx, cy, s)

    faces = [
        ([P(0, 0, z1), P(W, 0, z1), P(W, T, z1), P(T, T, z1), P(T, H, z1), P(0, H, z1)], ACCENT_TOP),
        ([P(0, 0, z0), P(W, 0, z0), P(W, 0, z1), P(0, 0, z1)], ACCENT_FRONT),
        ([P(W, 0, z0), P(W, T, z0), P(W, T, z1), P(W, 0, z1)], ACCENT_SIDE),
        ([P(T, T, z0), P(W, T, z0), P(W, T, z1), P(T, T, z1)], (70, 130, 200)),
        ([P(0, H, z0), P(T, H, z0), P(T, H, z1), P(0, H, z1)], ACCENT_LEFT),
        ([P(0, 0, z0), P(0, H, z0), P(0, H, z1), P(0, 0, z1)], ACCENT_LEFT),
    ]
    for pts, col in faces:
        poly(draw, pts, col)

    top_loop = [(0, 0), (W, 0), (W, T), (T, T), (T, H), (0, H)]
    for i in range(len(top_loop)):
        a, b = top_loop[i], top_loop[(i + 1) % len(top_loop)]
        draw.line([P(*a, z1), P(*b, z1)], fill=STROKE, width=lw)
    for x, y in [(0, 0), (W, 0), (W, T), (T, T), (T, H), (0, H)]:
        draw.line([P(x, y, z0), P(x, y, z1)], fill=STROKE, width=lw)

    ex = P(T * 0.55, T * 0.55, z1 + 0.02)
    tip = P(T * 0.55, T * 0.55, z1 + 0.75)
    ah = n * 0.028
    draw.line([ex, tip], fill=(255, 255, 255, 210), width=max(1, n // 90))
    draw.polygon(
        [
            (tip[0], tip[1] - ah),
            (tip[0] - ah * 0.55, tip[1] + ah * 0.2),
            (tip[0] + ah * 0.55, tip[1] + ah * 0.2),
        ],
        fill=(255, 255, 255, 220),
    )

    draw.rounded_rectangle(
        [pad + 1, pad + 1, n - pad - 1, n - pad - 1],
        radius=r,
        outline=(ACCENT_TOP[0], ACCENT_TOP[1], ACCENT_TOP[2], 35),
        width=max(1, n // 256),
    )

    return img


def main() -> None:
    for rel, sz in SIZES.items():
        full = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        make_icon(sz).save(full, "PNG", optimize=True)
        print(f"Wrote {full} ({sz}x{sz})")


if __name__ == "__main__":
    main()
