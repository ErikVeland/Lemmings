"""Compare selected native wins with independent published replay headers."""

import argparse
import json
from collections import Counter
from pathlib import Path


def identity_key(identity):
    return json.dumps(identity, sort_keys=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("fan_evidence", type=Path)
    parser.add_argument("solutions", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    rows = {
        identity_key(row["entry"]["identity"]): row
        for row in json.loads(args.fan_evidence.read_text())
        if row["profile"]["confidence"] != "low"
    }
    solutions = json.loads(args.solutions.read_text())
    comparisons = {}
    for source in json.loads(args.manifest.read_text()):
        row = rows.get(identity_key(source["identity"]))
        if row is None:
            continue
        replay_sha = row["profile"]["key"]["replayRevision"]
        selected = solutions.get(replay_sha)
        if selected is None or not selected["expected"]["didWin"]:
            continue
        published = json.loads(Path(source["candidate"]).read_text())
        if published["events"] != selected["events"]:
            continue
        key = (identity_key(source["identity"]), source["sourceReplaySHA256"])
        outcome = selected["expected"]
        comparisons[key] = {
            "identity": source["identity"],
            "levelSourceRevision": row["entry"]["sourceRevision"],
            "publishedReplayURL": source["url"],
            "publishedReplaySHA256": source["sourceReplaySHA256"],
            "sourceGameMode": source["gameMode"],
            "nativeReplaySHA256": replay_sha.removeprefix("SHA256 digest: "),
            "publishedSaved": source["sourceSaved"],
            "nativeSaved": outcome["saved"],
            "publishedHeaderTicks": source["sourceTicks"],
            "nativeCompletionTicks": outcome["ticks"],
        }
    records = [comparisons[key] for key in sorted(comparisons)]
    distinct = {identity_key(record["identity"]) for record in records}
    counts = Counter()
    for record in records:
        counts["sameSaved" if record["publishedSaved"] == record["nativeSaved"]
               else "differentSaved"] += 1
        counts["sameTicks" if record["publishedHeaderTicks"] == record["nativeCompletionTicks"]
               else "differentTicks"] += 1
    report = {
        "comparison": "Published replay header versus selected exact-input native winning replay",
        "limits": "Saved and tick counts are outcome checks, not full physics or terrain parity.",
        "sourceReplays": len(records),
        "distinctLevels": len(distinct),
        "counts": dict(counts),
        "records": records,
    }
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(f"Compared {len(records)} source replays on {len(distinct)} levels: "
          f"{counts['sameSaved']} matched saved counts, {counts['differentSaved']} differed.")


if __name__ == "__main__":
    main()
