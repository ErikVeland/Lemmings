#!/usr/bin/env python3
"""Prepare and verify a pinned CC0 Lix artwork pack with ImageMagick."""

import argparse
from collections import Counter
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PIN = ROOT / "Resources/AlternativeAssets/lix-source.json"
DEFAULT_OUTPUT = ROOT / ".build/alternative-assets/lix"
MAX_EXPANDED = 64 * 1024 * 1024


def digest(data):
    """Return the SHA-256 digest of bytes."""
    return hashlib.sha256(data).hexdigest()


def read_archive(path, pin):
    """Reject altered archives and unsafe members before reading their content."""
    expected = pin["archive"]
    if path.stat().st_size != expected["bytes"]:
        raise ValueError("The Lix source archive does not match its pinned size and hash.")
    data = path.read_bytes()
    if digest(data) != expected["sha256"]:
        raise ValueError("The Lix source archive does not match its pinned size and hash.")
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        members = archive.getmembers()
        validate_members(members, expected["root"])
        files = {}
        for member in members:
            if member.isfile():
                relative = PurePosixPath(member.name).relative_to(expected["root"]).as_posix()
                files[relative] = archive.extractfile(member).read()
    return files


def validate_members(members, root):
    """Allow bounded regular files and directories under one archive root."""
    names = set()
    expanded = 0
    if len(members) > 10000:
        raise ValueError("The source archive has too many members.")
    for member in members:
        path = PurePosixPath(member.name)
        if (path.is_absolute() or ".." in path.parts or not path.parts
                or path.parts[0] != root or "\\" in member.name
                or path.as_posix() != member.name.rstrip("/")
                or not (member.isfile() or member.isdir()) or member.name in names):
            raise ValueError("The source archive contains an unsafe member.")
        names.add(member.name)
        expanded += member.size
        if member.size < 0 or expanded > MAX_EXPANDED:
            raise ValueError("The source archive exceeds its expanded size limit.")


def select_files(files, pin):
    """Select only cleared graphics, definitions, notices and inert references."""
    selected = {}
    counts = Counter()
    for source in sorted(files):
        target = None
        if source.startswith("data/images/") and source.endswith(".png") and source not in pin["excluded"]:
            target = "assets/" + source
            counts["interfacePNGs"] += 1
        elif source.startswith("images/") and source.endswith((".png", ".txt")):
            target = "assets/" + source
            counts["tilesetPNGs" if source.endswith(".png") else "tileDefinitions"] += 1
        elif source == pin["licence"]["sourcePath"]:
            target = "licences/copying.txt"
        elif source in pin["references"]:
            target = "reference/" + source + ".txt"
        if target:
            selected[target] = source
    required = [pin["licence"]["sourcePath"], *pin["references"], "data/images/lixsprites.png", "data/images/lixrecol.png"]
    if any(source not in files for source in required) or dict(counts) != pin["expected"]:
        raise ValueError("The pinned Lix source is incomplete.")
    if digest(files[pin["licence"]["sourcePath"]]) != pin["licence"]["sha256"]:
        raise ValueError("The Lix licence does not match the pinned notice.")
    return selected


