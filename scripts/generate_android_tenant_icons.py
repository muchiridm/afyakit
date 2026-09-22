#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

from PIL import UnidentifiedImageError

try:
    from PIL import Image
except ImportError:
    print(
        "Pillow is required. Install it with:\n"
        "  python3 -m pip install --user Pillow",
        file=sys.stderr,
    )
    raise SystemExit(2)


DENSITIES: dict[str, int] = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

APP_ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate Android launcher icons for one AfyaKit app flavour."
        )
    )

    parser.add_argument(
        "app_id",
        help="Android product flavour, e.g. dawapap, afyatracker or occuwell",
    )

    parser.add_argument(
        "source",
        type=Path,
        help="Square PNG source image, ideally at least 512 × 512",
    )

    return parser.parse_args()


def main() -> int:
    args = parse_args()

    app_id = args.app_id.strip()
    source = args.source.resolve()

    if not APP_ID_PATTERN.fullmatch(app_id):
        print(
            "Invalid app ID. Use a lowercase Android flavour name "
            "containing letters, numbers or underscores, "
            "starting with a letter.",
            file=sys.stderr,
        )
        return 2

    if not source.is_file():
        print(
            f"Source icon not found: {source}",
            file=sys.stderr,
        )
        return 2

    try:
        
        with Image.open(source) as source_image:
            image = source_image.convert("RGBA")
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        print(
            f"Unable to read icon: {exc}",
            file=sys.stderr,
        )
        return 2

    width, height = image.size

    if width != height:
        print(
            f"Source icon must be square; "
            f"received {width} × {height}.",
            file=sys.stderr,
        )
        return 2

    project_root = Path(__file__).resolve().parents[1]

    output_root = (
        project_root
        / "android"
        / "app"
        / "src"
        / app_id
        / "res"
    )

    print(f"🎨 Generating Android icons for app: {app_id}")
    print(f"   Source: {source}")
    print(f"   Output: {output_root}")

    for density, size in DENSITIES.items():
        output_dir = output_root / f"mipmap-{density}"

        output_dir.mkdir(
            parents=True,
            exist_ok=True,
        )

        resized = image.resize(
            (size, size),
            Image.Resampling.LANCZOS,
        )

        launcher_path = output_dir / "ic_launcher.png"
        round_path = output_dir / "ic_launcher_round.png"

        resized.save(
            launcher_path,
            format="PNG",
            optimize=True,
        )

        shutil.copy2(
            launcher_path,
            round_path,
        )

        print(
            f"  {density:8} "
            f"{size:3} × {size:<3} "
            f"→ {launcher_path}"
        )

    print(
        f"✅ Android launcher icons generated successfully: {app_id}"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())