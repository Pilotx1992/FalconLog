"""Generate Android notification large-icon PNGs from assets/airplane.png.

Deprecated: large icons are no longer used in Android notifications.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "airplane.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

# Near-black background removal (source has solid black canvas).
BLACK_THRESHOLD = 24
PADDING_RATIO = 0.08

DENSITIES: tuple[tuple[str, int], ...] = (
    ("drawable-mdpi", 48),
    ("drawable-hdpi", 72),
    ("drawable-xhdpi", 96),
    ("drawable-xxhdpi", 144),
    ("drawable-xxxhdpi", 192),
)

LEGACY_LARGE_NAMES = ("ic_falconlog_notification_large.png",)


def _remove_near_black_background(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if r <= BLACK_THRESHOLD and g <= BLACK_THRESHOLD and b <= BLACK_THRESHOLD:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def _fit_on_square_canvas(img: Image.Image, padding_ratio: float) -> Image.Image:
    width, height = img.size
    side = max(width, height)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    pad = int(side * padding_ratio)
    inner = max(side - pad * 2, 1)
    scale = min(inner / width, inner / height)
    new_w = max(1, int(width * scale))
    new_h = max(1, int(height * scale))
    resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    offset = ((side - new_w) // 2, (side - new_h) // 2)
    canvas.paste(resized, offset, resized)
    return canvas


def _remove_legacy_large_icons() -> None:
    for folder, _ in DENSITIES:
        target_dir = RES / folder
        if not target_dir.exists():
            continue
        for name in LEGACY_LARGE_NAMES:
            path = target_dir / name
            if path.exists():
                path.unlink()
                print(f"Removed {path}")


def main() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(f"Missing source image: {SOURCE}")

    _remove_legacy_large_icons()

    source = Image.open(SOURCE)
    processed = _fit_on_square_canvas(_remove_near_black_background(source), PADDING_RATIO)

    for folder, size in DENSITIES:
        out_dir = RES / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / "ic_notification_large.png"
        out = processed.resize((size, size), Image.Resampling.LANCZOS)
        out.save(out_path, format="PNG", optimize=True)
        print(f"Wrote {out_path} ({size}x{size})")

    print("Done. Use DrawableResourceAndroidBitmap('ic_notification_large') in Dart.")


if __name__ == "__main__":
    main()
