#!/usr/bin/env python3
"""Copy locally decoded Classic artwork banks into an iOS app bundle."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil

# Kept for callers that inspect front-end names. Gameplay copies every bank.
BANKS = frozenset(["Charset1", "Charset2", "Logo1", "Logo2", "Icons", "Lemmings"])
FAMILIES = ("lemmings", "ohno", "xmas", "holiday")
ROOT = Path(__file__).resolve().parents[2]


def verify_menu_fonts(source):
    """Require both usable character sets before an app can be packaged."""
    source = Path(source)
    manifest = source / "manifest.json"
    try:
        document = json.loads(manifest.read_text())
    except (OSError, ValueError) as error:
        raise ValueError(f"Missing or invalid menu fonts at {source}. Restore the Mac artwork export or set the platform's MAC_ARTWORK_DIR.") from error
    counts = {}
    for face in ("Charset1", "Charset2"):
        banks = [key for key, name in document.get("names", {}).items() if name == face]
        frames = document.get("banks", {}).get(banks[0], []) if len(banks) == 1 else []
        if len(frames) < 95 or any(frame is None for frame in frames[1:95]):
            raise ValueError(f"Menu font {face} is incomplete at {source}.")
        for frame in frames[:95]:
            if frame is None:
                continue  # The space glyph may be blank.
            name = frame["file"]
            width, height = frame["width"], frame["height"]
            if "/" in name or ".." in name or (source / name).is_symlink():
                raise ValueError("Unsafe menu font frame path.")
            if not (0 < width <= 4096 and 0 < height <= 4096):
                raise ValueError(f"Invalid menu font dimensions in {face}.")
            try:
                data = (source / name).read_bytes()
            except OSError as error:
                raise ValueError(f"Missing menu font pixels in {face}: {name}.") from error
            if len(data) != width * height * 4 or not any(data[3::4]):
                raise ValueError(f"Missing or truncated menu font pixels in {face}: {name}.")
        counts[face] = 94
    return {"manifestSHA256": hashlib.sha256(manifest.read_bytes()).hexdigest(), "printableGlyphs": counts}


def inputs(source):
    source = Path(source)
    manifest = source / "manifest.json"
    if not manifest.is_file():
        return []
    document = json.loads(manifest.read_text())
    result = {manifest}
    for frames in document["banks"].values():
        for frame in frames:
            if frame:
                name = frame["file"]
                if "/" in name or ".." in name or (source / name).is_symlink():
                    raise ValueError("Unsafe artwork frame path.")
                result.add(source / name)
    return sorted(result)


def copy_family(source, destination):
    if destination.is_symlink():
        raise ValueError("App artwork destination must not be a link.")
    if destination.exists():
        shutil.rmtree(destination)
    files = inputs(source)
    if not files:
        return
    destination.mkdir(parents=True)
    for path in files:
        shutil.copyfile(path, destination / path.name)


def copy_into_app(source, destination):
    if destination.name != "lemmings" or destination.parent.name != "MacArtwork" or destination.parent.parent.suffix != ".app":
        raise ValueError("Mac artwork can only be copied into an app bundle.")
    mac = mac_root(source)
    verify_menu_fonts(mac / "lemmings")
    menu_art = destination.parent.parent / "MenuArtwork"
    menu_art.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / "Resources/MenuArtwork/ultimate.png", menu_art / "ultimate.png")
    shutil.copyfile(ROOT / "Resources/MenuArtwork/lemmings-chronicles.pcx", menu_art / "lemmings-chronicles.pcx")
    # The Xcode option remains a single-family path; siblings carry the other releases.
    amiga = Path(os.environ.get("IOS_AMIGA_ARTWORK_DIR", ROOT / ".build/amiga-artwork/export"))
    for kind, root in (("MacArtwork", mac), ("AmigaArtwork", amiga)):
        for family in (*FAMILIES, *("monochrome/" + family for family in FAMILIES)):
            copy_family(root / family, destination.parent.parent / kind / family)
    verify_menu_fonts(destination)


def mac_root(source=""):
    # A family can be linked to an existing export. Its siblings live beside the target.
    family = Path(source) if source else ROOT / ".build/mac-artwork/export/lemmings"
    return family.resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="")
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    copy_into_app(args.source, args.destination)


if __name__ == "__main__":
    main()
