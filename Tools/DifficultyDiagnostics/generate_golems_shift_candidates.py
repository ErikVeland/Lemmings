"""Generate bounded native replay timing candidates from decoded Golems routes."""

import argparse
import copy
import json
from pathlib import Path


def identity(row):
    item = row.get("identity", row.get("entry", {}).get("identity"))
    return item["packID"], item["levelID"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("audit", type=Path)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--minimum", type=int, required=True)
    parser.add_argument("--maximum", type=int, required=True)
    args = parser.parse_args()
    if not 1 <= args.minimum <= args.maximum:
        parser.error("require 1 <= minimum <= maximum")

    verified = {
        identity(row) for row in json.loads(args.evidence.read_text())
        if row["profile"]["confidence"] != "low"
    }
    limits = args.evidence.parent.parent / "DifficultyEvaluation/classic-structural-limits.json"
    impossible = {identity(row) for row in json.loads(limits.read_text())["records"]}
    audit = {
        identity(row): row for row in json.loads(args.audit.read_text())
        if identity(row) not in verified and identity(row) not in impossible
    }
    args.output.mkdir(parents=True, exist_ok=True)
    selected = set()
    candidates = []
    for source in json.loads(args.manifest.read_text()):
        key = identity(source)
        if key not in audit:
            continue
        original = json.loads(Path(source["candidate"]).read_text())
        if not original["events"]:
            continue
        initial_hash = audit[key]["initialHash"]
        if original["initialStateHash"] != initial_hash:
            raise ValueError(f"source route has a different initial state: {key}")
        selected.add(key)
        for distance in range(args.minimum, args.maximum + 1):
            for shift in (-distance, distance):
                if any(event["tick"] + shift < 0 for event in original["events"]):
                    continue
                replay = copy.deepcopy(original)
                for event in replay["events"]:
                    event["tick"] += shift
                name = f"{initial_hash}-{source['sourceReplaySHA256']}-global{'m' if shift < 0 else 'p'}{abs(shift)}.json"
                (args.output / name).write_text(json.dumps(replay, indent=2) + "\n")
                candidates.append({"identity": source["identity"], "source": source, "shift": shift,
                                   "candidate": str(args.output / name)})
    (args.output.parent / "shift-manifest.json").write_text(json.dumps(candidates, indent=2) + "\n")
    (args.output.parent / "input-audit.json").write_text(
        json.dumps([audit[key] for key in sorted(selected)], indent=2) + "\n"
    )
    print(f"Prepared {len(candidates)} replay candidates for {len(selected)} unverified levels.")


if __name__ == "__main__":
    main()
