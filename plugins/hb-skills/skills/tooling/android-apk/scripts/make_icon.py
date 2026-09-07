#!/usr/bin/env python3
"""
Generates a complete launcher icon density set.

The default is a rounded-square gradient tile with a monogram — plain, but it
always works and never looks broken. A drawn icon is better when the app
deserves one; this is ordinary Pillow, so extend draw_glyph() rather than
starting over.

Whatever you produce, open the preview and look at it. You can't run the app, so
rendering images and inspecting them is the only visual feedback loop you have —
and it catches things no build log will ever mention.

    python3 make_icon.py --label N --color "#2D5BE3" --out res
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
MASTER = 1024
SS = 4  # supersample, so rounded corners and glyph edges stay clean


def hex_rgb(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def shade(rgb, factor):
    return tuple(max(0, min(255, int(c * factor))) for c in rgb)


def draw_glyph(img, label, size):
    """Centre a monogram on the tile. Replace this for a custom icon."""
    if not label:
        return
    d = ImageDraw.Draw(img)
    font = None
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ):
        if os.path.exists(path):
            font = ImageFont.truetype(path, int(size * 0.46))
            break
    if font is None:
        font = ImageFont.load_default()

    text = label[:2].upper()
    box = d.textbbox((0, 0), text, font=font)
    x = (size - (box[2] - box[0])) / 2 - box[0]
    y = (size - (box[3] - box[1])) / 2 - box[1]

    # Soft drop shadow on its own blurred layer. Drawing the glyph twice with an
    # offset instead gives a hard double-image that reads as a rendering bug.
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((x, y + size * 0.012), text, font=font, fill=(0, 0, 0, 70))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(size * 0.012)))
    d.text((x, y), text, font=font, fill=(255, 255, 255, 255))


def build(label, color, out_dir, preview):
    base = hex_rgb(color)
    top, bottom = shade(base, 1.22), shade(base, 0.72)
    w = MASTER * SS

    gradient = Image.new("RGB", (1, w))
    gd = ImageDraw.Draw(gradient)
    for y in range(w):
        t = y / (w - 1)
        gd.point((0, y), fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    gradient = gradient.resize((w, w))

    mask = Image.new("L", (w, w), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, w - 1], radius=int(w * 0.225), fill=255)

    img = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    img.paste(gradient, (0, 0), mask)
    draw_glyph(img, label, w)
    img = img.resize((MASTER, MASTER), Image.LANCZOS)

    for name, px in DENSITIES.items():
        folder = os.path.join(out_dir, "mipmap-" + name)
        os.makedirs(folder, exist_ok=True)
        img.resize((px, px), Image.LANCZOS).save(os.path.join(folder, "ic_launcher.png"))
        print(f"  mipmap-{name:<8} {px}x{px}")

    os.makedirs(os.path.dirname(preview) or ".", exist_ok=True)
    img.resize((512, 512), Image.LANCZOS).save(preview)
    print(f"\npreview -> {preview}   (open it and check it before shipping)")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--label", default="A", help="monogram, 1-2 characters")
    p.add_argument("--color", default="#2D5BE3", help="base tile colour")
    p.add_argument("--out", default="res", help="res/ directory to write mipmaps into")
    p.add_argument("--preview", default="build/icon_preview.png")
    a = p.parse_args()
    build(a.label, a.color, a.out, a.preview)
