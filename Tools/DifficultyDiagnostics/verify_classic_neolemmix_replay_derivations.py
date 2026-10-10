"""Verify published NeoLemmix inputs used for bundled Classic fan wins."""

import hashlib
import json
import re
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "Artifacts/DifficultyEvaluation/classic-neolemmix-replay-derivations.json"
SOURCE = ROOT / ".build/full-difficulty-evaluation/LemmingsPlusI_Replays_V12.10-A.zip"


def read(path):
    return json.loads(path.read_text())


def identity(row):
    value = row["entry"]["identity"]
    return value["packID"], value["levelID"]


def fields(text):
    return {key: value.strip() for key, value in re.findall(r"^\s*([A-Z_]+) (.*)$", text, re.M)}


def source_events(text):
    result = []
    for kind, body in re.findall(r"^\$(ASSIGNMENT|SPAWN_INTERVAL|NUKE)\s*\n(.*?)^\$END", text, re.M | re.S):
        data = fields(body)
        if kind == "ASSIGNMENT":
            action = {"assign": {"lemmingID": int(data["LEM_INDEX"]), "skill": data["ACTION"].lower()}}
        elif kind == "SPAWN_INTERVAL":
            interval = int(data["RATE"])
            assert 4 <= interval <= 53
            action = {"releaseRate": {"_0": 107 - 2 * interval}}
        else:
            action = {"nuke": {}}
        result.append({"tick": int(data["FRAME"]), "action": action, "afterTick": True})
    result.sort(key=lambda item: item["tick"])
    return result


def swift_replay_bytes(replay):
    encoded = json.dumps(replay, indent=2, separators=(",", " : "),
                         sort_keys=True, ensure_ascii=False)
    encoded = re.sub(r'(?m)^([ \t]*)"nuke" : \{\}$',
                     lambda match: match.group(1) + '"nuke" : {\n\n' + match.group(1) + '}', encoded)
    return encoded.encode()


def main():
    evidence = read(EVIDENCE)
    rows = {identity(row): row for row in read(ROOT / "Artifacts/LearningJourney/fan-evidence.json")}
    solutions = read(ROOT / "Artifacts/LearningJourney/candidate-solutions.json")
    archive = zipfile.ZipFile(SOURCE) if SOURCE.exists() else None
    if archive:
        assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == evidence["sourceArchiveSHA256"]
    seen = set()
    for record in evidence["records"]:
        value = record["identity"]
        key = value["packID"], value["levelID"]
        assert key not in seen and key in rows
        seen.add(key)
        row = rows[key]
        assert row["entry"]["sourceRevision"] == record["levelSourceRevision"]
        assert row["initialHash"] == record["initialStateHash"]
        assert row["profile"]["overallScore"] == record["replayBasedScore"]
        pack_number = int(value["packID"].split("-")[-1])
        packs = list((ROOT / "Content/LevelPacks").glob(f"{pack_number:04d}-*.zip"))
        assert len(packs) == 1
        assert hashlib.sha256(packs[0].read_bytes()).hexdigest() == record["levelSourceRevision"]
        revision = "SHA256 digest: " + record["nativeReplaySHA256"]
        assert row["profile"]["key"]["replayRevision"] == revision
        replay = solutions[revision]
        encoded = swift_replay_bytes(replay)
        assert hashlib.sha256(encoded).hexdigest() == record["nativeReplaySHA256"]
        assert replay["rank"] == key[0] and replay["initialStateHash"] == row["initialHash"]
        assert replay["expected"]["didWin"]
        assert replay["expected"]["saved"] == record["nativeSaved"]
        assert replay["expected"]["required"] == record["requiredToSave"]
        assert replay["expected"]["ticks"] == record["nativeCompletionTicks"]
        if archive:
            raw = archive.read(record["sourceReplayName"])
            assert hashlib.sha256(raw).hexdigest() == record["sourceReplaySHA256"]
            text = raw.decode("latin1")
            header = fields(text.split("$", 1)[0])
            ranks = {"Mild": "fan:lldb-551", "Wimpy": "fan:lldb-552",
                     "Medi": "fan:lldb-553", "Danger": "fan:lldb-554",
                     "PSYCHO": "fan:lldb-555"}
            assert ranks[header["RANK"]] == key[0]
            normalise = lambda item: re.sub(r"[^a-z0-9]", "", item.lower())
            assert normalise(header["TITLE"]) == normalise(row["entry"]["levelNameSnapshot"])
            events = source_events(text)
            if "adjustedEventIndex" in record:
                index = record["adjustedEventIndex"]
                assert events[index]["tick"] == record["sourceTick"]
                events[index]["tick"] = record["nativeTick"]
                events.sort(key=lambda item: item["tick"])
            assert events == replay["events"]
    suffix = "including source bytes" if archive else "without the optional source archive"
    print(f"Verified {len(seen)} NeoLemmix-to-Classic replay derivations {suffix}.")


if __name__ == "__main__":
    main()
