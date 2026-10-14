#!/usr/bin/env python3
"""Package the original named sound banks with the TV development app."""
import argparse
from pathlib import Path
import shutil

parser = argparse.ArgumentParser()
parser.add_argument("--source", required=True)
parser.add_argument("--app", required=True)
args = parser.parse_args()
destination = Path(args.app) / "Sounds" / "Amiga"
destination.mkdir(parents=True, exist_ok=True)
for name in ("basicfx", "fullfx"):
    source = Path(args.source) / name
    if not source.is_file():
        raise SystemExit(f"Missing original sound bank: {source}")
    shutil.copyfile(source, destination / name)
print("Packaged original Amiga sound banks")
