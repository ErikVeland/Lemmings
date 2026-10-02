"""Report Lemmini text objects placed beyond the Classic simulation height."""

import csv
import hashlib
import json
import re
import zipfile
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LEVELS = ROOT / "Artifacts/DifficultyEvaluation/levels.csv"
PACKS = ROOT / "Content/LevelPacks"
OUTPUT = ROOT / "Artifacts/DifficultyEvaluation/lemmini-classic-bounds.json"
CLASSIC_MAXIMUM_Y = 163
OBJECT = re.compile(r"^object_\d+\s*=\s*(\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)", re.M)


def main() -> None:
    with LEVELS.open(newline="") as source:
        rows = [row for row in csv.DictReader(source)
                if row["source_engine"] == "Lemmini" and row["level"].lower().endswith(".ini#-1")]

    pack_paths = {}
    findings = []
    for row in rows:
        pack = row["pack"]
        if pack not in pack_paths:
            pack_id = int(pack.rsplit("-", 1)[1])
            paths = list(PACKS.glob(f"{pack_id:04d}-*.zip"))
            if len(paths) != 1:
                raise ValueError(f"Expected one bundled ZIP for {pack}: {paths}")
            pack_paths[pack] = paths[0]

        member = row["level"].removesuffix("#-1")
        with zipfile.ZipFile(pack_paths[pack]) as archive:
            names = {name.casefold(): name for name in archive.namelist()}
            if member.casefold() not in names:
                raise ValueError(f"Missing bundled level {pack}/{member}")
            text = archive.read(names[member.casefold()]).decode("latin1")
        objects = [tuple(map(int, match.groups())) for match in OBJECT.finditer(text)]
        exits = [y for kind, _, y in objects if kind == 0]
        entrances = [y for kind, _, y in objects if kind == 1]
        all_exits_below = bool(exits) and all(y > CLASSIC_MAXIMUM_Y for y in exits)
        all_entrances_below = bool(entrances) and all(y > CLASSIC_MAXIMUM_Y for y in entrances)
        if all_exits_below or all_entrances_below:
            findings.append({
                "pack": pack,
                "level": row["level"],
                "allExitPlacementsBelowClassicMaximum": all_exits_below,
                "allEntrancePlacementsBelowClassicMaximum": all_entrances_below,
                "verifiedWin": row["completion"] == "verified win",
            })

    counts = Counter()
    for finding in findings:
        counts["either"] += 1
        counts["allExitsBelow"] += finding["allExitPlacementsBelowClassicMaximum"]
        counts["allEntrancesBelow"] += finding["allEntrancePlacementsBelowClassicMaximum"]
        counts["both"] += (finding["allExitPlacementsBelowClassicMaximum"]
                           and finding["allEntrancePlacementsBelowClassicMaximum"])
        counts["verifiedWins"] += finding["verifiedWin"]

    result = {
        "method": "Exact bundled INI object placement Y; object IDs 0 and 1 are the Classic exit and entrance slots. This flags a geometry mismatch, not an impossibility proof or source parity check.",
        "classicMaximumY": CLASSIC_MAXIMUM_Y,
        "lemminiINILevels": len(rows),
        "bundledArchives": {
            pack: {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
            for pack, path in sorted(pack_paths.items())
        },
        "counts": dict(counts),
        "findings": findings,
    }
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"lemminiINILevels": len(rows), "counts": dict(counts)}))


if __name__ == "__main__":
    main()
