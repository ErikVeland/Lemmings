#!/usr/bin/env python3
"""Copy the soundtrack bundle into an iOS or tvOS app.

Local builds include all soundtracks. Distribution builds can select main scope
and download the optional libraries on demand. Both scopes bundle the Amiga
modules and the Macintosh song bank.
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
    copy_mac_music(app)


def copy_mac_music(app):
    """Render the Macintosh SONG bank as the Mac app does. Renders are cached in .build/mac-music."""
    target = app / "MacMusic"
    if target.is_symlink():
        raise ValueError("MacMusic destination must not be a link.")
    artwork = ROOT / ".build/mac-artwork"
    # Mac artwork preparation extracts the Music resource forks from the supplied disks.
    if not all((artwork / game / "Music.rsrc").is_file() for game in ("original", "ohno")):
        subprocess.run([sys.executable, str(ROOT / "Tools/MacArtwork/prepare.py"), str(artwork / "export")], check=True)
    tools = subprocess.run(["zsh", str(ROOT / "Scripts/ensure-mac-music-tools.sh")],
                           check=True, stdout=subprocess.PIPE, text=True).stdout.strip()
    subprocess.run([sys.executable, str(ROOT / "Tools/MacMusic/prepare.py"),
                    "--output", str(target), "--tools", tools], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--scope", choices=("main", "full"),
                        default=os.environ.get("IOS_MUSIC_SCOPE", "full"))
    args = parser.parse_args()
    copy_into_app(args.app, args.scope)


if __name__ == "__main__":
    main()
