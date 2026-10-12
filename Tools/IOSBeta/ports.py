#!/usr/bin/env python3
"""Stage the stock-release graphics folders that Classic-engine levels borrow.

Fan packs and the festive releases take sprites, sounds and ground graphics from
a few small stock folders. This copies only game data files. Executables,
installers and documents stay behind.
"""
import argparse
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
PORTS = ROOT / "Sources/Ports"
HOLIDAY = ROOT / ".build/holiday-assets/Holiday Lemmings 1994 Installer/Levels/..namedfork/rsrc"
STOCK = [
    "lemmings_dos_1991-07-30",
    "oh_no_more_lemmings_dos-1991-11-14_2232",
    "xmas_dos_XmasLemmingsV1.9",
    "xmas_dos_XmasLemmingsV1.9a1",
]
DATA = {".dat", ".rsrc"}


def stage(destination):
    if destination.exists() or destination.is_symlink():
        raise ValueError("Ports destination already exists. Use a new directory.")
    destination.mkdir(parents=True)
    try:
        for name in STOCK:
            source = PORTS / name
            if source.is_symlink() or not source.is_dir():
                raise ValueError(f"Missing stock release folder: {name}")
            (destination / name).mkdir()
            for path in sorted(source.iterdir()):
                if path.is_file() and not path.is_symlink() and path.suffix.lower() in DATA:
                    shutil.copyfile(path, destination / name / path.name)
        # Oh Yes! More Lemmings! reads Amiga level records and a converted Mega Drive archive.
        for family in ("lemmings", "ohno"):
            source = PORTS / "amiga_extracted" / family
            target = destination / "amiga_extracted" / family
            target.mkdir(parents=True)
            for path in sorted(source.iterdir()):
                if path.is_file() and not path.is_symlink() and path.name.startswith("level") and path.name != "leveldata":
                    shutil.copyfile(path, target / path.name)
        sunsoft = PORTS / "Genesis-Sunsoft"
        (destination / "Genesis-Sunsoft").mkdir()
        for path in sorted(sunsoft.iterdir()):
            if path.is_file() and not path.is_symlink() and path.suffix.lower() == ".dat":
                shutil.copyfile(path, destination / "Genesis-Sunsoft" / path.name)
        # Holiday levels live in a resource fork. Their graphics are the Xmas snow style.
        if HOLIDAY.is_file() and HOLIDAY.stat().st_size > 0:
            for year in ("1993", "1994"):
                target = destination / f"holiday_native_{year}"
                target.mkdir()
                shutil.copyfile(HOLIDAY, target / f"HOLIDAY{year}.RSRC")
                for name in ("MAIN.DAT", "GROUND2O.DAT", "VGAGR2.DAT"):
                    shutil.copyfile(PORTS / "xmas_dos_XmasLemmingsV1.9a1" / name, target / name)
    except Exception:
        shutil.rmtree(destination)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", type=Path, required=True)
    stage(parser.parse_args().destination)


if __name__ == "__main__":
    main()