def magick(arguments, data=None):
    """Run the repository's existing image tool without a shell."""
    binary = shutil.which("magick")
    if not binary:
        raise ValueError("Install ImageMagick to prepare or verify the artwork.")
    result = subprocess.run([binary, *map(str, arguments)], input=data,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise ValueError("ImageMagick failed: " + result.stderr.decode(errors="replace").strip()[:1000])
    return result.stdout


def dimensions(paths):
    """Decode each PNG and return its native dimensions."""
    result = {}
    for offset in range(0, len(paths), 100):
        batch = paths[offset:offset + 100]
        lines = magick(["identify", "-regard-warnings", "-format", "%w %h\n", *batch]).decode().splitlines()
        if len(lines) != len(batch):
            raise ValueError("An artwork file is not a single PNG image.")
        for path, line in zip(batch, lines):
            width, height = map(int, line.split())
            if not (0 < width <= 4096 and 0 < height <= 4096):
                raise ValueError("An artwork image exceeds the supported preparation size.")
            result[path] = {"width": width, "height": height}
    return result


def rgba(path):
    """Decode native RGBA pixels through ImageMagick."""
    return magick([path, "-alpha", "on", "-depth", "8", "rgba:-"])


def sprite_model(path, files):
    """Record upstream grid geometry and activity rows without engine adaptation."""
    raw = rgba(path)
    width, height = 913, 946
    if len(raw) != width * height * 4:
        raise ValueError("The pinned sprite sheet dimensions changed.")
    pixel = lambda x, y: raw[(y * width + x) * 4:(y * width + x + 1) * 4]
    grid = pixel(0, 0)
    frame_width = next(x - 1 for x in range(2, width) if pixel(x, 1) == grid)
    frame_height = next(y - 1 for y in range(2, height) if pixel(1, y) == grid)
    if (frame_width, frame_height) != (34, 34):
        raise ValueError("The pinned sprite grid changed.")
    declaration = files["src/net/ac.d"].decode().split("enum Ac : ubyte {", 1)[1].split("}", 1)[0]
    activities = [line.strip().rstrip(",") for line in declaration.splitlines() if line.strip()]
    if len(activities) != 27:
        raise ValueError("The pinned Lix activity list changed.")
    rows = []
    for row, name in enumerate(activities):
        frames = []
        for column in range(26):
            x, y = 1 + 35 * column, 1 + 35 * row
            if any(pixel(x + dx, y + dy) != grid for dy in range(34) for dx in range(34)):
                frames.append({"x": x, "y": y, "width": 34, "height": 34})
        rows.append({"activity": name, "row": row, "frames": frames})
    return {"sourcePath": "data/images/lixsprites.png", "frameWidth": 34, "frameHeight": 34,
            "gridRGBA": list(grid), "frameOrigin": [1, 1], "frameStride": [35, 35],
            "columns": 26, "rows": rows, "upstreamRightFacingFootAnchor": [16, 26],
            "recolourSource": "data/images/lixrecol.png", "recolourSourceRow": 0,
            "gardenTargetRow": 1, "timing": "Upstream activity cycles need an engine-specific adapter."}


def tile_model():
    """Retain the upstream tile naming and transparency rules without adapting masks."""
    return {"sourcePath": "src/tile/tilelib.d", "terrainSuffix": ".png",
            "preExtensions": {"S": "steel terrain", "H": "hatch", "G": "goal", "T": "trap",
                              "F": "fire", "W": "water", "X": "hidden", "I": "internal"},
            "transparencyKeyRGB": [255, 0, 255], "transparencySource": "src/basics/alleg5.d",
            "definitions": "Same-name .txt sidecars retain upstream trigger and animation definitions.",
            "solidity": "Lix terrain solidity follows remaining opaque pixels. Target-engine masks remain unverified."}


def render_previews(stage, model):
    """Make contact sheets with integer scaling and native source colours."""
    previews = stage / "previews"
    previews.mkdir()
    fonts = ("/System/Library/Fonts/Helvetica.ttc", "/System/Library/Fonts/Supplemental/Arial.ttf")
    font = next((path for path in fonts if Path(path).is_file()), "DejaVu-Sans")
    sprite = stage / "assets/data/images/lixsprites.png"
    frames = []
    for activity in ("walker", "climber", "floater", "builder", "basher", "miner", "digger", "blocker"):
        row = next(row for row in model["rows"] if row["activity"] == activity)
        for frame in row["frames"][:6]:
            frames += ["(", sprite, "-crop", "{width}x{height}+{x}+{y}".format(**frame),
                       "+repage", "-filter", "point", "-resize", "300%", ")"]
    magick(["montage", "-font", font, *frames, "-tile", "6x", "-geometry", "+4+4", "-background", "#242333",
            "-strip",
            previews / "sprites.png"])
    icons = [stage / "assets/data/images" / name for name in
             ("skillsinpanel.png", "gamebigbuttons/1.png", "gamesmallbuttons/1.png", "gamepause/1.png", "checkbox/1.png")]
    magick(["montage", "-font", font, *icons, "-tile", "1x", "-geometry", "+8+8", "-background", "#242333",
            "-strip", previews / "interface.png"])
    tiles = sorted((stage / "assets/images").rglob("*.png"))
    representatives = {}
    for path in tiles:
        group = tuple(path.relative_to(stage / "assets/images").parts[:2])
        if group in representatives or path.stem.split(".")[-1] in {"H", "G", "T", "F", "W", "X", "I"}:
            continue
        size = dimensions([path])[path]
        if 8 <= size["width"] <= 160 and 8 <= size["height"] <= 128:
            representatives[group] = path
    inputs = []
    for path in representatives.values():
        inputs += ["(", path, "-alpha", "on", "-transparent", "#ff00ff", "-filter", "point", "-resize", "200%", ")"]
    magick(["montage", "-font", font, *inputs, "-tile", "6x", "-geometry", "+8+8", "-background", "#242333", "-strip", previews / "tilesets.png"])
    return {"sprites.png": "Eight activity rows, six source frames each, nearest-neighbour 3x.",
            "interface.png": "Original interface sheets at native resolution.",
            "tilesets.png": "Representative terrain pieces, nearest-neighbour 2x; magenta colour key removed for preview."}


def file_records(stage, selected):
    """Inventory every output file except the manifest itself."""
    paths = sorted(path for path in stage.rglob("*") if path.is_file() and path.name != "manifest.json")
    sizes = dimensions([path for path in paths if path.suffix == ".png"])
    records = []
    for path in paths:
        relative = path.relative_to(stage).as_posix()
        data = path.read_bytes()
        record = {"path": relative, "bytes": len(data), "sha256": digest(data),
                  "kind": "upstream" if relative in selected else "prepared"}
        if relative in selected:
            record["sourcePath"] = selected[relative]
        if path in sizes:
            record.update(sizes[path])
        records.append(record)
    return records


def prepare(archive, output, pin):
    """Build in a sibling staging folder and replace only a complete pack."""
    verify_output_target(archive, output, pin)
    files = read_archive(archive, pin)
    selected = select_files(files, pin)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".lix-stage-", dir=output.parent) as temporary:
        stage = Path(temporary) / "pack"
        stage.mkdir()
        for target, source in selected.items():
            path = stage / target
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(files[source])
        model = sprite_model(stage / "assets/data/images/lixsprites.png", files)
        (stage / "sprite-metadata.json").write_text(json.dumps(model, indent=2) + "\n")
        preview_notes = render_previews(stage, model)
        (stage / "README.txt").write_text(
            "Lix alternative artwork source pack\n\n"
            "CC0-1.0. Read licences/copying.txt for upstream scope and exceptions.\n"
            "Fonts, Lix app branding, audio, levels and executables are excluded.\n"
            "Original PNG bytes and sidecar definitions are preserved.\n"
            "reference/ contains selected inert upstream source references only.\n"
            "Sprite recolouring uses lixrecol.png; these previews show source colours.\n"
            "Terrain uses magenta (255, 0, 255) as a transparency key in upstream.\n"
            "Sprite anchors and frame rows describe Lix, not Classic, L2 or L3.\n"
            "Animation timing, masks, object triggers and engine adapters remain unverified.\n"
            "No artwork is installed into the game by this preparation tool.\n")
        manifest = {"schemaVersion": 1, "id": pin["id"], "revision": pin["revision"],
                    "archive": pin["archive"], "licence": pin["licence"], "counts": pin["expected"],
                    "compatibility": pin["compatibility"], "tileMetadata": tile_model(), "previews": preview_notes,
                    "files": file_records(stage, selected)}
        (stage / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        verify(archive, stage, pin)
        backup = Path(temporary) / "previous"
        if output.exists():
            output.rename(backup)
        try:
            stage.rename(output)
        except OSError:
            if backup.exists():
                backup.rename(output)
            raise
    return manifest


def verify_output_target(archive, output, pin):
    """Refuse to replace unrelated content or a symbolic-link output target."""
    if output.is_symlink():
        raise ValueError("Choose a new output folder or an existing verified Lix pack, not a symbolic link.")
    if output.exists():
        if not output.is_dir() or not (output / "manifest.json").is_file():
            raise ValueError("The output target is not an existing verified Lix pack.")
        verify(archive, output, pin)


def verify(archive, output, pin):
    """Verify source provenance, exact file coverage, dimensions and frame metadata."""
    files = read_archive(archive, pin)
    selected = select_files(files, pin)
    if output.is_symlink() or any(path.is_symlink() for path in output.rglob("*")):
        raise ValueError("The artwork pack contains a symbolic link.")
    manifest = json.loads((output / "manifest.json").read_text())
    if (manifest["revision"] != pin["revision"] or manifest["archive"] != pin["archive"]
            or manifest["licence"] != pin["licence"] or manifest["counts"] != pin["expected"]
            or manifest.get("tileMetadata") != tile_model()):
        raise ValueError("The artwork manifest does not match the pinned source.")
    prepared = {"README.txt", "sprite-metadata.json", "previews/sprites.png", "previews/interface.png", "previews/tilesets.png"}
    expected_paths = set(selected) | prepared
    records = manifest["files"]
    if (len(records) != len(expected_paths)
            or {record["path"] for record in records} != expected_paths):
        raise ValueError("The artwork manifest contains unexpected or missing files.")
    actual = {path.relative_to(output).as_posix() for path in output.rglob("*") if path.is_file()}
    if actual != expected_paths | {"manifest.json"}:
        raise ValueError("The artwork pack contains unmanifested or missing files.")
    for record in records:
        path = output / record["path"]
        data = path.read_bytes()
        if len(data) != record["bytes"] or digest(data) != record["sha256"]:
            raise ValueError("An artwork file does not match its inventory.")
        if record["path"] in selected:
            source = selected[record["path"]]
            if record.get("sourcePath") != source or data != files[source]:
                raise ValueError("An upstream artwork file changed during preparation.")
    pngs = [output / record["path"] for record in records if record["path"].endswith(".png")]
    sizes = dimensions(pngs)
    for record in records:
        path = output / record["path"]
        if path in sizes and any(record.get(key) != value for key, value in sizes[path].items()):
            raise ValueError("An artwork dimension does not match its inventory.")
    expected_model = sprite_model(output / "assets/data/images/lixsprites.png", files)
    if json.loads((output / "sprite-metadata.json").read_text()) != expected_model:
        raise ValueError("The prepared sprite metadata does not match the source pixels.")
    return manifest


class SafetyTests(unittest.TestCase):
    """Exercise archive rejection separately from the real preparation run."""

    def test_unsafe_members(self):
        for name in ("/root/file", "root/../file", "other/file", "root\\file", "root/./file", "root//file"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                validate_members([tarfile.TarInfo(name)], "root")
        for kind in (tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.FIFOTYPE):
            member = tarfile.TarInfo("root/file")
            member.type = kind
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                validate_members([member], "root")

    def test_duplicate_and_large_members(self):
        member = tarfile.TarInfo("root/file")
        with self.assertRaises(ValueError):
            validate_members([member, member], "root")
        member.size = MAX_EXPANDED + 1
        with self.assertRaises(ValueError):
            validate_members([member], "root")

    def test_archive_hash_and_incomplete_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "bad.tar.gz"
            archive.write_bytes(b"invalid")
            with self.assertRaises(ValueError):
                read_archive(archive, json.loads(PIN.read_text()))
            pin = json.loads(PIN.read_text())
            archive.write_bytes(bytes(pin["archive"]["bytes"]))
            with self.assertRaises(ValueError):
                read_archive(archive, pin)
        with self.assertRaises(ValueError):
            select_files({}, json.loads(PIN.read_text()))

    def test_unrelated_output_and_symbolic_link_are_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary) / "unrelated"
            folder.mkdir()
            marker = folder / "important.txt"
            marker.write_text("Keep this file.")
            with self.assertRaises(ValueError):
                verify_output_target(Path("unused.tar.gz"), folder, {})
            self.assertEqual(marker.read_text(), "Keep this file.")
            link = Path(temporary) / "output-link"
            link.symlink_to(folder, target_is_directory=True)
            with self.assertRaises(ValueError):
                verify_output_target(Path("unused.tar.gz"), link, {})
            self.assertTrue(link.is_symlink())
            self.assertEqual(marker.read_text(), "Keep this file.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="Verify the prepared pack without downloading or writing it.")
    parser.add_argument("--self-test", action="store_true", help="Run data-independent archive safety tests.")
    parser.add_argument("--check-archive", type=Path, help="Verify a downloaded source archive before caching it.")
    parser.add_argument("--archive", type=Path, help="Use an existing pinned source archive.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    pin = json.loads(PIN.read_text())
    archive = args.archive or ROOT / ".build/dependencies" / pin["archive"]["filename"]
    if args.self_test:
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(SafetyTests)
        if not unittest.TextTestRunner(verbosity=1).run(suite).wasSuccessful():
            raise SystemExit(1)
    elif args.check_archive:
        select_files(read_archive(args.check_archive, pin), pin)
        print("PASS pinned Lix source archive and licence")
    else:
        manifest = verify(archive, args.output, pin) if args.verify else prepare(archive, args.output, pin)
        print(f"PASS Lix graphics: {len(manifest['files'])} inventoried files, output {args.output}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, StopIteration, subprocess.CalledProcessError, tarfile.TarError) as error:
        raise SystemExit(f"FAILED: {error}") from error
