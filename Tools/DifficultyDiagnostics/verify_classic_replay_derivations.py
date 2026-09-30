"""Check current and superseded Classic replay edits against their source records."""

import base64
import csv
import hashlib
import json
import pathlib
import re
import zlib


ROOT = pathlib.Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "Artifacts/DifficultyEvaluation"
CACHE = ROOT / ".build/learning-evidence"


def replay_bytes(page, index):
    fragments = list(dict.fromkeys(re.findall(r"#s=([^\"']+)", page.read_text())))
    fragment = fragments[index]
    raw = base64.urlsafe_b64decode(fragment.lstrip("~") + "===")
    return raw if fragment.startswith("~") else zlib.decompress(raw, -15)


def main():
    records = json.loads((EVIDENCE / "classic-replay-derivations.json").read_text())
    manifest = json.loads((CACHE / "lldb-all-records/manifest.json").read_text())
    solutions = json.loads((ROOT / "Artifacts/LearningJourney/candidate-solutions.json").read_text())
    audit = json.loads((ROOT / "Artifacts/ClassicProgression/audit.json").read_text())
    sources = {(row["entry"]["identity"]["packID"], row["entry"]["identity"]["levelID"]): row for row in audit}
    clock_records = json.loads((EVIDENCE / "classic-fan-clock-audit.json").read_text())
    clocks = {(row["packID"], row["levelID"]): row for row in clock_records}
    assert len(clocks) == len(clock_records)
    with (EVIDENCE / "levels.csv").open(newline="") as stream:
        ledger = {(row["pack"], row["level"]): row for row in csv.DictReader(stream)}
    current = superseded = 0
    for record in records:
        identity = record["identity"]
        key = identity["packID"], identity["levelID"]
        assert sources[key]["entry"]["sourceRevision"] == record["levelSourceRevision"]
        entry = ledger[key]
        assert entry["completion"] == "verified win"
        selected = solutions["SHA256 digest: " + entry["replay_sha256"]]
        assert selected["initialStateHash"] == sources[key]["initialHash"]
        assert selected["initialStateHash"] == clocks[key]["newHash"]
        assert selected["expected"]["didWin"]
        if entry["replay_sha256"] == record["nativeReplaySHA256"]:
            current += 1
        else:
            superseded += 1
        native = solutions["SHA256 digest: " + record["nativeReplaySHA256"]]
        assert native["initialStateHash"] == clocks[key]["oldHash"]
        assert native["expected"]["didWin"]
        source_events = json.loads(json.dumps(native["events"]))
        if "adjustedEvents" in record:
            edits = record["adjustedEvents"]
            assert 2 <= len(edits) <= 4
            assert len({edit["eventIndex"] for edit in edits}) == len(edits)
            for edit in edits:
                index = edit["eventIndex"]
                assert native["events"][index]["tick"] == edit["nativeTick"]
                assert 1 <= abs(edit["nativeTick"] - edit["sourceTick"]) <= 2
                source_events[index]["tick"] = edit["sourceTick"]
        elif "globalTickShift" in record:
            shift = record["globalTickShift"]
            assert 1 <= abs(shift) <= 8
            assert source_events
            for event in source_events:
                event["tick"] -= shift
                assert event["tick"] >= 0
        else:
            index = record["adjustedEventIndex"]
            assert native["events"][index]["tick"] == record["nativeTick"]
            assert 1 <= abs(record["nativeTick"] - record["sourceTick"]) <= 8
            source_events[index]["tick"] = record["sourceTick"]
        source_identity = record.get("sourceIdentity", identity)
        if source_identity != identity:
            source_row = sources[(source_identity["packID"], source_identity["levelID"])]
            assert source_row["initialHash"] == sources[key]["initialHash"]
        matches = [item for item in manifest if item["identity"] == source_identity
                   and item["url"] == record["publishedReplayURL"]
                   and item["sourceReplaySHA256"] == record["publishedReplaySHA256"]
                   and json.loads((ROOT / item["candidate"]).read_text())["events"] == source_events]
        assert len(matches) == 1, key
        match = matches[0]
        page_name = "-".join(re.search(r"/level/(\d+)/(\d+)", match["url"]).groups()) + ".html"
        pages = list(CACHE.glob("lldb-*/" + page_name))
        assert pages, key
        assert any(hashlib.sha256(replay_bytes(page, match["recordIndex"])).hexdigest()
                   == match["sourceReplaySHA256"] for page in pages)
    print(f"Verified {len(records)} Classic replay derivations and source records: "
          f"{current} current, {superseded} historical DOS-clock inputs with current Golems-clock wins.")


if __name__ == "__main__":
    main()
