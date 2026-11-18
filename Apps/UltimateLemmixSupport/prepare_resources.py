#!/usr/bin/env python3
"""Prepare current full-game mobile metadata with the pinned alternative assets."""

import argparse
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = "ultimate-lemmix-mobile-resources.json"


def mobile_guide(output):
    archive = output / "Integration/Ultimate-Lemmix-BYO.zip"
    with zipfile.ZipFile(archive) as source:
        contract = json.loads(source.read("byo-integration.json"))
    contract["id"] = "ultimate-lemmix-mobile-owned-assets-v1"
    contract["platforms"] = ["ios", "tvos"]
    contract["rawGameImport"]["families"] = ["Classic DOS", "Lemmings 2 DOS", "Lemmings 3 DOS", "Supported NeoLemmix CE"]
    contract["originalPresentation"]["action"] = "Game Data > Restore original assets"
    contract["originalPresentation"]["sources"] = ["A player-supplied prepared preservation asset folder"]
    contract["installation"] = "Validated data stays outside the installed app: iOS application support or purgeable tvOS caches."
    contract["applicationImportRoutes"] = {"ios": "system-folder-picker", "tvos": "temporary-local-browser-upload-with-session-token"}
    guide = b"""Ultimate Lemmix: player-owned mobile assets

This helper contains this guide and a JSON contract. It contains no game
assets, executable code or game-file downloads. The three authored starter
puzzles need no original files.

iPhone and iPad
1. Put your prepared preservation asset folder in Files.
2. Open Settings, then Game Data in Ultimate Lemmix.
3. Choose Restore original assets.
4. Select your asset folder.

Apple TV
1. Connect Apple TV and your source device to the same local network.
2. Open Settings, then Game Data in Ultimate Lemmix.
3. Choose Restore original assets.
4. Open the displayed private address on your source device.
5. Select your prepared asset folder and complete the transfer.
6. Keep both import pages open until validation finishes.

The app copies and validates data before activation. It does not run the
source application. A failed import retains the previous active data.
iOS uses application support. Apple TV uses caches that the system can
purge. Keep your source files so you can import them again.

The individual Classic, Lemmings 2, Lemmings 3 and NeoLemmix controls import
their selected game data. A raw DOS folder does not supply Macintosh or
Amiga artwork, archival music or the full preservation asset collection.

The app retains its current metadata, proof identities and licensed Lix
fallback. Your files do not grant redistribution permission. This helper
does not download them.
"""
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w") as target:
        for name, data in (("README.txt", guide), ("byo-integration.json", (json.dumps(contract, indent=2) + "\n").encode())):
            entry = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            target.writestr(entry, data)
    archive.write_bytes(stream.getvalue())
    (output / "Integration/README.txt").write_bytes(guide)


def finalise(output):
    mobile_guide(output)
    subprocess.run(["python3", "-B", ROOT / "Tools/AlternativeAssets/prepare_lemmix_base.py",
                    "--output", output, "--inventory-only"], check=True)
    rows = []
    for path in sorted(output.rglob("*")):
        if path.is_symlink():
            raise ValueError("The prepared mobile resources contain a link.")
        if path.is_file() and path != output / MANIFEST:
            data = path.read_bytes()
            rows.append({"path": path.relative_to(output).as_posix(), "bytes": len(data),
                         "sha256": hashlib.sha256(data).hexdigest()})
    manifest = {"schemaVersion": 1, "kind": "ultimate-lemmix-full-game-mobile-resources",
                "engineFingerprint": (output / "Trolley/engine-fingerprint.txt").read_text().strip(),
                "files": rows}
    (output / MANIFEST).write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"Prepared {len(rows)} current full-game mobile resources: {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--alternative-resources", type=Path, required=True)
    parser.add_argument("--store", action="store_true")
    args = parser.parse_args()
    sys.path.insert(0, str(ROOT / "Tools/AlternativeAssets"))
    specification = importlib.util.spec_from_file_location(
        "prepare_lemmix_base", ROOT / "Tools/AlternativeAssets/prepare_lemmix_base.py")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    module.prepare(args.output, args.alternative_resources, store=args.store)
    if not args.store:
        subprocess.run(["zsh", ROOT / "Scripts/prepare-lix-interface.sh",
                    "--font", args.output / "Fonts/Lix/djvusans.ttf",
                    "--licence", args.output / "Licences/Lix-font-LICENSE.txt",
                    "--output", args.output / "Fonts/LixInterface"], check=True)
    # Asset catalogues provide the mobile icon. Never copy a Mac icon into the app.
    for name in ("AppIcon.png", "AppIcon.icns"):
        (args.output / name).unlink(missing_ok=True)
    finalise(args.output)


if __name__ == "__main__":
    main()
