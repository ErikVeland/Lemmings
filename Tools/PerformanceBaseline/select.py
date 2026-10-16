#!/usr/bin/env python3
"""Select deterministic corpus cases. Selection never uses measured speed."""
import argparse
import json
from pathlib import Path
import re
import statistics
from snapshot import seal_assets


def select(source, assets, output):
    cases = []
    replays = {}
    for path in [assets / "resources/Hints/solutions.json",
                 assets / "resources/Progression/solutions.json",
                 assets / "candidate-solutions.json"]:
        if path.exists():
            for replay in json.loads(path.read_text()).values():
                if isinstance(replay, dict) and replay.get("expected", {}).get("didWin"):
                    replays[replay["initialStateHash"]] = replay
    rows = [json.loads(line) for line in (source / "Documentation/ReleaseReadiness/2.0-build83/classic-fan-build83-replay-levels.jsonl").read_text().splitlines()]
    eligible = [row for row in rows if row["collection"] == "fan" and row.get("initialHash") in replays]

    def destruction(row):
        return sum(event["action"].get("assign", {}).get("skill") in {"bomber", "basher", "miner", "digger"}
                   for event in replays[row["initialHash"]]["events"])

    median = statistics.median(replays[row["initialHash"]]["expected"]["ticks"] for row in eligible)
    selected = [
        ("typical", min(eligible, key=lambda row: (abs(replays[row["initialHash"]]["expected"]["ticks"] - median), row["source"]))),
        ("population", max(eligible, key=lambda row: (replays[row["initialHash"]]["expected"]["released"], row["source"]))),
        ("destruction", max(eligible, key=lambda row: (destruction(row), row["source"]))),
    ]
    (assets / "selected-replays").mkdir(exist_ok=True)
    for purpose, row in selected:
        replay_path = f"selected-replays/classic-{purpose}.json"
        (assets / replay_path).write_text(json.dumps(replays[row["initialHash"]], sort_keys=True) + "\n")
        cases.append(dict(id=f"classic-{purpose}", engine="classic", purpose=purpose,
                          level=row["source"], replay=replay_path, initialHash=row["initialHash"]))

    neo = []
    for path in sorted((assets / "neo/levels").rglob("*.nxlv")):
        text = path.read_text(encoding="utf-8-sig")
        def number(key, default):
            match = re.search(rf"^{key}\s+(\d+)\s*$", text, re.MULTILINE | re.IGNORECASE)
            return int(match[1]) if match else default
        neo.append((path, number("WIDTH", 320) * number("HEIGHT", 160), number("LEMMINGS", 1)))
    ordered = sorted(neo, key=lambda row: (row[1], row[0]))
    for purpose, row in [("typical", ordered[len(ordered) // 2]),
                         ("largest", max(neo, key=lambda row: (row[1], row[0]))),
                         ("population", max(neo, key=lambda row: (row[2], row[0]))),
                         ("scripted-nuke", max(neo, key=lambda row: (row[2], row[0])))]:
        cases.append(dict(id=f"neo-{purpose}", engine="neo", purpose=purpose,
                          level=str(row[0].relative_to(assets / "neo/levels")), replay=None, initialHash=None))

    for engine, folder in [("l2", "Tests/Lemmings2CompletionTests/Fixtures"),
                            ("l3", "Tests/Lemmings3CompletionTests/Fixtures")]:
        fixtures = [(path, json.loads(path.read_text())) for path in sorted((source / folder).glob("*.json"))]
        def ticks(row):
            return row[1]["expectedTicks"] if engine == "l2" else row[1]["expected"]["ticks"]
        def commands(row):
            return len(row[1].get("events") or row[1].get("inputs", []))
        median = statistics.median(ticks(row) for row in fixtures)
        selected = [("typical", min(fixtures, key=lambda row: (abs(ticks(row) - median), row[0]))),
                    ("commands", max(fixtures, key=lambda row: (commands(row), row[0]))),
                    ("longest", max(fixtures, key=lambda row: (ticks(row), row[0])))]
        if engine == "l3":
            def area(row):
                path = assets / f'resources/Ports/LEM3CD/LEVELS/LEVEL{row[1]["level"]:03d}.DAT'
                data = path.read_bytes()
                return int.from_bytes(data[12:14], "little") * int.from_bytes(data[14:16], "little")
            selected.append(("largest", max(fixtures, key=lambda row: (area(row), row[0]))))
        for purpose, row in selected:
            cases.append(dict(id=f"{engine}-{purpose}", engine=engine, purpose=purpose,
                              level=row[0].stem, replay=str(row[0].relative_to(source)), initialHash=None))
    output.write_text(json.dumps(cases, indent=2) + "\n")
    manifest = assets.parent / "assets-manifest.json"
    origins = json.loads(manifest.read_text())["origins"]
    seal_assets(assets, manifest, origins)
    print(f"Selected {len(cases)} cases from {len(eligible)} Classic replay rows, {len(neo)} NeoLemmix levels, 120 L2 and 90 L3 route fixtures")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("assets", type=Path)
    parser.add_argument("output", type=Path)
    options = parser.parse_args()
    select(options.source, options.assets, options.output)
