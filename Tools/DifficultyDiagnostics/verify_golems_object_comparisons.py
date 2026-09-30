"""Check that the Golems object-slot comparison still names current native wins."""

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return json.loads(path.read_text())


def identity(value):
    return value["packID"], value["levelID"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "report", nargs="?", type=Path,
        default=ROOT / "Artifacts/DifficultyEvaluation/classic-golems-object-comparisons.json",
    )
    parser.add_argument("--expected-count", type=int)
    args = parser.parse_args()

    rows = {identity(row["entry"]["identity"]): row for row in read(
        ROOT / "Artifacts/ClassicProgression/audit.json"
    )}
    rows.update({identity(row["entry"]["identity"]): row for row in read(
        ROOT / "Artifacts/LearningJourney/fan-evidence.json"
    )})
    solutions = {}
    for name in (
        "Resources/Hints/solutions.json",
        "Resources/Progression/solutions.json",
        "Artifacts/LearningJourney/candidate-solutions.json",
    ):
        for key, replay in read(ROOT / name).items():
            solutions.setdefault(key, replay)

    records = read(args.report)
    if args.expected_count is not None:
        assert len(records) == args.expected_count, "comparison count changed"
    seen = set()
    for record in records:
        key = identity(record["identity"])
        assert key not in seen and key[0].startswith("fan:"), "duplicate or non-fan identity"
        seen.add(key)
        row = rows[key]
        assert row["profile"]["confidence"] != "low", "comparison is no longer a verified win"
        assert record["sourceRevision"] == row["entry"]["sourceRevision"]
        assert record["replayRevision"] == row["profile"]["key"]["replayRevision"]
        assert record["nativeInitialHash"] == row["initialHash"]
        replay = solutions.get(record["replayRevision"]) or solutions.get(record["nativeInitialHash"])
        assert replay is not None and replay["initialStateHash"] == record["nativeInitialHash"]
        expected = replay["expected"]
        assert expected["didWin"] and expected["saved"] == record["nativeSaved"]
        assert expected["ticks"] == record["nativeTicks"]
        has_result = record.get("golemsSaved") is not None
        assert has_result == (record.get("golemsTicks") is not None)
        assert has_result != (record.get("error") is not None)
        if record["golemsDidWin"]:
            assert has_result, "a failed replay cannot be a win"

    changed = sum(
        record.get("golemsSaved") != record["nativeSaved"]
        or record.get("golemsTicks") != record["nativeTicks"]
        for record in records
    )
    lost = sum(not record["golemsDidWin"] for record in records)
    errors = sum(record.get("error") is not None for record in records)
    print(f"Verified {len(records)} current native witnesses in the Golems object-slot report: "
          f"{changed} changed outcomes, {lost} lost wins, {errors} rejected or failed replays.")


if __name__ == "__main__":
    main()
