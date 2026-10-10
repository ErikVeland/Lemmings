"""Check the retimed native witness against its archived Golems source replay."""

import hashlib
import json
from pathlib import Path

from decode_golems_replays import decode, source_bytes


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "Artifacts/DifficultyEvaluation"
CACHE = ROOT / ".build/learning-evidence"


def read(path):
    return json.loads(path.read_text())


def main():
    records = read(EVIDENCE / "classic-golems-late-timing-recovery.json")["records"]
    assert len(records) == 1
    record = records[0]
    archive = ROOT / "Content/LevelPacks/0193-Gronklems-0.zip"
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == record["bundledArchiveSHA256"]
    manifest = read(CACHE / "lldb-all-records/manifest.json")
    source = [item for item in manifest if item["identity"] == record["identity"]
              and item["sourceReplaySHA256"] == record["sourceReplaySHA256"]]
    assert len(source) == 1
    assert (source[0]["url"], source[0]["sourceSaved"], source[0]["sourceTicks"]) == (
        record["sourceURL"], record["sourceHeaderSaved"], record["sourceHeaderTicks"])
    raw = source_bytes(CACHE / "lldb-next500/193-3.html", source[0]["recordIndex"])
    assert hashlib.sha256(raw).hexdigest() == record["sourceReplaySHA256"]
    converted = decode(raw, native_tick_offset=-1)
    assert [event["tick"] for event in converted] == record["convertedSourceTicksMinusOne"]
    replay_data = (ROOT / record["replayPath"]).read_bytes()
    assert hashlib.sha256(replay_data).hexdigest() == record["nativeReplaySHA256"]
    replay = json.loads(replay_data)
    assert len(replay["events"]) == len(converted) == len(record["nativeTickOffsetsFromConvertedSource"])
    for source_event, native_event, offset in zip(
            converted, replay["events"], record["nativeTickOffsetsFromConvertedSource"]):
        assert source_event["action"] == native_event["action"]
        assert source_event["afterTick"] == native_event["afterTick"]
        assert native_event["tick"] == source_event["tick"] + offset
    assert replay["sourceRules"] == record["sourceRules"]
    assert replay["initialStateHash"] == record["initialStateHash"]
    assert replay["expected"]["didWin"]
    assert (replay["expected"]["saved"], replay["expected"]["required"],
            replay["expected"]["ticks"]) == (
                record["nativeSaved"], record["required"], record["nativeCompletionTick"])
    print("Verified exact archive, source bytes, all nine retimed commands and native replay digest")


if __name__ == "__main__":
    main()
