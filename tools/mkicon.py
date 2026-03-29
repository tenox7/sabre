#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import os, subprocess, sys

SIZES = [16, 32, 64, 128, 256, 512, 1024]
OUTDIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Sabre.iconset")

os.makedirs(OUTDIR, exist_ok=True)

def draw_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = size
    cx, cy = s // 2, s // 2
    p = s / 512.0

    # Sky gradient background (circle)
    for r in range(int(s * 0.48), 0, -1):
        t = r / (s * 0.48)
        rb = int(30 + 80 * t)
        gb = int(60 + 120 * t)
        bb = int(120 + 135 * (1 - t))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(rb, gb, bb, 255))

    # Ground strip at bottom of circle
    gy = int(cy + s * 0.25)
    for y in range(gy, int(cy + s * 0.48)):
        t = (y - gy) / max(1, (cy + s * 0.48 - gy))
        gc = int(60 + 40 * t)
        bc = int(80 - 30 * t)
        half = int((s * 0.48)**2 - (y - cy)**2) ** 0.5 if (s * 0.48)**2 > (y - cy)**2 else 0
        d.line([(cx - half, y), (cx + half, y)], fill=(gc - 10, gc, bc, 255))

    # F-86 Sabre jet silhouette
    jx = int(cx - s * 0.05)
    jy = int(cy - s * 0.05)
    sc = p

    # Fuselage
    body = [
        (jx + int(-120 * sc), jy),
        (jx + int(-80 * sc), jy + int(-12 * sc)),
        (jx + int(60 * sc), jy + int(-10 * sc)),
        (jx + int(130 * sc), jy + int(-5 * sc)),
        (jx + int(150 * sc), jy),
        (jx + int(130 * sc), jy + int(5 * sc)),
        (jx + int(60 * sc), jy + int(10 * sc)),
        (jx + int(-80 * sc), jy + int(12 * sc)),
    ]
    d.polygon(body, fill=(180, 185, 190, 255), outline=(80, 80, 90, 255))

    # Swept wings
    wing_top = [
        (jx + int(-10 * sc), jy + int(-10 * sc)),
        (jx + int(40 * sc), jy + int(-8 * sc)),
        (jx + int(-40 * sc), jy + int(-90 * sc)),
        (jx + int(-60 * sc), jy + int(-85 * sc)),
    ]
    d.polygon(wing_top, fill=(160, 165, 175, 255), outline=(80, 80, 90, 255))

    wing_bot = [
        (jx + int(-10 * sc), jy + int(10 * sc)),
        (jx + int(40 * sc), jy + int(8 * sc)),
        (jx + int(-40 * sc), jy + int(90 * sc)),
        (jx + int(-60 * sc), jy + int(85 * sc)),
    ]
    d.polygon(wing_bot, fill=(140, 145, 155, 255), outline=(80, 80, 90, 255))

    # Tail fin (vertical stabilizer)
    tail = [
        (jx + int(-100 * sc), jy + int(-12 * sc)),
        (jx + int(-120 * sc), jy + int(-55 * sc)),
        (jx + int(-90 * sc), jy + int(-50 * sc)),
        (jx + int(-75 * sc), jy + int(-12 * sc)),
    ]
    d.polygon(tail, fill=(170, 175, 185, 255), outline=(80, 80, 90, 255))

    # Horizontal stabilizers
    htail_t = [
        (jx + int(-95 * sc), jy + int(-10 * sc)),
        (jx + int(-75 * sc), jy + int(-8 * sc)),
        (jx + int(-110 * sc), jy + int(-40 * sc)),
        (jx + int(-120 * sc), jy + int(-38 * sc)),
    ]
    d.polygon(htail_t, fill=(155, 160, 170, 255), outline=(80, 80, 90, 255))
    htail_b = [
        (jx + int(-95 * sc), jy + int(10 * sc)),
        (jx + int(-75 * sc), jy + int(8 * sc)),
        (jx + int(-110 * sc), jy + int(40 * sc)),
        (jx + int(-120 * sc), jy + int(38 * sc)),
    ]
    d.polygon(htail_b, fill=(135, 140, 150, 255), outline=(80, 80, 90, 255))

    # Nose intake
    d.ellipse([jx + int(140 * sc), jy + int(-4 * sc),
               jx + int(152 * sc), jy + int(4 * sc)], fill=(50, 50, 60, 255))

    # Canopy
    canopy = [
        (jx + int(50 * sc), jy + int(-9 * sc)),
        (jx + int(80 * sc), jy + int(-16 * sc)),
        (jx + int(100 * sc), jy + int(-12 * sc)),
        (jx + int(90 * sc), jy + int(-8 * sc)),
    ]
    d.polygon(canopy, fill=(140, 200, 230, 200))

    # USAF star on wing (only if big enough)
    if size >= 128:
        star_x = jx + int(-20 * sc)
        star_y = jy + int(-45 * sc)
        sr = int(12 * sc)
        # Simple circle + star approximation
        d.ellipse([star_x - sr, star_y - sr, star_x + sr, star_y + sr],
                  fill=(255, 255, 255, 180))
        inner = int(sr * 0.5)
        d.ellipse([star_x - inner, star_y - inner, star_x + inner, star_y + inner],
                  fill=(30, 50, 120, 200))

    # Exhaust glow
    d.ellipse([jx + int(-125 * sc), jy + int(-6 * sc),
               jx + int(-115 * sc), jy + int(6 * sc)], fill=(255, 200, 100, 150))

    return img

for size in SIZES:
    img = draw_icon(size)
    img.save(os.path.join(OUTDIR, f"icon_{size}x{size}.png"))
    if size <= 512:
        img2 = draw_icon(size * 2)
        img2 = img2.resize((size * 2, size * 2), Image.LANCZOS)
        img2.save(os.path.join(OUTDIR, f"icon_{size}x{size}@2x.png"))

print(f"Generated icons in {OUTDIR}")

icns_path = os.path.join(os.path.dirname(OUTDIR), "Sabre.icns")
subprocess.run(["iconutil", "-c", "icns", OUTDIR, "-o", icns_path], check=True)
print(f"Created {icns_path}")

import shutil
shutil.rmtree(OUTDIR)
