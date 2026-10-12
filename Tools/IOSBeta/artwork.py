#!/usr/bin/env python3
"""Copy locally decoded Classic artwork banks into an iOS app bundle."""
import argparse
import json
import os
from pathlib import Path
import shutil

# Kept for callers that inspect front-end names. Gameplay copies every bank.
BANKS = frozenset(["Charset1", "Charset2", "Logo1", "Logo2", "Icons", "Lemmings"])
FAMILIES = ("lemmings", "ohno", "xmas", "holiday")
ROOT = Path(__file__).resolve().parents[2]


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
    # The Xcode option remains a single-family path; siblings carry the other releases.
    mac = Path(source).parent if source else ROOT / ".build/mac-artwork/export"
    amiga = Path(os.environ.get("IOS_AMIGA_ARTWORK_DIR", ROOT / ".build/amiga-artwork/export"))
    for kind, root in (("MacArtwork", mac), ("AmigaArtwork", amiga)):
        for family in FAMILIES:
            copy_family(root / family, destination.parent.parent / kind / family)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="")
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    copy_into_app(args.source, args.destination)


if __name__ == "__main__":
    main()
