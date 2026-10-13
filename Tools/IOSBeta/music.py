#!/usr/bin/env python3
"""Copy the soundtrack bundle into an iOS app.

Local builds include all soundtracks. Distribution builds can select main scope
and download the optional libraries on demand.
"""
import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def copy_into_app(app, scope="full"):
    if scope not in ("main", "full"):
        raise ValueError("Music scope must be main or full.")
    if app.suffix != ".app":
        raise ValueError("Music can only be copied into an app bundle.")
    target = app / "Music"
    if target.is_symlink():
        raise ValueError("Music destination must not be a link.")
    source = ROOT / "Sources/Music"
    if not source.is_dir():
        raise ValueError("Music sources are missing. Restore Sources/Music before building the iOS app.")
    subprocess.run([sys.executable, str(ROOT / "Tools/MusicCatalogue/library.py"), "bundle",
                    "--output", str(target), "--game", "all", "--scope", scope], check=True)
    if scope == "full":
        subprocess.run(["zsh", str(ROOT / "Scripts/compact-bundled-music.sh"), str(target)], check=True)
        subprocess.run([sys.executable, str(ROOT / "Tools/MusicCatalogue/library.py"), "playback",
                        "--output", str(target)], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--scope", choices=("main", "full"),
                        default=os.environ.get("IOS_MUSIC_SCOPE", "full"))
    args = parser.parse_args()
    copy_into_app(args.app, args.scope)


if __name__ == "__main__":
    main()
