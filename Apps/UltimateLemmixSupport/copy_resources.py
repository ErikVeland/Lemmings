#!/usr/bin/env python3
"""Copy only the verified clean profile into a separate mobile product."""

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath

MANIFEST = "ultimate-lemmix-mobile-resources.json"
RECEIPT = "ultimate-lemmix-resource-receipt.json"
FOLDERS = {"AlternativeAssets", "Fonts", "Music", "Licences", "Provenance", "Integration",
           "Localization.bundle", "About", "GameCenter", "Hints", "Progression", "Trolley", "Ports", "MenuArtwork"}
WIDGET_FOLDERS = {"AlternativeAssets", "Fonts", "Licences", "Provenance"}


def checked_path(name):
    path = PurePosixPath(name)
    if not name or path.is_absolute() or "\\" in name or any(part in ("", ".", "..") for part in name.split("/")):
        raise ValueError("A mobile resource path is unsafe.")
    if name == "ultimate-lemmix-data-inventory.json":
        return path
    if path.parts[0] not in FOLDERS or (path.parts[0] == "Ports" and path.parts[1:2] != ("ultimate_lemmix_starter",)):
        raise ValueError("A mobile resource is outside the clean profile.")
    return path


def read_checked(root, row):
    relative = checked_path(row["path"])
    path = root.joinpath(*relative.parts)
    if any(parent.is_symlink() for parent in (path, *path.parents) if parent == root or root in parent.parents):
        raise ValueError("A mobile resource path contains a link.")
    data = path.read_bytes()
    if len(data) != row["bytes"] or hashlib.sha256(data).hexdigest() != row["sha256"]:
        raise ValueError("A prepared mobile resource changed: " + row["path"])
    return data


def check_destination_path(root, name):
    target = root.joinpath(*checked_path(name).parts)
    if any(parent.is_symlink() for parent in (target, *target.parents) if parent == root or root in parent.parents):
        raise ValueError("A product resource path contains a link.")
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--scope", choices=("app", "widget"), required=True)
    args = parser.parse_args()
    if args.source.is_symlink() or args.destination.is_symlink():
        raise ValueError("The mobile resource root must not be a link.")
    if args.destination.name not in {"UltimateLemmixIOS.app", "UltimateLemmixTVOS.app", "DeskClockWidget.appex"}:
        raise ValueError("Copy resources only into the separate Ultimate Lemmix mobile products.")
    manifest = json.loads((args.source / MANIFEST).read_bytes())
    if manifest.get("kind") != "ultimate-lemmix-full-game-mobile-resources" or manifest.get("schemaVersion") != 1:
        raise ValueError("The full-game mobile resource manifest is invalid.")
    rows = manifest["files"]
    expected = {row["path"] for row in rows}
    actual = set()
    for path in args.source.rglob("*"):
        if path.is_symlink():
            raise ValueError("The mobile resource profile contains a link.")
        if path.is_file():
            actual.add(path.relative_to(args.source).as_posix())
    if len(expected) != len(rows) or actual != expected | {MANIFEST}:
        raise ValueError("The mobile resource inventory has extra or missing files.")
    # Verify the whole input profile even when an extension needs only its artwork.
    verified = {row["path"]: read_checked(args.source, row) for row in rows}
    selected = [row for row in rows if args.scope == "app" or PurePosixPath(row["path"]).parts[0] in WIDGET_FOLDERS]
    chosen = {row["path"] for row in selected}
    receipt = args.destination / RECEIPT
    if receipt.is_symlink():
        raise ValueError("The product resource receipt must not be a link.")
    previous = json.loads(receipt.read_bytes())["files"] if receipt.is_file() else []
    if {row["path"] for row in previous} - chosen:
        raise ValueError("The resource profile changed. Clean this derived product before rebuilding.")
    old = {row["path"]: row for row in previous}
    for row in previous:
        read_checked(args.destination, row)
    for prohibited in ("MacArtwork", "AmigaArtwork", "NeoLemmix", "LevelPacks", "BetaGameData"):
        if (args.destination / prohibited).exists():
            raise ValueError("The product contains resources outside the clean profile.")
    for family in FOLDERS:
        directory = args.destination / family
        if directory.is_symlink():
            raise ValueError("A product resource folder must not be a link.")
        for path in directory.rglob("*"):
            if path.is_symlink() or (path.is_file() and path.relative_to(args.destination).as_posix() not in old):
                raise ValueError("The product contains an untracked resource. Clean this derived product before rebuilding.")
    for row in selected:
        target = check_destination_path(args.destination, row["path"])
        if target.exists() and row["path"] not in old:
            raise ValueError("A mobile resource would replace an untracked file: " + row["path"])
    args.destination.mkdir(parents=True, exist_ok=True)
    for row in selected:
        target = check_destination_path(args.destination, row["path"])
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(verified[row["path"]])
    receipt.write_text(json.dumps({"schemaVersion": 1, "scope": args.scope, "files": selected}, indent=2, sort_keys=True) + "\n")
    print(f"Copied {len(selected)} verified full-game {args.scope} resources.")


if __name__ == "__main__":
    main()
