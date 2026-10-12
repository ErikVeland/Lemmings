#!/usr/bin/env python3
"""Stage the stock-release graphics folders that Classic-engine levels borrow.

Fan packs and the festive releases take sprites, sounds and ground graphics from
a few small stock folders. This copies only game data files. Executables,
installers and documents stay behind.
"""
import argparse
import hashlib
import json
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


def directory_revision(root, excluded=frozenset()):
    ignored = {"sav", "mp4", "m4a", "wav", "ogg", "mp3", "mod", "mid", "png", "jpg"}
    entries = {}
    for path in root.rglob("*"):
        relative = path.relative_to(root)
        if any(part.startswith(".") for part in relative.parts) or not path.is_file():
            continue
        if path.suffix.lower().lstrip(".") in ignored | excluded:
            continue
        entries["/" + relative.as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    if not entries:
        return None
    # Match JSONEncoder.sortedKeys, including its escaped path separators.
    encoded = json.dumps(entries, sort_keys=True, ensure_ascii=False, separators=(",", ":")).replace("/", "\\/")
    return hashlib.sha256(encoded.encode()).hexdigest()


def source_revisions(destination):
    releases = dict(zip(STOCK, ["lemmings", "ohNoMoreLemmings", "xmasLemmings1991", "xmasLemmings1992"]))
    revisions = {title: directory_revision(PORTS / folder, {"exe", "bat"}) for folder, title in releases.items()}
    folders = ["amiga_extracted/lemmings", "amiga_extracted/ohno", "Genesis-Sunsoft", STOCK[0], STOCK[1]]
    scoped = {folder: directory_revision(PORTS / folder, {"exe", "bat"}) or "missing" for folder in folders}
    encoded = json.dumps(scoped, sort_keys=True, separators=(",", ":")).replace("/", "\\/")
    exclusive = hashlib.sha256(encoded.encode()).hexdigest()
    revisions["ohYesMoreLemmings"] = ("fc020d72e88706953d4737e1b5fa09f5b653d7a70e4e1c1fa1cfa5546a24a908"
        if exclusive == "843c764dea3913f6e03c46d08b0fa53761dcc48c65b6628bbe7f0d01204df9ad" else exclusive)
    for year in ("1993", "1994"):
        revisions["holidayLemmings" + year] = directory_revision(destination / ("holiday_native_" + year))
    return {key: value for key, value in revisions.items() if value is not None}


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
                if path.is_file() and not path.is_symlink() and ((path.name.startswith("level") and path.name != "leveldata") or path.name in ("basicfx", "fullfx")):
                    shutil.copyfile(path, target / path.name)
        # The shared sound player reads the Macintosh resource fork directly.
        mac_sound = PORTS / "lemmings_1_5_2/Lemmings_1_5_2.dsk"
        if mac_sound.is_file() and not mac_sound.is_symlink():
            mac_target = destination / "lemmings_1_5_2"
            mac_target.mkdir()
            shutil.copyfile(mac_sound, mac_target / mac_sound.name)
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
        (destination / "source-revisions.json").write_text(json.dumps(source_revisions(destination), sort_keys=True, indent=2) + "\n")
    except Exception:
        shutil.rmtree(destination)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", type=Path, required=True)
    stage(parser.parse_args().destination)


if __name__ == "__main__":
    main()
