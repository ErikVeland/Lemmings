#!/usr/bin/env python3
"""Copy the original clock frames and fonts, retaining their manifest indices."""
import argparse
import json
from pathlib import Path
import shutil


def prune(source, destination):
    source, destination = Path(source).resolve(), Path(destination)
    if destination.is_symlink() or source == destination.resolve() or source in destination.resolve().parents:
        raise ValueError("Use a separate artwork destination.")
    document = json.loads((source / "manifest.json").read_text())
    selections = {"1400": set(range(43)) | {75} | set(range(77, 111)) | set(range(127, 143))
                  | set(range(215, 247)) | set(range(299, 307)) | set(range(321, 353)),
                  "1500": {3, 9, 10, 36, 37, 38, 39}, "1600": set(range(17))}
    for bank, name in document.get("names", {}).items():
        if name in ("Charset1", "Charset2"):
            selections[bank] = set(range(len(document["banks"][bank])))
    banks = {}
    files = set()
    for bank, indices in selections.items():
        records = document["banks"][bank]
        banks[bank] = [frame if i in indices else None for i, frame in enumerate(records)]
        for frame in banks[bank]:
            if frame:
                name = frame["file"]
                if Path(name).name != name or ".." in name or (source / name).is_symlink():
                    raise ValueError("Invalid artwork frame path.")
                files.add(name)
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)
    for name in sorted(files):
        shutil.copyfile(source / name, destination / name)
    document["banks"] = banks
    document["objects"] = {key: value for key, value in document.get("objects", {}).items() if key in banks}
    document["names"] = {key: value for key, value in document.get("names", {}).items() if key in banks}
    (destination / "manifest.json").write_text(json.dumps(document, separators=(",", ":")))
    size = sum(p.stat().st_size for p in destination.iterdir())
    if size >= 2_000_000:
        raise ValueError(f"Clock artwork exceeds 2 MB: {size} bytes.")
    print(f"PASS clock artwork: {len(files)} original frames, {size} bytes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source")
    parser.add_argument("destination")
    args = parser.parse_args()
    prune(args.source, args.destination)
