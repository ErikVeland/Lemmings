#!/usr/bin/env python3
"""Copy the Macintosh front-end banks the iOS interface draws into an app bundle."""
import argparse
import json
from pathlib import Path
import shutil

BANKS = frozenset(["Charset1", "Charset2", "Logo1", "Logo2", "Icons", "Lemmings"])


def copy_into_app(source, destination):
    if destination.name != "lemmings" or destination.parent.name != "MacArtwork" or destination.parent.parent.suffix != ".app":
        raise ValueError("Mac artwork can only be copied into an app bundle.")
    if destination.is_symlink():
        raise ValueError("App artwork destination must not be a link.")
    if destination.exists():
        shutil.rmtree(destination)
    if not source or not (Path(source) / "manifest.json").is_file():
        return
    source = Path(source)
    manifest = json.loads((source / "manifest.json").read_text())
    names = manifest.get("names") or {}
    keep = {key for key, name in names.items() if name in BANKS}
    manifest["banks"] = {key: frames for key, frames in manifest["banks"].items() if key in keep}
    manifest["objects"] = {}
    destination.mkdir(parents=True)
    for frames in manifest["banks"].values():
        for frame in frames:
            if frame:
                name = frame["file"]
                if "/" in name or ".." in name:
                    raise ValueError("Unsafe artwork frame path.")
                shutil.copyfile(source / name, destination / name)
    (destination / "manifest.json").write_text(json.dumps(manifest))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="")
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    copy_into_app(args.source, args.destination)


if __name__ == "__main__":
    main()
