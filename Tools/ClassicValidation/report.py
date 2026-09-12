#!/usr/bin/env python3
"""Check corpus coverage independently of the app's level decoder."""
import collections
import hashlib
import json
from pathlib import Path
import sys
import zipfile


def report(resources, output):
    library = resources / "LevelPacks"
    rows = [json.loads(line) for line in (output / "levels.jsonl").read_text().splitlines()]
    packs = json.loads((output / "packs.json").read_text())
    index = json.loads((library / "level-counts.json").read_text())
    actual = {pack["pack"]: int(pack["decodedLevels"]) for pack in packs}
    failures = []
    if set(actual) != {path.name for path in library.glob("*.zip")}:
        failures.append("Audited archives differ from the packaged library")
    if actual != index:
        failures.append("Decoded pack counts differ from the packaged index")
    if len(packs) != len(actual):
        failures.append("Duplicate pack records")
    sources = [row["source"] for row in rows if row["collection"] == "fan"]
    if len(sources) != len(set(sources)) or len(sources) != sum(actual.values()):
        failures.append("Fan rows are missing or duplicated")
    represented = {(source.split("/", 1)[0], source.split("/", 1)[1].rsplit("#", 1)[0]) for source in sources}
    inventory = []
    for pack in packs:
        path = library / pack["pack"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != pack["sha256"].removeprefix("SHA256 digest: "):
            failures.append("Pack changed during the audit: " + pack["pack"])
        with zipfile.ZipFile(path) as archive:
            for entry in archive.infolist():
                name = Path(entry.filename)
                lower = name.name.lower()
                if entry.is_dir() or name.suffix.lower() not in {".lvl", ".dat", ".ini", ".nxlv"}:
                    continue
                if lower == "levelpack.ini" or lower.startswith(("ground", "vgagr", "vgaspec")):
                    continue
                classification = "decoded-level-file"
                if (pack["pack"], entry.filename) not in represented:
                    # Reviewed graphics definitions shipped beside the levels.
                    definitions = {
                        ("0401-Christmas-2013.zip", "christmas/christmas.ini"),
                        ("0415-Blizzard-of-Lemm.zip", "mods/blizzlem/styles/snow/snow.ini"),
                    }
                    text = archive.read(entry).decode("latin1")
                    if (pack["pack"], entry.filename) in definitions and "tiles =" in text and "frames_0" in text and "numLemmings" not in text:
                        classification = "graphics-definition"
                    else:
                        classification = "unaccounted-file"
                        failures.append("Unaccounted content: " + pack["pack"] + "/" + entry.filename)
                inventory.append({"pack": pack["pack"], "file": entry.filename, "classification": classification})
    counts = collections.defaultdict(collections.Counter)
    for row in rows:
        counts[row["collection"]][row["status"]] += 1
    expected = {"lemmings": 120, "ohNoMoreLemmings": 100, "xmasLemmings1991": 4,
                "xmasLemmings1992": 4, "holidayLemmings1993": 32, "holidayLemmings1994": 32,
                "ohYesMoreLemmings": 60}
    for collection, total in expected.items():
        subset = [row for row in rows if row["collection"] == collection]
        if len(subset) != total or len({row["source"] for row in subset}) != total:
            failures.append("Incomplete or duplicate collection: " + collection)
    if any(row["status"] == "winning-replay" and (not row.get("witness") or not row.get("initialHash")) for row in rows):
        failures.append("Winning rows lack replay provenance")
    unverified = sum(row["status"] != "winning-replay" for row in rows)
    if unverified:
        failures.append(f"{unverified} levels lack verified winning replays")
    result = {"passed": not failures, "failures": failures, "counts": counts,
              "packs": len(packs), "fanLevels": len(sources), "inventory": inventory}
    (output / "coverage.json").write_text(json.dumps(result, indent=2) + "\n")
    (output / "blockers.json").write_text(json.dumps([row for row in rows if row["status"] != "winning-replay"], indent=2) + "\n")
    print(json.dumps({key: value for key, value in result.items() if key != "inventory"}, indent=2))
    return not failures


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: report.py RESOURCES AUDIT_OUTPUT")
    sys.exit(0 if report(Path(sys.argv[1]), Path(sys.argv[2])) else 1)
