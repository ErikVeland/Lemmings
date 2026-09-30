"""Stage a checked source-clock evidence set without changing published records."""

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return json.loads(path.read_text())


def identity(row):
    level = row["entry"]["identity"]
    return level["packID"], level["levelID"]


def indexed(rows):
    result = {identity(row): row for row in rows}
    assert len(result) == len(rows), "duplicate level identity"
    return result


def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def main(baseline_path, rescore_paths, output):
    original = read(ROOT / "Artifacts/ClassicProgression/audit.json")
    old_fan = read(ROOT / "Artifacts/LearningJourney/fan-evidence.json")
    previous = indexed(original)
    previous.update(indexed(old_fan))
    baseline = indexed(read(baseline_path))
    rescored_records = [record for path in rescore_paths for record in read(path)]
    repaired = {identity(record["row"]): record["recoveredOldReplayDigest"]
                for record in rescored_records if record.get("recoveredOldReplayDigest")}
    assert repaired == {
        ("fan:lldb-88", "Timpack1.dat#1"):
            "SHA256 digest: 28309041ba09b08e165fb0562c8dfb36ba1910bb316f10a8751a8bdf4de787a5",
        ("fan:lldb-88", "Timpack1.dat#5"):
            "SHA256 digest: c87d0788d1abc053591868c066e3b73c10e32e1e7ffc86105098af3832b67969",
        ("fan:lldb-90", "Timpack3.dat#5"):
            "SHA256 digest: 71b62b516b36b5cef0904ba4dc7681f549d9a3d5f7bbdebf170c1b41812c0450",
    }, "replay integrity repair set differs from the audited three"
    repair_records = read(ROOT / "Artifacts/DifficultyEvaluation/source-clock-candidates/replay-integrity-repairs.json")
    assert len(repair_records) == 3
    for repair in repair_records:
        key = repair["identity"]["packID"], repair["identity"]["levelID"]
        record = next(item for item in rescored_records if identity(item["row"]) == key)
        assert repair["actualStoredReplayRevision"] == repaired[key]
        assert repair["newReplayRevision"] == record["row"]["profile"]["key"]["replayRevision"]
        assert repair["newDifficultyScore"] == record["row"]["profile"]["overallScore"]
    clock_checks = read(ROOT / "Artifacts/DifficultyEvaluation/classic-fan-clock-audit.json")
    clock_order = {(check["packID"], check["levelID"]): index
                   for index, check in enumerate(clock_checks)}
    assert len(clock_order) == len(rescored_records) == 2138, "source-clock rescore is incomplete"
    rescored_records.sort(key=lambda record: clock_order[identity(record["row"])])
    rescored = indexed([record["row"] for record in rescored_records])
    new_records = read(ROOT / "Artifacts/DifficultyEvaluation/source-clock-candidates/canonical-lldb-224.json")
    new_rows = indexed([record["row"] for record in new_records])
    source_fan = {identity(row) for row in original if not row["official"]}
    expected_fan = set(baseline)
    assert source_fan - expected_fan == {
        ("fan:lldb-595", "LEVELPAK.DAT#0"),
        ("fan:lldb-595", "LEVELPAK.DAT#1"),
    }, "unexpected unbundled audit rows"
    expected_wins = {key for key in expected_fan if previous[key]["profile"]["confidence"] != "low"}
    assert len(expected_fan) == 6020 and len(expected_wins) == 2141
    assert set(baseline) == expected_fan
    assert set(rescored) == set(clock_order)
    assert set(new_rows) == expected_wins - set(clock_order)
    revision = "golems-clock-2-limit-from-clock-1"
    replays = read(ROOT / "Artifacts/LearningJourney/candidate-solutions.json")
    for record in rescored_records:
        row = record["row"]
        key = identity(row)
        source = previous[key]
        base = baseline[key]
        replay = record["replay"]
        assert record["analysisRevision"] == revision
        assert row["entry"] == source["entry"] == base["entry"]
        assert record["oldHash"] == source["initialHash"]
        assert record["newHash"] == base["initialHash"] == replay["initialStateHash"]
        assert replay["expected"]["didWin"] and row["profile"]["confidence"] != "low"
        assert row["profile"]["key"]["identity"] == row["entry"]["identity"]
        assert row["profile"]["key"]["simulationVersion"].endswith(":" + revision)
        digest = row["profile"]["key"]["replayRevision"]
        assert digest not in replays or replays[digest] == replay
        replays[digest] = replay
        replays.setdefault(record["newHash"], replay)
    for record in new_records:
        row = record["row"]
        key = identity(row)
        replay = record["replay"]
        assert key not in clock_order and row["entry"] == previous[key]["entry"] == baseline[key]["entry"]
        assert row["initialHash"] == baseline[key]["initialHash"] == replay["initialStateHash"]
        assert replay["expected"]["didWin"] and row["profile"]["confidence"] != "low"
        assert row["profile"]["key"]["simulationVersion"].endswith(":" + revision)
        digest = row["profile"]["key"]["replayRevision"]
        assert digest not in replays or replays[digest] == replay
        replays[digest] = replay
        replays.setdefault(row["initialHash"], replay)
    candidate = next(row for row in original if identity(row) == (
        "fan:lldb-554", "Lemmings Plus DOS Project - 10 - Danger (Part 1).dat#5"))
    alternative = dict(candidate)
    alternative["initialHash"] = baseline[identity(candidate)]["initialHash"]
    alternative["profile"] = read(ROOT / "Artifacts/DifficultyEvaluation/source-clock-candidates/alternative-logic-profile.json")
    alternative["issue"] = None
    alternative_replay = read(ROOT / "Artifacts/DifficultyEvaluation/source-clock-candidates/alternative-logic-replay.json")
    assert alternative_replay["expected"]["didWin"]
    assert alternative_replay["initialStateHash"] == alternative["initialHash"]
    assert alternative["profile"]["key"]["identity"] == candidate["entry"]["identity"]
    alternative_digest = alternative["profile"]["key"]["replayRevision"]
    assert alternative_digest not in replays or replays[alternative_digest] == alternative_replay
    replays[alternative_digest] = alternative_replay
    replays.setdefault(alternative["initialHash"], alternative_replay)
    merged = []
    for row in original:
        if row["official"]:
            merged.append(row)
            continue
        if identity(row) not in expected_fan:
            continue
        replacement = dict(baseline[identity(row)])
        assert replacement["entry"] == row["entry"]
        replacement["order"] = row["order"]
        merged.append(replacement)
    evidence = [record["row"] for record in rescored_records] + [record["row"] for record in new_records] + [alternative]
    assert len(indexed(evidence)) == 2142
    for row in evidence:
        assert row["initialHash"] == baseline[identity(row)]["initialHash"]
    output.mkdir(parents=True, exist_ok=True)
    write(output / "audit.json", merged)
    write(output / "fan-evidence.json", evidence)
    write(output / "candidate-solutions.json", replays)
    print("Staged", len(expected_fan), "fan hashes and", len(evidence), "verified fan wins")


if __name__ == "__main__":
    if len(sys.argv) < 4:
        raise SystemExit("Usage: stage_classic_fan_clock_migration.py BASELINE RESCORE... OUTPUT")
    main(Path(sys.argv[1]), [Path(path) for path in sys.argv[2:-1]], Path(sys.argv[-1]))
