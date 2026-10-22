#!/usr/bin/env python3
"""Copy only the Macintosh frames the Desk Clock draws into a smaller artwork directory.

The output has the same manifest format as the source, so ClassicMacArtwork(directory:)
loads it. Frames that the clock does not use become null entries, which keeps every
frame at its original index.

Usage: prune_artwork.py --source <MacArtwork/lemmings> --destination <dir>
"""
import argparse
import json
import os
import shutil
import sys


def ranges(*spans):
    kept = set()
    for span in spans:
        if isinstance(span, tuple):
            kept.update(range(span[0], span[1] + 1))
        else:
            kept.add(span)
    return kept


# Lemmings: walk, fall, dig, explosion, build, block, umbrella, exit and "Oh no!".
LEMMINGS = ranges((0, 41), 75, (77, 109), (127, 142), (215, 230), (299, 306), (337, 352))
# Grounds1: the flat slab, grass tufts and the rock texture.
GROUNDS = ranges(3, 9, 10, (36, 39))
# Objects1: the trapdoor, the exit top and the exit arch.
OBJECTS = ranges((0, 16))
CHARSETS = ("Charset1", "Charset2")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", required=True, help="Directory that holds the full manifest.json")
    parser.add_argument("--destination", required=True, help="Directory for the pruned artwork")
    arguments = parser.parse_args()

    with open(os.path.join(arguments.source, "manifest.json")) as handle:
        manifest = json.load(handle)
    names = manifest.get("names", {})
    keep = {"1400": LEMMINGS, "1500": GROUNDS, "1600": OBJECTS}
    for name in CHARSETS:
        bank = next((key for key, value in names.items() if value == name), None)
        if bank is None:
            sys.exit(f"The source artwork has no {name} bank.")
        keep[bank] = None  # Every frame.
    for bank in keep:
        if bank not in manifest["banks"]:
            sys.exit(f"The source artwork has no bank {bank}.")

    os.makedirs(arguments.destination, exist_ok=True)
    banks = {}
    for bank, indices in keep.items():
        records = []
        for index, record in enumerate(manifest["banks"][bank]):
            if record is None or (indices is not None and index not in indices):
                records.append(None)
                continue
            shutil.copyfile(os.path.join(arguments.source, record["file"]),
                            os.path.join(arguments.destination, record["file"]))
            records.append(record)
        banks[bank] = records

    # Object sequences are keyed by graphic set; Objects1 (bank 1600) is set 0.
    objects = {key: value for key, value in manifest.get("objects", {}).items()
               if str(1600 + int(key)) in keep}
    pruned = {
        "version": manifest["version"],
        "monochrome": manifest.get("monochrome", False),
        "banks": banks,
        "names": {key: value for key, value in names.items() if key in keep},
        "objects": objects,
    }
    with open(os.path.join(arguments.destination, "manifest.json"), "w") as handle:
        json.dump(pruned, handle, separators=(",", ":"))


if __name__ == "__main__":
    main()
