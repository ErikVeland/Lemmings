"""Check bundled fan levels that cannot meet the native rescue requirement."""

import csv
import hashlib
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RAW_SOURCE = ROOT / ".build/learning-evidence/fan-slot-scan/evaluated/port-descriptors.json"
SOURCE = ROOT / ".build/learning-evidence/fan-slot-scan/evaluated/bundled-port-descriptors.json"
SCAN_AUDIT = ROOT / ".build/learning-evidence/fan-slot-scan/evaluated/audit.json"
AUDIT = ROOT / "Artifacts/ClassicProgression/audit.json"
RECORDS = ROOT / "Artifacts/DifficultyEvaluation/classic-structural-limits.json"


def main():
    if sys.argv[1:] == ["--pin-bundled"]:
        raw = json.loads(RAW_SOURCE.read_text())
        pack_ids = {"fan:lldb-" + str(pack["id"]) for pack in
                    json.loads((ROOT / "Content/LevelPacks/packs.json").read_text())}
        bundled = {key: value for key, value in raw.items()
                   if key.split("\0", 1)[0] in pack_ids}
        assert len(bundled) == sum(1 for row in json.loads(SCAN_AUDIT.read_text())
                                   if row["entry"]["identity"]["packID"] in pack_ids)
        temporary = SOURCE.with_suffix(".tmp")
        temporary.write_text(json.dumps(bundled, sort_keys=True, separators=(",", ":")) + "\n")
        temporary.replace(SOURCE)
        print(f"Pinned {len(bundled)} bundled fan descriptors.")
        return
    descriptors = json.loads(SOURCE.read_text())
    audit = json.loads(AUDIT.read_text())
    levels = {row["entry"]["identity"]["packID"] + "\0"
              + row["entry"]["identity"]["levelID"]: row for row in audit}
    expected = {}
    for key, value in descriptors.items():
        if not key.startswith("fan:"):
            continue
        no_exit = value["requiredToSave"] > 0 and value["exitTriggerCount"] == 0
        excess = value["requiredToSave"] > value["totalLemmings"]
        if no_exit or excess:
            expected[key] = "no functional exit" if no_exit else "rescue requirement exceeds population"
    if sys.argv[1:] == ["--refresh"]:
        records = []
        for key, reason in sorted(expected.items()):
            source, row = descriptors[key], levels[key]
            records.append({
                "identity": row["entry"]["identity"],
                "title": row["entry"]["levelNameSnapshot"],
                "levelSourceRevision": row["entry"]["sourceRevision"],
                "initialStateHash": row["initialHash"],
                "reason": reason,
                "exitObjectSlots": sorted(obj["slot"] for obj in source["objects"] if obj["id"] == 0),
                **{field: source[field] for field in
                   ("exitTriggerCount", "entranceCount", "totalLemmings", "requiredToSave")},
            })
        RECORDS.write_text(json.dumps({
            "diagnostic": "Exact bundled Classic fan levels under the native fan object and rescue rules",
            "descriptorSHA256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
            "records": records,
        }, indent=2) + "\n")
        print(f"Refreshed {len(records)} structural limits.")
        return
    assert not sys.argv[1:]
    artifact = json.loads(RECORDS.read_text())
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == artifact["descriptorSHA256"]
    with (ROOT / "Artifacts/DifficultyEvaluation/levels.csv").open(newline="") as stream:
        ledger = {(row["pack"], row["level"]): row for row in csv.DictReader(stream)}
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
