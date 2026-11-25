"""Generates the TripMate launcher icons (Android legacy + iOS) from code.

Run from the project root:  python3 tool/make_icons.py   (needs Pillow)
The Android adaptive icon is a vector drawable and needs no PNGs.
"""
import json
import math
import os
from PIL import Image, ImageDraw

TEAL_TOP = (42, 144, 151)
TEAL_BOTTOM = (21, 90, 95)
AMBER = (242, 166, 90)
WHITE = (255, 255, 255)


def render(size, rounded, ss=4):
    S = size * ss
    grad = Image.new("RGB", (S, S))
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        t = y / (S - 1)
        c = tuple(int(TEAL_TOP[i] + (TEAL_BOTTOM[i] - TEAL_TOP[i]) * t) for i in range(3))
        gd.line([(0, y), (S, y)], fill=c)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    mask = Image.new("L", (S, S), 0)
    md = ImageDraw.Draw(mask)
    if rounded:
        pad = int(S * 0.06)
        md.rounded_rectangle([pad, pad, S - pad, S - pad], radius=int(S * 0.2), fill=255)
    else:
        md.rectangle([0, 0, S, S], fill=255)
    img.paste(grad, (0, 0), mask)

    d = ImageDraw.Draw(img)
    cx, cy = S / 2, S * 0.56
    r = S * (0.27 if rounded else 0.30)
    w = int(S * 0.07)
    box = [cx - r, cy - r, cx + r, cy + r]
    # PIL angles: 0 = 3 o'clock, clockwise. Arc from 135° to 405°.
    d.arc(box, 135, 405, fill=WHITE, width=w)
    for a in (135, 405):  # round caps
        x = cx + math.cos(math.radians(a)) * (r - w / 2)
        y = cy + math.sin(math.radians(a)) * (r - w / 2)
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=WHITE)
    a = math.radians(-45)
    nx, ny = cx + math.cos(a) * r * 0.72, cy + math.sin(a) * r * 0.72
    nw = int(S * 0.065)
    d.line([(cx, cy), (nx, ny)], fill=AMBER, width=nw)
    d.ellipse([nx - nw / 2, ny - nw / 2, nx + nw / 2, ny + nw / 2], fill=AMBER)
    hub = S * 0.06
    d.ellipse([cx - hub, cy - hub, cx + hub, cy + hub], fill=WHITE)
    out = img.resize((size, size), Image.LANCZOS)
    if not rounded:
        out = out.convert("RGB")  # App Store icons must not have alpha
    return out


def main():
    android = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for k, px in android.items():
        p = f"android/app/src/main/res/mipmap-{k}/ic_launcher.png"
        render(px, rounded=True).save(p, optimize=True)

    iosdir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.load(open(os.path.join(iosdir, "Contents.json")))
    for im in contents["images"]:
        base = float(im["size"].split("x")[0])
        scale = int(im["scale"].replace("x", ""))
        px = int(round(base * scale))
        render(px, rounded=False).save(os.path.join(iosdir, im["filename"]), optimize=True)
    render(512, rounded=True).save("tool/icon_preview.png", optimize=True)
    print("Icons written.")


if __name__ == "__main__":
    main()
