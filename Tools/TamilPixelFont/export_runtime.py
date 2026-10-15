#!/usr/bin/env python3
"""Export the prototype pixels into the app's compact Tamil resource."""

import argparse
import base64
from hashlib import sha256
import json
from pathlib import Path
import shutil


def main():
    """Keep complete Tamil forms and pack two palette indices into each byte."""
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prototype", type=Path, default=root / "Tools/TamilPixelFont/output")
    args = parser.parse_args()
    atlas_path = args.prototype / "atlas.json"
    pixels_path = args.prototype / "pixel-source.json"
    atlas = json.loads(atlas_path.read_text())
    pixels = json.loads(pixels_path.read_text())
    pixel_faces = {face["id"]: {glyph["id"]: glyph for glyph in face["glyphs"]} for face in pixels["faces"]}
    faces = []
    aliases = {}
    for face in atlas["faces"]:
        glyphs = {}
        for glyph in face["glyphs"]:
            if glyph["group"].startswith("ascii-") or glyph["diagnosticOnly"]:
                continue
            if glyph["missingGlyph"] or not glyph["glyphIds"] or 0 in glyph["glyphIds"]:
                raise ValueError(f"A missing source glyph cannot enter the runtime font: {glyph['id']}.")
            sequence = glyph["sequence"]
            rows = pixel_faces[face["id"]][glyph["id"]]["rows"]
            width, height = glyph["spriteWidth"], glyph["spriteHeight"]
            if len(rows) != height or any(len(row) != width for row in rows):
                raise ValueError(f"Pixel dimensions differ for {face['id']}/{glyph['id']}.")
            indices = [15 if value == "." else int(value) for row in rows for value in row]
            if any(value not in (*range(7), 15) for value in indices):
                raise ValueError(f"Unknown palette index in {glyph['id']}.")
            if len(indices) % 2:
                indices.append(15)
            packed = bytes((indices[i] << 4) | indices[i + 1] for i in range(0, len(indices), 2))
            glyphs[sequence] = {"advance": glyph["advance"], "x": glyph["x"], "y": glyph["y"],
                                "width": width, "height": height, "data": base64.b64encode(packed).decode("ascii")}
            for alias in glyph["aliases"]:
                if alias["relationship"] == "unicode-recommended-equivalent":
                    aliases[alias["text"]] = sequence
        faces.append({"id": face["id"], "bodyHeight": face["bodyHeight"], "glyphs": glyphs})
    primary_sets = [set(face["glyphs"]) for face in faces]
    if len(faces) != 3 or any(sequences != primary_sets[0] for sequences in primary_sets):
        raise ValueError("The three prototype faces must cover the same Tamil forms.")
    if len(primary_sets[0]) != 399:
        raise ValueError("Expected 399 complete Tamil forms after excluding isolated combining-sign diagnostics.")
    palette = [int(colour[i:i + 2], 16) for colour in atlas["palettes"]["blue"] for i in (1, 3, 5)]
    result = {"version": 1, "normalisation": "NFC", "packing": "Two 4-bit indices per byte, high nibble first. 15 is transparent.",
              "palette": palette, "aliases": aliases,
              "provenance": {"atlasSHA256": sha256(atlas_path.read_bytes()).hexdigest(),
                             "pixelSourceSHA256": sha256(pixels_path.read_bytes()).hexdigest(),
                             "source": "Noto outlines with generated Lemmings pixel finish. See bundled OFL licences."},
              "faces": faces}
    target = root / "Sources/NxlvKit/Resources/Localization.bundle/Fonts"
    target.mkdir(parents=True, exist_ok=True)
    output = target / "TamilPixelFont.json"
    output.write_text(json.dumps(result, ensure_ascii=False, separators=(",", ":")) + "\n")
    for name in ("OFL.txt", "OFL-Latin.txt", "UNICODE-LICENSE.txt"):
        shutil.copyfile(root / "Tools/TamilPixelFont/vendor" / name, target / name)
    print(f"Exported {len(primary_sets[0])} Tamil forms × {len(faces)} faces, {len(aliases)} alias, {output.stat().st_size} bytes.")


if __name__ == "__main__":
    main()
