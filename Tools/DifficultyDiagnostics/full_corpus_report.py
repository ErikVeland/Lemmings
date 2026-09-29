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
BUNDLED_FAN_PACKS = ROOT / "Content/LevelPacks"
NEO = ROOT / ".build/full-difficulty-evaluation/neolemmix/profiles.json"
NEO_REPORT = ROOT / ".build/full-difficulty-evaluation/neolemmix/report.json"
PASSIVE = ROOT / ".build/neolemmix-passive-evaluation/results.json"
OUTPUT = ROOT / "Artifacts/DifficultyEvaluation"
PARTIAL_SOURCE_ASSIGNMENTS = {
    "NeoLemmix_Introduction_Pack/Advanced_Training/Beam_Up_The_Equipment!.nxlv":
        ("aa256c48ee1bb20077d0b22b7ccfee6ed4b6835467422fc318e0770c2bdcac7d", 5),
    "NeoLemmix_Introduction_Pack/Advanced_Training/Curse_Of_The_Gold.nxlv":
        ("437ad8f26c6a13ad6f7f83ec26e138c64be10be8d2f3d9f7ad0a54455e82106e", 11),
    "NeoLemmix_Introduction_Pack/Basic_Training_2/Counterclockwise.nxlv":
        ("2acdf4bf8dd221d1cc9b3287f38eda854e1f58522c6aaf54b274ae16f7099c67", 16),
}


def read(path):
    return json.loads(path.read_text())


