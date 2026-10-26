#!/usr/bin/env python3
"""Stage only the native Classic DOS inputs used by the first iOS beta."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil

REQUIRED = frozenset(
    ["MAIN.DAT", "ODDTABLE.DAT"]
    + [f"LEVEL{i:03}.DAT" for i in range(10)]
    + [f"GROUND{i}O.DAT" for i in range(5)]
    + [f"VGAGR{i}.DAT" for i in range(5)]
    + [f"VGASPEC{i}.DAT" for i in range(4)]
)

PARITY_RESOURCES = ("Hints", "Progression", "Trolley", "GameCenter", "Sounds")


def copy_parity_resources(resources, app):
    """Copy the shared teaching and record catalogues into the mobile bundle."""
    for name in PARITY_RESOURCES:
        source = resources / name
        destination = app / name
        if destination.exists():
            shutil.rmtree(destination)
        if source.is_dir():
            shutil.copytree(source, destination)
    activation = os.environ.get("IOS_GAME_CENTER_ACTIVATION")
    if activation:
        from game_center import validate_activation
        validate_activation(activation, resources, os.environ.get("IOS_GAME_CENTER_BUNDLE_ID", "academy.glasscode.lemmings.ios"))
    catalogue = app / "GameCenter/leaderboards.json"
    if catalogue.is_file():
        config = json.loads(catalogue.read_text())
        config["enabled"] = bool(activation)
        catalogue.write_text(json.dumps(config, indent=2, sort_keys=True) + "\n")



def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stage(source, destination):
    if source.is_symlink() or not source.is_dir():
        raise ValueError("Classic source must be a local directory.")
    if destination.exists() or destination.is_symlink():
        raise ValueError("Content destination already exists. Use a new candidate directory.")
    selected = {}
    for path in source.iterdir():
        name = path.name.upper()
        if name in REQUIRED:
            if name in selected or path.is_symlink() or not path.is_file():
                raise ValueError(f"Duplicate, linked or invalid content input: {name}")
            selected[name] = path
    missing = REQUIRED - selected.keys()
    if missing:
        raise ValueError(f"Missing Classic input: {', '.join(sorted(missing))}")
    destination.mkdir(parents=True)
    try:
        for name, source_file in selected.items():
            shutil.copyfile(source_file, destination / name)
        manifest = {
            "schemaVersion": 1, "game": "classic", "campaignLevels": 120,
            "files": {name: digest(destination / name) for name in sorted(REQUIRED)},
        }
        (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        verify(destination)
    except Exception:
        shutil.rmtree(destination)
        raise


def verify(directory):
    if directory.is_symlink():
        raise ValueError("Content directory must not be a link.")
    manifest_path = directory / "manifest.json"
    if manifest_path.is_symlink():
        raise ValueError("Content manifest must not be a link.")
    manifest = json.loads(manifest_path.read_text())
    if (manifest.get("schemaVersion"), manifest.get("game"), manifest.get("campaignLevels")) != (1, "classic", 120):
        raise ValueError("Unexpected beta content scope or manifest version.")
    if set(manifest["files"]) != REQUIRED:
        raise ValueError("Content manifest must contain exactly the approved Classic inputs.")
    if {p.name for p in directory.iterdir()} != REQUIRED | {"manifest.json"}:
        raise ValueError("Content directory contains extra or missing files.")
    for name, expected in manifest["files"].items():
        path = directory / name
        if path.is_symlink() or not path.is_file() or digest(path) != expected:
            raise ValueError(f"Content hash mismatch or linked input: {name}")
    return manifest


def copy_into_app(source, destination, development_source=None):
    # A frozen export takes precedence over optional local development data.
    if destination.name != "BetaGameData" or destination.parent.suffix != ".app":
        raise ValueError("Beta content can only be copied into an app bundle.")
    if destination.is_symlink():
        raise ValueError("App content destination must not be a link.")
    copy_parity_resources(Path(__file__).resolve().parents[2] / "Resources", destination.parent)
    if not source:
        if destination.exists():
            shutil.rmtree(destination)
        if development_source and Path(development_source).exists():
            stage(Path(development_source), destination)
        return
    source_path = Path(source)
    verify(source_path)
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(source_path, destination)
    verify(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for command in ("stage", "copy"):
        sub = commands.add_parser(command)
        sub.add_argument("--source", required=True)
        sub.add_argument("--destination", type=Path, required=True)
        if command == "copy":
            sub.add_argument("--development-source", help="Optional original data for local Xcode Debug builds")
    sub = commands.add_parser("verify")
    sub.add_argument("directory", type=Path)
    args = parser.parse_args()
    if args.command == "stage":
        stage(Path(args.source), args.destination)
    elif args.command == "copy":
        copy_into_app(args.source, args.destination, args.development_source)
    else:
        verify(args.directory)


if __name__ == "__main__":
    main()
