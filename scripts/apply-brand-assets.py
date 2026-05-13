#!/usr/bin/env python3
"""
File Purpose: One-shot pipeline to resize user-supplied Mandaza brand images into
Xcode asset catalog slots (iOS app icon + launch splash, tvOS layered icons + top shelf).

Primary Functions:
- `fit_on_canvas` — letterbox/pillarbox compositing onto a target size with optional background.
- `main` — writes PNGs referenced by this repo's asset catalogs.

Inputs / Outputs:
- Inputs: CLI paths to square icon PNG, iOS portrait `--splash`, optional `--tv-icon` for tvOS icon stacks, optional `--tv-store-backdrop` for tvOS App Store depth layers, and optional wide `--tv-splash` for tvOS top shelf + tv launch (defaults to `--splash` when omitted).
- Outputs: Overwrites PNG files under Mandaza/ and MandazaTV/ Assets.xcassets.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageFilter


def fit_on_canvas(
    img: Image.Image,
    canvas_w: int,
    canvas_h: int,
    *,
    bg: tuple[int, int, int] = (0, 0, 0),
) -> Image.Image:
    """Scale `img` with uniform scale to fit inside canvas; center on solid background."""
    img = img.convert("RGBA")
    iw, ih = img.size
    scale = min(canvas_w / iw, canvas_h / ih)
    nw = max(1, int(round(iw * scale)))
    nh = max(1, int(round(ih * scale)))
    resized = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (*bg, 255))
    ox = (canvas_w - nw) // 2
    oy = (canvas_h - nh) // 2
    canvas.paste(resized, (ox, oy), resized)
    return canvas.convert("RGB")


def square_icon(src: Path, out_size: int = 1024) -> Image.Image:
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    cropped = img.crop((left, top, left + side, top + side))
    return cropped.resize((out_size, out_size), Image.Resampling.LANCZOS).convert("RGB")


def save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--icon", required=True, type=Path, help="Square-ish app icon source PNG (iOS AppIcon)")
    parser.add_argument(
        "--tv-icon",
        type=Path,
        default=None,
        help="Optional wide icon source for tvOS icon stacks only (defaults to --icon)",
    )
    parser.add_argument("--splash", required=True, type=Path, help="Portrait splash for iOS launch (and tv if no --tv-splash)")
    parser.add_argument(
        "--tv-store-backdrop",
        type=Path,
        default=None,
        help="Optional backdrop image for tvOS App Store icon middle/back layers",
    )
    parser.add_argument(
        "--tv-splash",
        type=Path,
        default=None,
        help="Optional wide splash for tvOS top shelf + tv launch only",
    )
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()

    root: Path = args.repo_root
    icon_src = args.icon.expanduser().resolve()
    tv_icon_src = (args.tv_icon.expanduser().resolve() if args.tv_icon else icon_src)
    tv_store_backdrop_src = (args.tv_store_backdrop.expanduser().resolve() if args.tv_store_backdrop else tv_icon_src)
    splash_src = args.splash.expanduser().resolve()
    tv_splash_src = (args.tv_splash.expanduser().resolve() if args.tv_splash else splash_src)
    if (
        not icon_src.is_file()
        or not tv_icon_src.is_file()
        or not tv_store_backdrop_src.is_file()
        or not splash_src.is_file()
        or not tv_splash_src.is_file()
    ):
        print("Icon, tv-icon, tv-store-backdrop, splash, and tv-splash (when set) paths must exist.", file=sys.stderr)
        return 2

    icon_rgb = square_icon(icon_src, 1024)
    tv_icon_img = Image.open(tv_icon_src).convert("RGBA")
    tv_store_backdrop_img = Image.open(tv_store_backdrop_src).convert("RGBA")
    splash_img = Image.open(splash_src).convert("RGBA")
    tv_splash_img = Image.open(tv_splash_src).convert("RGBA")

    # iOS
    ios_icon = root / "Mandaza/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    ios_splash = root / "Mandaza/Assets.xcassets/LaunchSplash.imageset/launch-splash.png"
    save_png(icon_rgb, ios_icon)
    save_png(fit_on_canvas(splash_img, 1290, 2796), ios_splash)

    tv_brand = root / "MandazaTV/Assets.xcassets/AppIcon.brandassets"

    def write_tv_layer(rel: str, w: int, h: int) -> None:
        out = tv_brand / rel
        save_png(fit_on_canvas(tv_icon_img, w, h), out)

    # Primary app icon stack (parallax layers share the same artwork for simplicity).
    write_tv_layer("App Icon.imagestack/Front.imagestacklayer/Content.imageset/front@1x.png", 400, 240)
    write_tv_layer("App Icon.imagestack/Front.imagestacklayer/Content.imageset/front@2x.png", 800, 480)
    write_tv_layer("App Icon.imagestack/Middle.imagestacklayer/Content.imageset/middle@1x.png", 400, 240)
    write_tv_layer("App Icon.imagestack/Middle.imagestacklayer/Content.imageset/middle@2x.png", 800, 480)
    write_tv_layer("App Icon.imagestack/Back.imagestacklayer/Content.imageset/back@1x.png", 400, 240)
    write_tv_layer("App Icon.imagestack/Back.imagestacklayer/Content.imageset/back@2x.png", 800, 480)

    # App Store marketing icon stack (1280×768):
    # - front: icon artwork
    # - middle/back: separate backdrop so icon and backdrop are not duplicates
    write_tv_layer("App Icon - App Store.imagestack/Front.imagestacklayer/Content.imageset/front@1x.png", 1280, 768)
    save_png(
        fit_on_canvas(tv_store_backdrop_img, 1280, 768),
        tv_brand / "App Icon - App Store.imagestack/Middle.imagestacklayer/Content.imageset/middle@1x.png",
    )
    save_png(
        fit_on_canvas(tv_store_backdrop_img, 1280, 768).filter(ImageFilter.GaussianBlur(radius=6)),
        tv_brand / "App Icon - App Store.imagestack/Back.imagestacklayer/Content.imageset/back@1x.png",
    )

    # Top shelf + tv launch: prefer wide tv splash when provided.
    save_png(fit_on_canvas(tv_splash_img, 1920, 720), tv_brand / "Top Shelf Image.imageset/top@1x.png")
    save_png(fit_on_canvas(tv_splash_img, 3840, 1440), tv_brand / "Top Shelf Image.imageset/top@2x.png")
    save_png(fit_on_canvas(tv_splash_img, 2320, 720), tv_brand / "Top Shelf Image Wide.imageset/wide@1x.png")
    save_png(fit_on_canvas(tv_splash_img, 4640, 1440), tv_brand / "Top Shelf Image Wide.imageset/wide@2x.png")

    # tvOS launch splash (full HD frame; UILaunchScreen references this name).
    tv_launch_dir = root / "MandazaTV/Assets.xcassets/LaunchSplash.imageset"
    tv_launch_dir.mkdir(parents=True, exist_ok=True)
    save_png(fit_on_canvas(tv_splash_img, 1920, 1080), tv_launch_dir / "launch-splash-tv.png")
    contents = {
        "images": [{"filename": "launch-splash-tv.png", "idiom": "tv"}],
        "info": {"author": "xcode", "version": 1},
    }
    (tv_launch_dir / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")

    print("Wrote iOS icon + splash, tvOS icon stacks, top shelf, and tv LaunchSplash imageset.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
