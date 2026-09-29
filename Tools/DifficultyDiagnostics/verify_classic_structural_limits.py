"""Check bundled fan levels that cannot meet the native rescue requirement."""

import csv
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / ".build/learning-evidence/unverified-structure/evaluated/port-descriptors.json"
RECORDS = ROOT / "Artifacts/DifficultyEvaluation/classic-structural-limits.json"


def main():
    artifact = json.loads(RECORDS.read_text())
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == artifact["descriptorSHA256"]
    descriptors = json.loads(SOURCE.read_text())
    audit = json.loads((ROOT / "Artifacts/ClassicProgression/audit.json").read_text())
    levels = {row["entry"]["identity"]["packID"] + "\0"
              + row["entry"]["identity"]["levelID"]: row for row in audit}
    with (ROOT / "Artifacts/DifficultyEvaluation/levels.csv").open(newline="") as stream:
        ledger = {(row["pack"], row["level"]): row for row in csv.DictReader(stream)}
    expected = {}
    for key, value in descriptors.items():
        if not key.startswith("fan:"):
            continue
        no_exit = value["requiredToSave"] > 0 and value["exitTriggerCount"] == 0
        excess = value["requiredToSave"] > value["totalLemmings"]
        if no_exit or excess:
            expected[key] = "no functional exit" if no_exit else "rescue requirement exceeds population"
    records = artifact["records"]
    assert len(records) == len(expected)
    for record in records:
        identity = record["identity"]
        key = identity["packID"] + "\0" + identity["levelID"]
        source = descriptors[key]
        row = levels[key]
        assert record["reason"] == expected.pop(key)
        assert record["levelSourceRevision"] == row["entry"]["sourceRevision"]
        assert record["initialStateHash"] == row["initialHash"]
        assert record["title"] == row["entry"]["levelNameSnapshot"]
        assert record["exitObjectSlots"] == sorted(
            obj["slot"] for obj in source["objects"] if obj["id"] == 0)
        for field in ("exitTriggerCount", "entranceCount", "totalLemmings", "requiredToSave"):
            assert record[field] == source[field]
        if record["reason"] == "no functional exit":
            assert not record["exitObjectSlots"] or min(record["exitObjectSlots"]) >= 16
        assert ledger[(identity["packID"], identity["levelID"])]["completion"] == "no verified win"
        assert ledger[(identity["packID"], identity["levelID"])]["playtest"] == record["reason"]
    assert not expected
    print(f"Verified {len(records)} structural limits on exact bundled fan levels: "
          f"{sum(record['reason'] == 'no functional exit' for record in records)} no functional exits, "
          f"{sum(record['reason'] == 'rescue requirement exceeds population' for record in records)} "
          "excess rescue requirements.")


if __name__ == "__main__":
    main()
