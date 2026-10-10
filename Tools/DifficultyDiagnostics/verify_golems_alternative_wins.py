"""Check identities and replay digests for alternate Golems object-rule wins."""

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "Artifacts/DifficultyEvaluation"


def read(path):
    return json.loads(path.read_text())


def identity(value):
    return value["packID"], value["levelID"]


def main():
    rows = read(OUTPUT / "classic-golems-alternative-evidence.json")
    solutions = read(OUTPUT / "classic-golems-alternative-solutions.json")
    comparisons = {
        identity(row["identity"]): row
        for row in read(OUTPUT / "classic-golems-object-comparisons.json")
    }
    seen = set()
    for row in rows:
        entry = row["entry"]
        key = identity(entry["identity"])
        assert key not in seen and key in comparisons
        seen.add(key)
        assert not comparisons[key]["golemsDidWin"]
        assert row["profile"]["confidence"] != "low"
        assert math.isfinite(row["profile"]["overallScore"])
        assert row["profile"]["key"]["identity"] == entry["identity"]
        assert row["initialHash"] == comparisons[key]["nativeInitialHash"]
        pack_number = int(key[0].split("-")[-1])
        archives = list((ROOT / "Content/LevelPacks").glob(f"{pack_number:04d}-*.zip"))
        assert len(archives) == 1
        assert hashlib.sha256(archives[0].read_bytes()).hexdigest() == entry["sourceRevision"]
        revision = row["profile"]["key"]["replayRevision"]
        replay = solutions[revision]
        assert replay["initialStateHash"] == row["initialHash"]
        assert replay["rank"] == key[0]
        assert replay["expected"]["didWin"]
        assert replay["expected"]["saved"] >= replay["expected"]["required"]
        encoded = json.dumps(replay, indent=2, separators=(",", " : "),
                             sort_keys=True, ensure_ascii=False).encode()
        assert "SHA256 digest: " + hashlib.sha256(encoded).hexdigest() == revision
    print(f"Verified {len(rows)} alternate Golems object-rule replay identities and digests.")


if __name__ == "__main__":
    main()
