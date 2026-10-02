"""Verify source provenance for selected Golems replays with one retimed skill."""

import hashlib
import json
import re
from pathlib import Path

from decode_golems_replays import decode, source_bytes


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "Artifacts/DifficultyEvaluation"
CACHE = ROOT / ".build/learning-evidence"


def read(path):
    return json.loads(path.read_text())


def main():
    records = read(EVIDENCE / "classic-golems-selected-ordinary.json")["records"]
    selected = [record for record in records if record.get("nativeInputRetiming")]
    manifest = read(CACHE / "lldb-all-records/manifest.json")
    fan = {json.dumps(row["entry"]["identity"], sort_keys=True): row
           for row in read(ROOT / "Artifacts/LearningJourney/fan-evidence.json")}
    solutions = read(ROOT / "Artifacts/LearningJourney/candidate-solutions.json")
    for record in selected:
        identity = record["identity"]
        source = [item for item in manifest if item["identity"] == identity
                  and item["sourceReplaySHA256"] == record["sourceReplaySHA256"]]
        assert len(source) == 1, identity
        source = source[0]
        assert (source["url"], source["sourceSaved"], source["sourceTicks"]) == (
            record["sourceURL"], record["sourceHeaderSaved"], record["sourceHeaderTicks"])
        page_name = "-".join(re.search(r"/level/(\d+)/(\d+)", source["url"]).groups()) + ".html"
        raw = None
        for page in CACHE.glob("lldb-*/" + page_name):
            try:
                candidate = source_bytes(page, source["recordIndex"])
            except IndexError:
                continue
            if hashlib.sha256(candidate).hexdigest() == record["sourceReplaySHA256"]:
                raw = candidate
                break
        assert raw is not None, identity
        events = decode(raw, native_tick_offset=-1)
        change = record["nativeInputRetiming"]
        index = change["eventIndex"]
        assert events[index] == {"tick": change["convertedSourceTick"], "afterTick": True,
                                 "action": {"assign": {"lemmingID": change["lemmingID"],
                                                       "skill": change["skill"]}}}
        events[index] = dict(events[index], tick=change["nativeTick"])
        replay_path = ROOT / record["replayPath"]
        replay_bytes = replay_path.read_bytes()
        assert hashlib.sha256(replay_bytes).hexdigest() == record["nativeReplaySHA256"]
        replay = json.loads(replay_bytes)
        assert replay["events"] == events and not replay.get("sourceRules")
        assert replay["initialStateHash"] == record["initialStateHash"]
        assert replay["expected"]["didWin"] and replay["expected"]["saved"] == record["nativeSaved"]
        assert replay["expected"]["required"] == record["required"]
        assert replay["expected"]["ticks"] == record["nativeCompletionTick"]
        row = fan[json.dumps(identity, sort_keys=True)]
        assert row["entry"]["sourceRevision"] == record["bundledArchiveSHA256"]
        assert row["initialHash"] == record["initialStateHash"]
        assert row["profile"]["overallScore"] == record["difficultyScore"]
        assert solutions[row["profile"]["key"]["replayRevision"]] == replay
    assert len(selected) == 2
    print(f"Verified {len(selected)} exact-source Golems replays with one native input retiming")


if __name__ == "__main__":
    main()
