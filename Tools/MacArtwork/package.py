#!/usr/bin/env python3
"""Package decoded Macintosh artwork as PNGs for an external graphics handoff.

Requires Pillow. Run prepare.py first, then pass its output directory here.
Commercial pixels and generated handoff files stay in ignored .build output.
"""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import shutil
import zipfile

from PIL import Image, ImageDraw


FAMILIES = {
    "lemmings": ("Lemmings 1.5.2", ["orig_dirt", "orig_fire", "orig_marble", "orig_pillar", "orig_crystal"]),
    "ohno": ("Oh No! More Lemmings", ["ohno_brick", "ohno_rock", "ohno_snow", "ohno_bubble"]),
    "xmas": ("Xmas Lemmings 1992", ["ohno_brick", None, "xmas"]),
    "holiday": ("Holiday Lemmings 1994", [None, None, "xmas"]),
}

# Explicit ranges from ClassicMacArtwork.lemming. Other slots contain masks,
# construction pixels and additional source images, not consecutive poses.
POSES = [
    ("walking", "right", 0, 8), ("jumping", "right", 8, 1),
    ("walking", "left", 9, 8), ("jumping", "left", 17, 1),
    ("falling", "right", 18, 4), ("falling", "left", 22, 4),
    ("digging", "shared", 26, 16),
    ("climbing", "right", 43, 8), ("climbing", "left", 51, 8),
    ("post_climb", "right", 59, 8), ("post_climb", "left", 67, 8),
    ("explosion", "shared", 75, 1),
    ("building", "right", 77, 16), ("building", "left", 94, 16),
    ("splatting", "shared", 111, 16), ("blocking", "shared", 127, 16),
    ("bashing", "right", 143, 32), ("bashing", "left", 179, 32),
    ("umbrella_opening", "right", 215, 4), ("floating", "right", 219, 4),
    ("umbrella_opening", "left", 223, 4), ("floating", "left", 227, 4),
    ("mining", "right", 231, 24), ("mining", "left", 257, 24),
    ("drowning", "shared", 283, 16), ("exiting", "shared", 299, 8),
    ("frying", "shared", 307, 14),
    ("shrugging", "right", 321, 8), ("shrugging", "left", 329, 8),
    ("oh_no", "shared", 337, 16),
]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def save_png(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, compress_level=9)
    # Verify every PNG against its decoded source, including transparent RGB.
    with Image.open(path) as decoded:
        if decoded.mode != "RGBA" or decoded.size != image.size or decoded.tobytes() != image.tobytes():
            raise ValueError(f"PNG round-trip changed pixels: {path}")


def make_strip(frames, images, out, relative):
    """Translate frames into equal cells without clipping or changing pixels."""
    x = min(f["x"] for f in frames)
    y = min(f["y"] for f in frames)
    width = max(f["x"] + f["width"] for f in frames) - x
    height = max(f["y"] + f["height"] for f in frames) - y
    strip = Image.new("RGBA", (width, height * len(frames)))
    for index, frame in enumerate(frames):
        image = images[frame["file"]]
        left, top = frame["x"] - x, frame["y"] - y + height * index
        # No alpha mask: paste copies all RGBA bytes, including transparent RGB.
        strip.paste(image, (left, top))
        if strip.crop((left, top, left + image.width, top + image.height)).tobytes() != image.tobytes():
            raise ValueError(f"Strip changed pixels: {relative}")
    save_png(strip, out / relative)
    return dict(file=relative, layout="vertical", frame_width=width,
                frame_height=height, frame_count=len(frames), cell_origin_x=x, cell_origin_y=y)


