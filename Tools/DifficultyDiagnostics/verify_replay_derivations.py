"""Check native replay edits against the downloaded source archive and ledger."""

import csv
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "Artifacts/DifficultyEvaluation"
ARCHIVE = ROOT / ".build/full-difficulty-evaluation/intro-2022-19608.rar"
EXTRACTED = ROOT / ".build/full-difficulty-evaluation/intro-2022-19608"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def main():
    records = json.loads((EVIDENCE / "replay-derivations.json").read_text())
    with (EVIDENCE / "levels.csv").open(newline="") as stream:
        ledger = {row["level"]: row for row in csv.DictReader(stream)}
    archive_digest = sha256(ARCHIVE.read_bytes())
    for record in records:
        assert archive_digest == record["source_archive_sha256"]
        relative = Path(record["source_path"])
        assert not relative.is_absolute() and ".." not in relative.parts
        replay = (EXTRACTED / relative).read_bytes()
        assert sha256(replay) == record["source_replay_sha256"]
        for edit in record["edits"]:
            old, new = edit["from"].encode(), edit["to"].encode()
            assert replay.count(old) == edit["expected_occurrences"]
            replay = replay.replace(old, new)
        assert sha256(replay) == record["native_replay_sha256"]
        assert ledger[record["level"]]["completion"] == "verified win"
        assert ledger[record["level"]]["replay_sha256"] == record["native_replay_sha256"]
    print(f"Verified {len(records)} replay derivations and ledger digests.")


if __name__ == "__main__":
    main()
