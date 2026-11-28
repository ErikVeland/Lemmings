"""Generate the Classic Easy puzzles catalogue from existing replay evidence."""

import argparse
import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS = ROOT / "Artifacts/LearningJourney"
PROGRESSION = ROOT / "Resources/Progression"
OUTPUT = PROGRESSION / "easy-puzzles.json"
BASIC_SKILLS = {"basher", "blocker", "bomber", "builder", "climber", "digger", "floater", "miner"}
COMPETITIVE_PACKS = {404, 405, 572, 582, 583}


def read(path):
    return json.loads(path.read_text())


def identity(entry):
    value = entry["identity"]
    return (value["packID"], value["levelID"])


def normalized(name):
    return "".join(character for character in name.casefold() if character.isalnum())


def build():
    audit = read(ROOT / "Artifacts/ClassicProgression/audit.json")
    lessons = read(PROGRESSION / "learning.json")["lessons"]
    exact_wins = {
        identity(row): row
        for row in read(ARTIFACTS / "native-replay-validation.json") if row["passed"]
    }
    official_states = {row["initialHash"] for row in audit if row["official"]}
    official_titles = {normalized(row["entry"]["levelNameSnapshot"]) for row in audit if row["official"]}
    witnesses = read(ARTIFACTS / "candidate-solutions.json")
    excluded = {identity(row) for row in read(PROGRESSION / "exclusions.json")}
    result = []
    for lesson in lessons[:47]:
        entry = lesson["entry"]
        evidence = exact_wins.get(identity(entry))
        skills = sorted(set(lesson["concepts"]) & BASIC_SKILLS)
        if (evidence and evidence["sourceRevision"] == entry["sourceRevision"] and identity(entry) not in excluded
                and 0 < len(skills) <= 2 and evidence["firstQuotaTick"] <= 2600
                and all(evidence["toolsRemainingAtQuota"].get(skill, 0) > 0 for skill in skills)):
            result.append({"entry": entry, "score": min(170, round(lesson["score"])), "skills": skills})

    fan = sorted(read(ARTIFACTS / "fan-evidence.json"),
                 key=lambda row: (row["profile"]["overallScore"], identity(row["entry"])))
    occupied = {identity(row["entry"]) for row in result}
    seen_states = set(official_states)
    seen_titles = official_titles | {normalized(row["entry"]["levelNameSnapshot"]) for row in result}
    pack_counts = Counter()
    for row in fan:
        entry, profile = row["entry"], row["profile"]
        pack, _ = identity(entry)
        title = normalized(entry["levelNameSnapshot"])
        if (not row["playable"] or identity(entry) in occupied or identity(entry) in excluded
                or row["initialHash"] in seen_states or title in seen_titles
                or not pack.startswith("fan:lldb-") or int(pack.removeprefix("fan:lldb-")) in COMPETITIVE_PACKS
                or pack_counts[pack] >= 3):
            continue
        witness = witnesses.get(profile["key"]["replayRevision"])
        precision = profile.get("precision")
        skills, score = set(profile["detectedTechniques"]), profile["overallScore"]
        if not witness or not precision or not 0 < score < 185 or not 0 < len(skills) <= 2 or not skills <= BASIC_SKILLS:
            continue
        expected, events = witness["expected"], witness["events"]
        assignments = [event for event in events if "assign" in event["action"]]
        if (witness["initialStateHash"] != row["initialHash"] or not expected["didWin"]
                or not 0 < expected["required"] <= expected["saved"] or expected["ticks"] > 3500
                or not 1 <= len(assignments) <= 10 or len(events) - len(assignments) > 10
                or any(set(event["action"]) - {"assign", "releaseRate"} for event in events)):
            continue
        pressure = profile["components"]
        if (pressure["executionPrecision"] > 120 or pressure["constraintPressure"] > 430
                or pressure["concurrencyBurden"] > 220 or not precision["actions"]):
            continue
        if any(not any(won for offset, won in action["outcomes"].items() if abs(int(offset)) >= 4)
               for action in precision["actions"] if any(abs(int(offset)) >= 4 for offset in action["outcomes"])):
            continue
        result.append({"entry": entry, "score": round(score), "skills": sorted(skills)})
        occupied.add(identity(entry))
        seen_states.add(row["initialHash"])
        seen_titles.add(title)
        pack_counts[pack] += 1
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rows = build()
    rendered = json.dumps(rows, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    if args.check:
        if OUTPUT.read_text() != rendered:
            raise SystemExit("The Easy puzzles catalogue is out of date.")
    else:
        OUTPUT.write_text(rendered)
    packs = {identity(row["entry"])[0] for row in rows}
    fan_count = sum(identity(row["entry"])[0].startswith("fan:") for row in rows)
    print(f"{len(rows)} puzzles, including {fan_count} fan levels, across {len(packs)} packs")


if __name__ == "__main__":
    main()