def make_sheet(entries, images, out, relative, title):
    if not entries:
        return
    width = max(160, max(images[f["file"]].width for _, f in entries)) + 16
    height = max(images[f["file"]].height for _, f in entries) + 34
    columns = min(5, len(entries))
    rows = (len(entries) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * width, 36 + rows * height), (24, 28, 36, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((8, 10), title, fill="white")
    for i, (label, frame) in enumerate(entries):
        x, y = (i % columns) * width, 36 + (i // columns) * height
        draw.text((x + 8, y + 4), label, fill="white")
        # Preview checkerboard only. Actual asset PNGs retain transparency.
        for cy in range(y + 25, y + height, 8):
            for cx in range(x, x + width, 8):
                colour = (48, 54, 65, 255) if ((cx - x) // 8 + (cy - y - 25) // 8) % 2 else (34, 40, 50, 255)
                draw.rectangle((cx, cy, min(cx + 7, x + width - 1), min(cy + 7, y + height - 1)), fill=colour)
        sheet.alpha_composite(images[frame["file"]], (x + 8, y + 27))
    save_png(sheet, out / relative)


def provenance(project, family):
    folder, app = {
        "lemmings": ("original", "Lemmings"),
        "ohno": ("ohno", "Oh No! More Lemmings"),
        "xmas": ("xmas", "Xmas Lemmings"),
        "holiday": ("holiday", "Holiday Lemmings 1994"),
    }[family]
    root = project / ".build/mac-artwork" / folder
    result = []
    for name in ["Graphics.data", "Graphics.rsrc", "Levels.rsrc", app + ".rsrc"]:
        path = root / name
        if not path.is_file():
            raise ValueError(f"Missing source provenance file: {path}")
        data = path.read_bytes()
        result.append(dict(name=name, bytes=len(data), sha256=digest(data)))
    return result


def build(source, out, project):
    out.mkdir(parents=True, exist_ok=False)
    index = dict(format_version=1, pixel_format="RGBA8", coordinate_scale=2,
                 frames=[], object_sequences=[], lemming_sequences=[], families=[], issues=[])
    for family, (release, style_names) in FAMILIES.items():
        manifest_path = source / family / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        shutil.copytree(source / family, out / "decoded" / family)
        images = {}
        family_count = 0
        for bank, bank_frames in sorted(manifest["banks"].items(), key=lambda item: int(item[0])):
            number = int(bank)
            for slot, frame in enumerate(bank_frames):
                if frame is None:
                    continue
                name = frame["file"]
                if Path(name).name != name or ".." in name:
                    raise ValueError(f"Invalid frame filename: {name}")
                data = (source / family / name).read_bytes()
                if len(data) != frame["width"] * frame["height"] * 4:
                    raise ValueError(f"Truncated source frame: {family}/{name}")
                image = Image.frombytes("RGBA", (frame["width"], frame["height"]), data)
                images[name] = image
                category = "terrain" if 1500 <= number < 1600 else "objects" if 1600 <= number < 1700 else "special" if 1700 <= number <= 1703 else "lemmings" if number == 1400 else "interface"
                style_id = number - (1500 if category == "terrain" else 1600)
                style = style_names[style_id] if category in ("terrain", "objects") and 0 <= style_id < len(style_names) else None
                relative = f"png/{family}/{category}/{bank}/{slot:03d}.png"
                save_png(image, out / relative)
                record = dict(family=family, release=release, bank=number,
                              bank_name=manifest["names"].get(bank, ""), frame=slot,
                              category=category, neolemmix_style_hint=style,
                              x=frame["x"], y=frame["y"], width=image.width, height=image.height,
                              file=relative, rgba_file=f"decoded/{family}/{name}", rgba_sha256=digest(data))
                index["frames"].append(record)
                family_count += 1
            if 1500 <= number < 1600:
                entries = [(f"piece {i}", f) for i, f in enumerate(bank_frames) if f]
                make_sheet(entries, images, out, f"previews/{family}-terrain-{style_names[number - 1500] or bank}.png", f"{release}: {style_names[number - 1500] or bank} / original size / source piece IDs")

        for style_id, sequences in sorted(manifest["objects"].items(), key=lambda item: int(item[0])):
            bank = 1600 + int(style_id)
            frames = manifest["banks"].get(str(bank), [])
            style = style_names[int(style_id)] if int(style_id) < len(style_names) else None
            for object_id, sequence in enumerate(sequences):
                if sequence["count"] == 0:
                    continue
                slots = list(range(sequence["base"], sequence["base"] + sequence["count"]))
                missing = [i for i in slots if i >= len(frames) or frames[i] is None]
                record = dict(family=family, bank=bank, style_id=int(style_id),
                              neolemmix_style_hint=style, object_id=object_id,
                              **sequence, frame_slots=slots, missing_slots=missing)
                if not missing:
                    relative = f"animations/{family}/objects/{style or style_id}/{object_id:02d}.png"
                    record["strip"] = make_strip([frames[i] for i in slots], images, out, relative)
                else:
                    index["issues"].append(dict(family=family, bank=bank, object_id=object_id,
                                                reason="Source object sequence has absent frames", missing_slots=missing))
                index["object_sequences"].append(record)
        sprite_frames = manifest["banks"]["1400"]
        sprite_preview = []
        for pose, direction, start, count in POSES:
            slots = list(range(start, start + count))
            frames = [sprite_frames[i] for i in slots]
            if any(f is None for f in frames):
                raise ValueError(f"Missing lemming frame: {family}/{pose}/{direction}")
            relative = f"animations/{family}/lemmings/{pose}_{direction}.png"
            index["lemming_sequences"].append(dict(family=family, pose=pose, direction=direction,
                                                     bank=1400, frame_slots=slots,
                                                     strip=make_strip(frames, images, out, relative)))
            sprite_preview.append((f"{pose} {direction}", frames[0]))
        make_sheet(sprite_preview, images, out, f"previews/{family}-lemmings.png", f"{release}: first frame per pose / original size")
        index["families"].append(dict(id=family, release=release, source_manifest_sha256=digest(manifest_path.read_bytes()),
                                      shpd_version=manifest["version"], frame_count=family_count,
                                      source_files=provenance(project, family)))

    index["summary"] = dict(source_pngs=len(index["frames"]),
                              complete_object_strips=sum("strip" in s for s in index["object_sequences"]),
                              lemming_strips=len(index["lemming_sequences"]),
                              incomplete_object_sequences=len(index["issues"]))
    write_json(out / "index.json", index)
    stream = io.StringIO()
    fields = list(index["frames"][0])
    writer = csv.DictWriter(stream, fields)
    writer.writeheader()
    writer.writerows(index["frames"])
    (out / "frames.csv").write_text(stream.getvalue())
    notices = (project / "THIRD_PARTY_NOTICES.md").read_text()
    notice = notices.split("## resource_dasm format reference\n", 1)[1].split("\n## ", 1)[0]
    (out / "DECODER-NOTICE.txt").write_text("resource_dasm format reference\n" + notice)
    (out / "tools").mkdir(exist_ok=True)
    shutil.copy2(Path(__file__), out / "tools/package.py")
    shutil.copy2(project / "Tools/MacArtwork/prepare.py", out / "tools/prepare.py")
    (out / "README.txt").write_text(readme(index))
    checksums = []
    for path in sorted(out.rglob("*")):
        if path.is_file():
            checksums.append(f"{digest(path.read_bytes())}  {path.relative_to(out).as_posix()}")
    (out / "SHA256SUMS.txt").write_text("\n".join(checksums) + "\n")
    archive = out.with_suffix(".zip")
    with zipfile.ZipFile(archive, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for path in sorted(out.rglob("*")):
            if path.is_file():
                entry = zipfile.ZipInfo((Path(out.name) / path.relative_to(out)).as_posix(), date_time=(2026, 1, 1, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                entry.external_attr = 0o100644 << 16
                z.writestr(entry, path.read_bytes())
    with zipfile.ZipFile(archive) as z:
        if z.testzip():
            raise ValueError("Archive integrity check failed")
        for path in sorted(out.rglob("*")):
            if path.is_file() and z.read((Path(out.name) / path.relative_to(out)).as_posix()) != path.read_bytes():
                raise ValueError(f"Archive content changed: {path}")
    print(json.dumps(dict(archive=str(archive), bytes=archive.stat().st_size,
                         sha256=digest(archive.read_bytes()), **index["summary"]), indent=2))


def readme(index):
    counts = "\n".join(f"  {f['release']}: {f['frame_count']} source PNGs" for f in index["families"])
    return f"""MACINTOSH LEMMINGS GRAPHICS — NEOLEMMIX HANDOFF

This package contains the decoded, original colour Macintosh artwork from
four supplied releases. Pixels are native Macintosh pixels. No interpolation,
AI generation or inferred Macintosh-style sequel artwork is included.

{counts}
Total: {index['summary']['source_pngs']} source PNGs.

CONTENTS

png/          Every nonempty graphics-bank frame, in lossless RGBA PNG format.
              Grouped by release, category, bank ID and original frame slot.
decoded/      Original decoded RGBA files and manifests, including null slots.
animations/   Equal-cell vertical strips for complete object and lemming runs.
previews/     Labelled contact sheets. These have a preview background.
index.json    Full frame, sequence, origin, source hash and coverage records.
frames.csv    Frame index for spreadsheet import or tooling.
tools/        Decoder and packaging scripts for use in a source checkout.
SHA256SUMS.txt  Hashes of every other package file.

COORDINATES AND TRANSPARENCY

Each source PNG keeps the frame's exact cropped dimensions and RGBA bytes.
x and y in index.json are signed authored offsets from the frame canvas origin.
Place a source PNG at (x, y). Do not infer its position from its crop size.
Macintosh coordinates are twice the Classic simulation's pixel coordinates.
PNG alpha preserves transparent pixels and opaque black as distinct values.

Animation strips use the union of all frame bounds as their common cell.
cell_origin_x/y gives that union's top-left in authored coordinates.
Frame i starts at strip y = i * frame_height. Restore its cell at
(cell_origin_x, cell_origin_y). The strips preserve every original frame,
but their union-sized cells are not guaranteed to match NeoLemmix canvases.

STYLE AND SEQUENCE MAPPING

Lemmings banks 1500–1504: Dirt, Fire, Marble, Pillar, Crystal.
Oh No! banks 1500–1503: Brick, Rock, Snow, Bubble.
Xmas '92: brick bank 1500, festive snow bank 1502.
Holiday '94: festive snow bank 1502.
Object banks are 1600 + the corresponding style ID.
Terrain frame slots correspond to Classic piece IDs.
Object sequences specify object_id, base bank slot, count and first frame.
Keep first as the authored initial/rest frame within the sequence.
Do not treat an entire object or lemming bank as one animation.
The lemming pose ranges follow ClassicMacArtwork.swift. Direction 'shared'
means the current Classic pose map uses one sequence for both directions.
Extra slots, masks and construction pixels remain available in png/ and decoded/.
Bank names are source resource names. NeoLemmix style names are mapping hints.

NEOLEMMIX INTEGRATION

This is a source-art package for the team to integrate, not an installable style.
NeoLemmix's published format uses PNGs in terrain-hr, objects-hr and lemmings-hr,
with matching low-resolution graphics and shared metadata. HR dimensions must
be exactly twice the corresponding low-resolution dimensions.
Recanvas the cropped originals using the preserved offsets before adoption.
Validate terrain silhouettes against the existing low-resolution collision map.
Mac silhouettes can extend into transparent DOS cells or leave solid cells empty.
Keep the existing physics, trigger rectangles, steel and one-way metadata.
Some NeoLemmix exits combine separate Classic exit and flame graphics.
Frame counts, actor anchors and animation phases can differ between engines.
The Mac artwork does not supply NeoLemmix-only skills or trait recolourings.
Object animation timing and trigger metadata are not inferred by this package.

Format reference (namida):
https://www.lemmingsforums.net/index.php?topic=4337.0
Ultimate Lemmings implementation reference:
Sources/NxlvKit/NeoLemmixMacArtwork.swift
Sources/NxlvKit/ClassicMacArtwork.swift
Sources/LemmingsLocal/NeoLemmixSpriteSet.swift

SOURCE LIMITS

Lemmings and Oh No! also contain object sequences with null source slots.
These sequences remain incomplete in this export.
Xmas '92's brick object table is recovered from the Holiday '94 Levels resource.
Some of those referenced brick frames are absent from the Xmas graphics bank.
Holiday '94 also contains a brick object table without a brick graphics bank.
index.json lists all {index['summary']['incomplete_object_sequences']} incomplete object sequences.
No animation strip is generated for an incomplete sequence.
Null slots are retained in decoded manifests and never replaced with guessed art.
PICT fallback images use the existing ImageMagick decoder in prepare.py.
Bank 1400 includes unused images as well as the mapped lemming actions.

PROVENANCE AND NOTICES

Original art comes from the locally supplied Macintosh releases named above.
index.json records SHA-256 hashes of the Graphics, Levels and application forks
used by the decoder. Original disks, executables, levels and music are omitted.
The existing decoder follows resource_dasm's SHPD and Presage LZSS research.
See DECODER-NOTICE.txt for its MIT notice. That notice applies to the decoder
reference, not to the commercial game artwork. This package grants no new
licence to the original artwork.

VERIFICATION

Every asset PNG was decoded again and checked against all source RGBA bytes.
Each strip's placed frames were checked for clipping and pixel changes.
Every archived file was compared with its packaged file, and ZIP CRCs passed.
No NeoLemmix runtime integration test was performed.

REPRODUCTION

In an Ultimate Lemmings source checkout with the supplied Mac data:
  python3 Tools/MacArtwork/prepare.py .build/mac-artwork/handoff-source
  python3 Tools/MacArtwork/package.py .build/mac-artwork/handoff-source \\
    .build/exports/Macintosh-Graphics-NeoLemmix

The decoder requires unar and ImageMagick. The packager requires Pillow.
Choose an output folder and ZIP filename that do not already exist.
"""


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Output directory from prepare.py")
    parser.add_argument("output", type=Path, help="New package directory, with an adjacent ZIP")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    build(args.source.resolve(), args.output.resolve(), project)
