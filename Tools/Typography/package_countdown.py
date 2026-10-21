#!/usr/bin/env python3
"""Package the hand-drawn 4x countdown numerals exported by the typography checks."""
import argparse
from pathlib import Path
import zipfile


def main():
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=root / ".build/lemmings-typography/countdown4x")
    parser.add_argument("--output", type=Path, default=root / "Artifacts/Typography/LemmingsCountdown4x.zip")
    args = parser.parse_args()
    readme = """Lemmings Countdown 4x

Ten hand-drawn numerals on a 64 x 80 pixel grid.
Each numeral has its own contour, counters, light facet, shade facet and sparkle.
Interior colour clusters come from the original Lemmings large face.

Contents
- blue.png and green.png: transparent atlases for digits 0 through 9.
- metrics.json: atlas rectangles, bearings, advances and baseline.
- preview.png: both colour ramps and the 3, 2, 1 countdown.

Use nearest-neighbour sampling at native size. Bearings and advances are exactly
four times the original large face. The game shares these pixels across Mac,
iOS and TV. GameLemmingsCountdownFace.swift contains the editable drawing data.

Regenerate
TEST_SCOPE=typography zsh Scripts/run-app-integration-tests.sh
python3 Tools/Typography/package_countdown.py
"""
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name in ("blue.png", "green.png", "metrics.json"):
            archive.write(args.source / name, f"LemmingsCountdown4x/{name}")
        archive.write(args.source.parent / "countdown4x-preview.png", "LemmingsCountdown4x/preview.png")
        archive.writestr("LemmingsCountdown4x/README.txt", readme)
    with zipfile.ZipFile(args.output) as archive:
        if archive.testzip() is not None:
            raise SystemExit("Countdown font archive failed its integrity check")
    print(args.output)


if __name__ == "__main__":
    main()
