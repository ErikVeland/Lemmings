"""Combine Classic and NeoLemmix scores with explicit completion evidence."""

import csv
import hashlib
import json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CLASSIC = ROOT / "Artifacts/ClassicProgression/audit.json"
FAN = ROOT / "Artifacts/LearningJourney/fan-evidence.json"
NEO = ROOT / ".build/full-difficulty-evaluation/neolemmix/profiles.json"
PASSIVE = ROOT / ".build/neolemmix-passive-evaluation/results.json"
OUTPUT = ROOT / "Artifacts/DifficultyEvaluation"


def read(path):
    return json.loads(path.read_text())


def identity(row):
    return json.dumps(row["entry"]["identity"], sort_keys=True)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    classic = {identity(row): row for row in read(CLASSIC)}
    classic.update({identity(row): row for row in read(FAN)})
    fan = [row for row in classic.values() if not row["official"]]
    neo = read(NEO)
    passive = {row["path"]: row for row in read(PASSIVE)} if PASSIVE.exists() else {}
    assert len(fan) == 6022, len(fan)
    assert len(neo) == 794, len(neo)
    rows = []
    for row in fan:
        profile = row["profile"]
        verified = profile["confidence"] != "low"
        rows.append({"source": "Classic fan", "pack": row["entry"]["identity"]["packID"],
                     "level": row["entry"]["identity"]["levelID"],
                     "title": row["entry"]["levelNameSnapshot"],
                     "score": round(profile["overallScore"], 2),
                     "confidence": profile["confidence"],
                     "completion": "verified win" if verified else "no verified win",
                     "playtest": "replay verified" if verified else "bounded search or metadata only",
                     "issue": row.get("issue") or ""})
    for profile in neo:
        path = profile["key"]["identity"]["levelID"]
        run = passive.get(path, {})
        status = run.get("status", "not run")
        score = run.get("score") or profile["overallScore"]
        rows.append({"source": "NeoLemmix", "pack": path.split("/", 1)[0],
                     "level": path, "title": path.rsplit("/", 1)[-1].removesuffix(".nxlv"),
                     "score": round(score, 2),
                     "confidence": "high" if status == "passive-win" and run.get("score") is not None else profile["confidence"],
                     "completion": "verified win" if status == "passive-win" and run.get("score") is not None else "no verified win",
                     "playtest": status,
                     "issue": ", ".join(run.get("features", [])) or run.get("issue", "")})
    rows.sort(key=lambda row: (row["source"], row["pack"], row["level"]))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with (OUTPUT / "levels.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    sources = {str(path.relative_to(ROOT)): digest(path) for path in (CLASSIC, FAN, NEO)}
    if PASSIVE.exists():
        sources[str(PASSIVE.relative_to(ROOT))] = digest(PASSIVE)
    counts = Counter((row["source"], row["completion"]) for row in rows)
    summary = {"generatedAt": datetime.now(timezone.utc).isoformat(),
               "sourceDigests": sources, "levels": len(rows), "fanLevels": len(fan),
               "neoLemmixLevels": len(neo), "neoPassiveRuns": len(passive),
               "verifiedFanWins": counts[("Classic fan", "verified win")],
               "unverifiedFan": counts[("Classic fan", "no verified win")],
               "verifiedNeoLemmixWins": counts[("NeoLemmix", "verified win")],
               "unverifiedNeoLemmix": counts[("NeoLemmix", "no verified win")],
               "neoPlaytestStatuses": dict(Counter(row["playtest"] for row in rows if row["source"] == "NeoLemmix"))}
    (OUTPUT / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    (OUTPUT / "README.md").write_text(
        "# Difficulty evaluation\n\n"
        f"This ledger covers {len(fan)} bundled Classic fan levels and {len(neo)} bundled NeoLemmix levels. "
        "Every row has a difficulty score. A low-confidence score is a metadata estimate, not a completed playtest.\n\n"
        f"Verified winning replays support {summary['verifiedFanWins']} Classic fan scores and "
        f"{summary['verifiedNeoLemmixWins']} NeoLemmix scores. "
        f"The remaining {summary['unverifiedFan'] + summary['unverifiedNeoLemmix']} scores need a verified win.\n\n"
        "The `playtest` column records the latest check. A passive loss or timeout only describes a run "
        "without player input. It does not prove that the level is impossible. See `summary.json` for source digests.\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
