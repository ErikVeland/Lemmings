#!/usr/bin/env python3
"""Package the 2x bitmap font atlases exported by the typography render checks."""
import argparse
import json
from pathlib import Path
import zipfile


def main():
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=root / ".build/lemmings-typography/display2x")
    parser.add_argument("--output", type=Path, default=root / "Artifacts/Typography/LemmingsDisplay2x.zip")
    args = parser.parse_args()
    preview = args.source.parent / "display2x-preview.png"
    readme = """Lemmings Display 2x

A dedicated pixel-art display cut made from the extended Lemmings lettering.
Contours follow the original colour clusters. Letter-specific glints and shade facets refine the doubled pixels.

Contents
- large-blue.png and large-green.png: 32 x 40 cells.
- small-blue.png and small-green.png: 24 x 36 cells.
- large-metrics.json and small-metrics.json: ASCII, extended Latin and the skull.
- preview.png: the display cut on a black background.

Using an atlas
Each glyph record gives its atlas rectangle, draw offsets and advance.
Offsets are relative to the original line origin. Keep negative offsets for accents.
Baseline, ascent, descent and a safe line height are supplied in the metadata.
Use nearest-neighbour sampling. The images have transparent backgrounds and retain the original blue/green colour ramps.

The game uses GameLemmingsDisplayFace with the same doubled advances and bearings.
The runtime retains its existing Tamil forms. These Latin atlas exports do not include the Tamil repertoire.

Regenerate
TEST_SCOPE=typography zsh Scripts/run-app-integration-tests.sh
python3 Tools/Typography/package_display.py
"""
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for face in ("small", "large"):
            metadata = json.loads((args.source / f"{face}-metrics.json").read_text())
            glyphs = metadata["glyphs"]
            top = min(0, *(glyph["offsetY"] for glyph in glyphs))
            bottom = max(metadata["cellHeight"], *(glyph["offsetY"] + glyph["height"] for glyph in glyphs))
            baseline = metadata["cellHeight"]
            metadata.update(baseline=baseline, ascent=baseline - top, descent=max(0, bottom - baseline),
                            lineHeight=max(baseline + 12, bottom - top + 4), sampling="nearest")
            archive.writestr(f"LemmingsDisplay2x/{face}-metrics.json",
                             json.dumps(metadata, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
            for ink in ("blue", "green"):
                archive.write(args.source / f"{face}-{ink}.png", f"LemmingsDisplay2x/{face}-{ink}.png")
        archive.write(preview, "LemmingsDisplay2x/preview.png")
        archive.writestr("LemmingsDisplay2x/README.txt", readme)
    with zipfile.ZipFile(args.output) as archive:
        if archive.testzip() is not None:
            raise SystemExit("Font archive failed its integrity check")
    print(args.output)


if __name__ == "__main__":
    main()
