#!/usr/bin/env python3
"""Export the phone app's adaptive launcher layers from the iOS app icon.

The iOS icon draws neon lines inside a rounded neon frame on black. Android
launchers apply their own shape, so the adaptive foreground keeps everything
inside that frame (the frame itself is masked out to black), places it across
64dp of the 72dp visible area, and fills the rest of the 108dp layer with black.
The monochrome layer is the same neon lines, picked out by brightness.
The legacy PNG icons for API 24 and 25 are left as they are.

Requires Pillow and numpy. Run from the repository root:

    python3 android/scripts/export-launcher-icon.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "Mandaza/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
RES = ROOT / "android/app/src/main/res"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

INSET, RADIUS = 96, 180    # inside the neon frame and its glow, master px
CONTENT_DP = 64            # width the framed content takes in the 108dp layer
LAYER = 432                # 108dp at xxxhdpi


def framed_content(master):
    mask = Image.new("L", master.size, 0)
    w = master.size[0]
    ImageDraw.Draw(mask).rounded_rectangle([INSET, INSET, w - 1 - INSET, w - 1 - INSET], radius=RADIUS, fill=255)
    art = Image.composite(master, Image.new("RGB", master.size, (0, 0, 0)), mask.filter(ImageFilter.GaussianBlur(3)))
    inner = art.crop((INSET, INSET, w - INSET, w - INSET))
    side = inner.size[0]
    pad = round(side * (108 - CONTENT_DP) / 2 / CONTENT_DP)
    full = Image.new("RGB", (side + 2 * pad,) * 2, (0, 0, 0))
    full.paste(inner, (pad, pad))
    return full


def main():
    full = framed_content(Image.open(MASTER).convert("RGB"))
    fg = full.resize((LAYER, LAYER), Image.LANCZOS)
    bright = np.asarray(full).astype(float).max(axis=2)
    alpha = Image.fromarray((np.clip((bright - 90) / 70, 0, 1) * 255).astype("uint8"))
    mono = Image.new("RGBA", (LAYER, LAYER), (255, 255, 255, 0))
    mono.putalpha(alpha.resize((LAYER, LAYER), Image.LANCZOS))
    for name, scale in DENSITIES.items():
        folder = RES / f"mipmap-{name}"
        px = round(108 * scale)
        fg.resize((px, px), Image.LANCZOS).save(folder / "ic_launcher_foreground.png", optimize=True)
        mono.resize((px, px), Image.LANCZOS).save(folder / "ic_launcher_monochrome.png", optimize=True)
    print(f"wrote launcher layers to {RES.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