def identity(row):
    return json.dumps(row["entry"]["identity"], sort_keys=True)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    classic = {identity(row): row for row in read(CLASSIC)}
    classic.update({identity(row): row for row in read(FAN)})
    bundled_pack_revisions = {
        "fan:lldb-" + str(int(prefix)): digest(path)
        for path in BUNDLED_FAN_PACKS.glob("*.zip")
        if (prefix := path.name.split("-", 1)[0]).isdigit()
    }
    manifest_pack_ids = {
        "fan:lldb-" + str(pack["id"])
        for pack in read(BUNDLED_FAN_PACKS / "packs.json")
    }
    assert bundled_pack_revisions.keys() == manifest_pack_ids
    fan = [
        row for row in classic.values()
        if not row["official"]
        and row["entry"]["identity"]["packID"] in bundled_pack_revisions
    ]
    assert all(
        row["entry"]["sourceRevision"]
        == bundled_pack_revisions[row["entry"]["identity"]["packID"]]
        for row in fan
    )
    neo = read(NEO)
    neo_failures = {}
    for failure in read(NEO_REPORT)["failures"]:
        path, _, reason = failure.partition(": ")
        neo_failures[path] = reason
    passive = {row["path"]: row for row in read(PASSIVE)} if PASSIVE.exists() else {}
    assert len(fan) == 6020, len(fan)
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
                     "replay_sha256": profile["key"]["replayRevision"].rsplit(" ", 1)[-1]
                     if verified else "",
                     "completion": "verified win" if verified else "no verified win",
                     "physics_parity": "not independently checked",
                     "playtest": "replay verified" if verified else "bounded search or metadata only",
                     "issue": row.get("issue") or ""})
    for profile in neo:
        path = profile["key"]["identity"]["levelID"]
        run = passive.get(path, {})
        status = run.get("status", "not run")
        score = run.get("score") or profile["overallScore"]
        replay_win = profile["confidence"] != "low"
        passive_win = status == "passive-win" and run.get("score") is not None
        source_compatible = profile["key"]["replayRevision"].endswith(":source-compatible")
        replay_digest = profile["key"]["replayRevision"].split(":", 1)[0]
        partial_match = PARTIAL_SOURCE_ASSIGNMENTS.get(path)
        parity = (
            f"partial source assignment match ({partial_match[1]}/{partial_match[1]})"
            if replay_win and partial_match and replay_digest == partial_match[0]
            else "not independently checked"
        )
        rows.append({"source": "NeoLemmix", "pack": path.split("/", 1)[0],
                     "level": path, "title": path.rsplit("/", 1)[-1].removesuffix(".nxlv"),
                     "score": round(score, 2),
                     "confidence": "high" if passive_win else profile["confidence"],
                     "replay_sha256": replay_digest
                     if replay_win else "",
                     "completion": "verified win" if replay_win or passive_win else "no verified win",
                     "physics_parity": parity,
                     "playtest": ("source-compatible replay verified" if source_compatible else "replay verified")
                     if replay_win else "replay analysis failed" if path in neo_failures else status,
                     "issue": neo_failures.get(path) or ", ".join(run.get("features", []))
                     or run.get("issue", "")})
    rows.sort(key=lambda row: (row["source"], row["pack"], row["level"]))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with (OUTPUT / "levels.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    sources = {str(path.relative_to(ROOT)): digest(path) for path in (CLASSIC, FAN, NEO, NEO_REPORT)}
    pack_manifest = BUNDLED_FAN_PACKS / "packs.json"
    sources[str(pack_manifest.relative_to(ROOT))] = digest(pack_manifest)
    if PASSIVE.exists():
        sources[str(PASSIVE.relative_to(ROOT))] = digest(PASSIVE)
    counts = Counter((row["source"], row["completion"]) for row in rows)
    unverified_official_conversions = sum(
        row["completion"] == "no verified win" and row["pack"] == "Original_Lemmings"
        for row in rows
    )
    unverified_non_official = sum(
        row["completion"] == "no verified win" and row["pack"] != "Original_Lemmings"
        for row in rows
    )
    summary = {"generatedAt": datetime.now(timezone.utc).isoformat(),
               "sourceDigests": sources, "levels": len(rows), "fanLevels": len(fan),
               "neoLemmixLevels": len(neo), "neoPassiveRuns": len(passive),
               "neoReplayAnalysisFailures": len(neo_failures),
               "verifiedFanWins": counts[("Classic fan", "verified win")],
               "unverifiedFan": counts[("Classic fan", "no verified win")],
               "verifiedNeoLemmixWins": counts[("NeoLemmix", "verified win")],
               "unverifiedNeoLemmix": counts[("NeoLemmix", "no verified win")],
               "unverifiedNonOfficial": unverified_non_official,
               "unverifiedOfficialConversions": unverified_official_conversions,
               "independentPhysicsParityVerified": 0,
               "partialSourceAssignmentMatches": sum(
                   row["physics_parity"].startswith("partial source assignment match")
                   for row in rows
               ),
               "neoPlaytestStatuses": dict(Counter(row["playtest"] for row in rows if row["source"] == "NeoLemmix"))}
    (OUTPUT / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    (OUTPUT / "README.md").write_text(
        "# Difficulty evaluation\n\n"
        f"This ledger covers {len(fan)} bundled Classic fan levels and {len(neo)} bundled NeoLemmix levels. "
        "Every row has a difficulty score. A low-confidence score is a metadata estimate, not a completed playtest.\n\n"
        f"Verified winning replays support {summary['verifiedFanWins']} Classic fan scores and "
        f"{summary['verifiedNeoLemmixWins']} NeoLemmix scores. "
        f"The remaining {summary['unverifiedNonOfficial']} non-official scores and "
        f"{summary['unverifiedOfficialConversions']} official conversion scores need a verified win.\n\n"
        "The `playtest` column records the latest check. A passive loss or timeout only describes a run "
        "without player input. It does not prove that the level is impossible. "
        "Source-compatible replays can have an absent or different level version; their native wins are valid, but source parity is unverified.\n\n"
        "The `issue` column records a replay-analysis failure where one occurred. Such rows keep their "
        "metadata score and do not count as verified wins.\n\n"
        "A native win shows that this engine can complete the level. It does not independently prove "
        "physics parity with the source engine. The `physics_parity` column records partial "
        "assignment-state matches where checked and keeps the full parity gate separate.\n\n"
        "Third-party replay archives and community styles remain in the ignored local build folder. "
        "The repository does not redistribute them. See `summary.json` for source digests.\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
