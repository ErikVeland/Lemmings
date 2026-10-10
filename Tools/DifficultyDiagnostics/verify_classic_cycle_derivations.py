"""Verify cycle-corrected Golems replay shifts against cached source bytes."""

import csv
import hashlib
import json
import re
from pathlib import Path

from decode_golems_replays import decode, source_bytes


ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / ".build/learning-evidence"
EVIDENCE = ROOT / "Artifacts/DifficultyEvaluation"


def main():
    shifted = json.loads((EVIDENCE / "classic-golems-cycle-derivations.json").read_text())
    terminal = json.loads((EVIDENCE / "classic-golems-terminal-derivations.json").read_text())
    single_path = EVIDENCE / "classic-golems-single-event-derivations.json"
    single = json.loads(single_path.read_text()) if single_path.exists() else []
    multiple_path = EVIDENCE / "classic-golems-multiple-event-derivations.json"
    multiple = json.loads(multiple_path.read_text()) if multiple_path.exists() else []
    records = shifted + terminal + single + multiple
    sources = json.loads((CACHE / "lldb-all-records/manifest.json").read_text())
    solutions = json.loads((ROOT / "Artifacts/LearningJourney/candidate-solutions.json").read_text())
    audit = json.loads((ROOT / "Artifacts/ClassicProgression/audit.json").read_text())
    level_sources = {(row["entry"]["identity"]["packID"],
                      row["entry"]["identity"]["levelID"]): row for row in audit}
    with (EVIDENCE / "levels.csv").open(newline="") as stream:
        ledger = {(row["pack"], row["level"]): row for row in csv.DictReader(stream)}
    current = superseded = 0
    for record in records:
        identity = record["identity"]
        key = identity["packID"], identity["levelID"]
        assert level_sources[key]["entry"]["sourceRevision"] == record["levelSourceRevision"]
        assert level_sources[key]["initialHash"] == record["initialStateHash"]
        entry = ledger[key]
        assert entry["completion"] == "verified win"
        if entry["replay_sha256"] == record["nativeReplaySHA256"]:
            current += 1
        else:
            superseded += 1
        replay = solutions["SHA256 digest: " + record["nativeReplaySHA256"]]
        assert replay["initialStateHash"] == record["initialStateHash"]
        assert replay["expected"]["didWin"]
        assert replay["expected"]["saved"] == record["nativeSaved"]
        assert replay["expected"]["ticks"] == record["nativeCompletionTicks"]
        matching = [source for source in sources if source["identity"] == identity
                    and source["url"] == record["publishedReplayURL"]
                    and source["sourceReplaySHA256"] == record["publishedReplaySHA256"]]
        assert matching, key
        assert all(source["sourceSaved"] == matching[0]["sourceSaved"]
                   and source["sourceTicks"] == matching[0]["sourceTicks"]
                   and source["gameMode"] == matching[0]["gameMode"]
                   for source in matching)
        source = matching[0]
        assert source["sourceSaved"] == record["sourceSaved"]
        assert source["sourceTicks"] == record["sourceHeaderTicks"]
        assert source["gameMode"] == record["sourceGameMode"]
        page_name = "-".join(re.search(r"/level/(\d+)/(\d+)", source["url"]).groups()) + ".html"
        for page in CACHE.glob("lldb-*/" + page_name):
            try:
                raw = source_bytes(page, source["recordIndex"])
            except (IndexError, ValueError):
                continue
            if hashlib.sha256(raw).hexdigest() == record["publishedReplaySHA256"]:
                break
        else:
            raise AssertionError(f"cached source replay missing: {key}")
        assert (raw[0] & 15, raw[1], int.from_bytes(raw[2:4], "little")) == (
            record["sourceGameMode"], record["sourceSaved"], record["sourceHeaderTicks"])
        if "globalTickShift" in record:
            shift = record["globalTickShift"]
            assert 1 <= abs(shift) <= 16
            events = [{**event, "tick": event["tick"] + shift} for event in decode(raw)]
        elif "adjustedEventIndex" in record:
            events = decode(raw)
            index = record["adjustedEventIndex"]
            assert events[index]["tick"] == record["sourceTick"]
            assert 1 <= abs(record["nativeTick"] - record["sourceTick"]) <= 8
            events[index] = {**events[index], "tick": record["nativeTick"]}
        elif "adjustedEvents" in record:
            events = decode(raw)
            edits = record["adjustedEvents"]
            assert 2 <= len(edits) <= 4
            assert len({edit["eventIndex"] for edit in edits}) == len(edits)
            for edit in edits:
                index = edit["eventIndex"]
                assert events[index]["tick"] == edit["sourceTick"]
                assert 1 <= abs(edit["nativeTick"] - edit["sourceTick"]) <= 2
                events[index] = {**events[index], "tick": edit["nativeTick"]}
        else:
            assert record["translation"] == "terminal abandon to native nuke"
            events = decode(raw, abandon_as_nuke=True)
        assert all(event["tick"] >= 0 for event in events)
        assert replay["events"] == events, key
    print(f"Verified {len(shifted)} shifted, {len(terminal)} terminal, {len(single)} single-event, and {len(multiple)} multiple-event Golems source replays: "
          f"{current} selected, {superseded} superseded by other verified wins.")


if __name__ == "__main__":
    main()
