#!/usr/bin/env python3
"""Copy the slim soundtrack bundle into an iOS app: the essential tracker modules and the index.

The remaining recordings are optional libraries that the app downloads on demand.
This needs the music source tree. Without it the app still runs, silent.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def copy_into_app(app):
    if app.suffix != ".app":
        raise ValueError("Music can only be copied into an app bundle.")
    target = app / "Music"
    if target.is_symlink():
        raise ValueError("Music destination must not be a link.")
    source = ROOT / "Sources/Music"
    if not source.is_dir():
        if target.exists():
            shutil.rmtree(target)
        print("note: music sources are not present; building without the soundtrack.")
        return
    subprocess.run([sys.executable, str(ROOT / "Tools/MusicCatalogue/library.py"), "bundle",
                    "--output", str(target), "--game", "all", "--scope", "main"], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    copy_into_app(parser.parse_args().app)


if __name__ == "__main__":
    main()
