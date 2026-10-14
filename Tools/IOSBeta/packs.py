#!/usr/bin/env python3
"""Copy the level catalogue data into an iOS app bundle: stock releases and fan packs."""
import argparse
from pathlib import Path
import shutil

from ports import stage
from games import copy_into_app as copy_games, is_source_gate

ROOT = Path(__file__).resolve().parents[2]
PACKS = ROOT / "Content/LevelPacks"


def copy_into_app(app_resources):
    if app_resources.suffix != ".app":
        raise ValueError("Catalogue data can only be copied into an app bundle.")
    localisation = app_resources / "Localization.bundle"
    if localisation.is_symlink():
        raise ValueError("Localisation destination must not be a link.")
    if localisation.exists():
        shutil.rmtree(localisation)
    shutil.copytree(ROOT / "Sources/NxlvKit/Resources/Localization.bundle", localisation)
    ports = app_resources / "Ports"
    packs = app_resources / "LevelPacks"
    for target in (ports, packs):
        if target.is_symlink():
            raise ValueError("Catalogue destination must not be a link.")
        if target.exists():
            shutil.rmtree(target)
    source_gate = is_source_gate()
    try:
        stage(ports)
    except (ValueError, FileNotFoundError):
        if not source_gate:
            raise
        print("SKIP Classic catalogue data in the unsigned source-only gate.")
    copy_games(app_resources, source_gate=source_gate)
    if not (PACKS / "packs.json").is_file() and not source_gate:
        raise ValueError("Missing embedded fan level packs in Content/LevelPacks.")
    if PACKS.is_dir():
        packs.mkdir()
        for path in sorted(PACKS.iterdir()):
            if path.is_file() and not path.is_symlink() and path.suffix in (".zip", ".json"):
                shutil.copyfile(path, packs / path.name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--resources", type=Path, required=True)
    copy_into_app(parser.parse_args().resources)


if __name__ == "__main__":
    main()
