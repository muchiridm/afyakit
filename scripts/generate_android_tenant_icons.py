#!/usr/bin/env python3

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate Android launcher icons for one AfyaKit tenant."
    )
    parser.add_argument(
        "tenant",
        help="Android product flavour, for example dawapap",
    )
    parser.add_argument(
        "source",
        type=Path,
        help="Square PNG source image, ideally at least 512 × 512",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    tenant = args.tenant.strip()
    source = args.source.resolve()

    if not tenant:
        print("Tenant cannot be empty.", file=sys.stderr)
        return 2

    if not source.is_file():
        print(f"Source icon not found: {source}", file=sys.stderr)
        return 2

    try:
        image = Image.open(source).convert("RGBA")
    except Exception as exc:
        print(f"Unable to read icon: {exc}", file=sys.stderr)
        return 2

    width, height = image.size

    if width != height:
        print(
            f"Source icon must be square; received {width} × {height}.",
            file=sys.stderr,
        )
        return 2

    project_root = Path(__file__).resolve().parents[1]
    output_root = project_root / "android" / "app" / "src" / tenant / "res"

    print(f"Generating Android icons for: {tenant}")
    print(f"Source: {source}")
    print(f"Output: {output_root}")

    for density, size in DENSITIES.items():
        output_dir = output_root / f"mipmap-{density}"
        output_dir.mkdir(parents=True, exist_ok=True)

        resized = image.resize(
            (size, size),
            Image.Resampling.LANCZOS,
        )

        launcher_path = output_dir / "ic_launcher.png"
        round_path = output_dir / "ic_launcher_round.png"

        resized.save(launcher_path, format="PNG", optimize=True)
        shutil.copy2(launcher_path, round_path)

        print(f"  {density:8} {size:3} × {size:<3} → {launcher_path}")

    print("Android tenant icons generated successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())