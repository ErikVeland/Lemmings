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
STRUCTURAL = ROOT / "Artifacts/DifficultyEvaluation/classic-structural-limits.json"
GOLEMS_OBJECTS = ROOT / "Artifacts/DifficultyEvaluation/classic-golems-object-comparisons.json"
GOLEMS_ALTERNATIVES = ROOT / "Artifacts/DifficultyEvaluation/classic-golems-alternative-evidence.json"
GOLEMS_ALTERNATIVE_SOLUTIONS = ROOT / "Artifacts/DifficultyEvaluation/classic-golems-alternative-solutions.json"
SOURCE_OUTCOMES = ROOT / "Artifacts/DifficultyEvaluation/classic-source-outcomes.json"
CLASSIC_NEO_DERIVATIONS = ROOT / "Artifacts/DifficultyEvaluation/classic-neolemmix-replay-derivations.json"
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
    structural_records = read(STRUCTURAL)["records"] if STRUCTURAL.exists() else []
    structural = {
        (record["identity"]["packID"], record["identity"]["levelID"]): record
        for record in structural_records
    }
    assert len(structural) == len(structural_records)
    golems_records = read(GOLEMS_OBJECTS) if GOLEMS_OBJECTS.exists() else []
    golems_objects = {
        (record["identity"]["packID"], record["identity"]["levelID"]): record
        for record in golems_records
    }
    assert len(golems_objects) == len(golems_records)
    golems_alternative_records = read(GOLEMS_ALTERNATIVES) if GOLEMS_ALTERNATIVES.exists() else []
    golems_alternatives = {
        (record["entry"]["identity"]["packID"], record["entry"]["identity"]["levelID"]): record
        for record in golems_alternative_records
    }
    assert len(golems_alternatives) == len(golems_alternative_records)
    source_outcome_records = read(SOURCE_OUTCOMES)["records"] if SOURCE_OUTCOMES.exists() else []
    source_outcomes = {
        (record["identity"]["packID"], record["identity"]["levelID"]): record
        for record in source_outcome_records
    }
    assert len(source_outcomes) == len(source_outcome_records)
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
        level_id = row["entry"]["identity"]
        limit = structural.get((level_id["packID"], level_id["levelID"]))
        object_comparison = golems_objects.get((level_id["packID"], level_id["levelID"]))
        object_alternative = golems_alternatives.get((level_id["packID"], level_id["levelID"]))
        source_outcome = source_outcomes.get((level_id["packID"], level_id["levelID"]))
        if source_outcome:
            assert verified
            assert source_outcome["levelSourceRevision"] == row["entry"]["sourceRevision"]
        if object_comparison:
            assert verified
            assert object_comparison["sourceRevision"] == row["entry"]["sourceRevision"]
            assert object_comparison["replayRevision"] == profile["key"]["replayRevision"]
            assert object_comparison["nativeInitialHash"] == row["initialHash"]
        object_route_differs = object_comparison and (
            object_comparison.get("golemsSaved") != object_comparison["nativeSaved"]
            or object_comparison.get("golemsTicks") != object_comparison["nativeTicks"]
        )
        parity_observations = []
        if object_route_differs:
            parity_observations.append("Golems object-rule replay differs")
        if object_alternative:
            assert object_route_differs and object_alternative["entry"]["sourceRevision"] == row["entry"]["sourceRevision"]
            parity_observations.append("alternate Golems object-rule replay verified")
        if source_outcome and source_outcome["nativeSaved"] != source_outcome["publishedSaved"]:
            parity_observations.append("published replay saved header differs")
        if source_outcome and abs(
            source_outcome["nativeCompletionTicks"] - source_outcome["publishedHeaderTicks"]
        ) > 5:
            parity_observations.append("published replay completion header differs by over 5 ticks")
        if limit:
            assert not verified and limit["levelSourceRevision"] == row["entry"]["sourceRevision"]
            assert limit["initialStateHash"] == row["initialHash"]
            if limit["reason"] == "no functional exit":
                assert limit["requiredToSave"] > 0 and limit["exitTriggerCount"] == 0
                assert not limit["exitObjectSlots"] or min(limit["exitObjectSlots"]) >= 16
            else:
                assert limit["reason"] == "rescue requirement exceeds population"
                assert limit["requiredToSave"] > limit["totalLemmings"]
        rows.append({"source": "Classic fan", "pack": row["entry"]["identity"]["packID"],
                     "level": row["entry"]["identity"]["levelID"],
                     "title": row["entry"]["levelNameSnapshot"],
                     "score": round(profile["overallScore"], 2) if verified else "",
                     "confidence": profile["confidence"],
                     "replay_sha256": profile["key"]["replayRevision"].rsplit(" ", 1)[-1]
                     if verified else "",
                     "completion": "verified win" if verified else "no verified win",
                     "physics_parity": "; ".join(parity_observations) if parity_observations
                     else "not independently checked",
                     "playtest": "replay verified" if verified else
                     limit["reason"] if limit else "bounded search or metadata only",
                     "issue": (f"Exit object in inactive slot(s) {', '.join(map(str, limit['exitObjectSlots']))}"
                               if limit["exitObjectSlots"] else "No exit object in the bundled level")
                     if limit and limit["reason"] == "no functional exit" else
                     f"Requires {limit['requiredToSave']} saves from {limit['totalLemmings']} lemmings"
                     if limit else row.get("issue") or ""})
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
                     "score": round(score, 2) if replay_win else "",
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
    if STRUCTURAL.exists():
        sources[str(STRUCTURAL.relative_to(ROOT))] = digest(STRUCTURAL)
    if GOLEMS_OBJECTS.exists():
        sources[str(GOLEMS_OBJECTS.relative_to(ROOT))] = digest(GOLEMS_OBJECTS)
    for path in (GOLEMS_ALTERNATIVES, GOLEMS_ALTERNATIVE_SOLUTIONS):
        if path.exists():
            sources[str(path.relative_to(ROOT))] = digest(path)
    if SOURCE_OUTCOMES.exists():
        sources[str(SOURCE_OUTCOMES.relative_to(ROOT))] = digest(SOURCE_OUTCOMES)
    classic_neo_derivations = read(CLASSIC_NEO_DERIVATIONS)["records"] if CLASSIC_NEO_DERIVATIONS.exists() else []
    if CLASSIC_NEO_DERIVATIONS.exists():
        sources[str(CLASSIC_NEO_DERIVATIONS.relative_to(ROOT))] = digest(CLASSIC_NEO_DERIVATIONS)
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
               "structuralNoExitFan": sum(record["reason"] == "no functional exit"
                                          for record in structural_records),
               "structuralExcessRequirementFan": sum(record["reason"] == "rescue requirement exceeds population"
                                                      for record in structural_records),
               "golemsObjectComparisons": len(golems_records),
               "golemsObjectReplayDifferences": sum(
                   record.get("golemsSaved") != record["nativeSaved"]
                   or record.get("golemsTicks") != record["nativeTicks"]
                   for record in golems_records),
               "golemsObjectLostWins": sum(not record["golemsDidWin"] for record in golems_records),
               "golemsObjectReplayErrors": sum(record.get("error") is not None
                                                 for record in golems_records),
               "golemsObjectAlternativeWins": len(golems_alternative_records),
               "classicNeoLemmixInputWins": len(classic_neo_derivations),
               "classicSourceOutcomeComparisons": len(source_outcome_records),
               "classicSourceOutcomeMatchesWithinFiveTicks": sum(
                   record["nativeSaved"] == record["publishedSaved"]
                   and abs(record["nativeCompletionTicks"] - record["publishedHeaderTicks"]) <= 5
                   for record in source_outcome_records),
               "classicSourceSavedHeaderDifferences": sum(
                   record["nativeSaved"] != record["publishedSaved"]
                   for record in source_outcome_records),
               "classicSourceCompletionHeaderOutliers": sum(
                   abs(record["nativeCompletionTicks"] - record["publishedHeaderTicks"]) > 5
                   for record in source_outcome_records),
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
        "A row has a difficulty score only when a winning replay supports it. "
        "Low-confidence metadata estimates remain outside the score column.\n\n"
        f"Verified winning replays support {summary['verifiedFanWins']} Classic fan scores and "
        f"{summary['verifiedNeoLemmixWins']} NeoLemmix scores. "
        f"The remaining {summary['unverifiedNonOfficial']} non-official levels and "
        f"{summary['unverifiedOfficialConversions']} official conversion levels have no replay-based score. "
        f"Of the non-official rows, {len(structural)} bundled Classic levels cannot win under "
        "the current native object and rescue rules recorded below.\n\n"
        "The `playtest` column records the latest check. A passive loss or timeout only describes a run "
        "without player input. It does not prove that the level is impossible. "
        "Source-compatible replays can have an absent or different level version; their native wins are valid, but source parity is unverified.\n\n"
        "The `issue` column records a replay-analysis failure where one occurred. Such rows have "
        "no replay-based score and do not count as verified wins.\n\n"
        "Classic fan rows marked `no functional exit` contain no exit object. "
        "The native fan runtime activates all 32 object slots when every exit would otherwise "
        "be inactive under the DOS rule. This gives the 30 late-exit levels functional exits; "
        "the ledger records their winning evidence separately. The inspected Golems assembly "
        "processes all 32 slots. Other native fan "
        "levels still use DOS object semantics, so full Golems parity is not established. See "
        "[the traditional Lemmix object rule]"
        "(https://www.neolemmix.com/old/nle_piece_properties.html), `classic-structural-limits.json` "
        "and `validation.md`. A row marked `rescue requirement exceeds population` also cannot win "
        "on the bundled level.\n\n"
        "A native win shows that this engine can complete the level. It does not independently prove "
        "physics parity with the source engine. The `physics_parity` column records partial "
        "assignment-state matches and known object-rule replay differences where checked. "
        "The full parity gate remains separate.\n\n"
        "Bundled Classic fan playback uses the Golems timed-level clock, which allows two more "
        "update cycles than the DOS clock. Official Classic levels retain the DOS clock. "
        "[The clock audit](classic-fan-clock-audit.json) replayed 2,138 earlier fan witnesses: "
        "all retained their wins. The selected fan witnesses were then rescored with ten probes "
        "on the bundled levels. Three earlier replay-key mismatches were repaired from commands "
        "that won again under both clocks; their provenance is in "
        "`source-clock-candidates/replay-integrity-repairs.json`. See `validation.md` and "
        "`Tools/DifficultyDiagnostics/ClassicFanClockAudit/main.swift` for the source check.\n\n"
        "The Classic replay initial-state hash covers the starting counters, workers and terrain "
        "mask. It does not include configured object triggers. An archive fingerprint and a replay "
        "run under the current object rule are required alongside that hash. "
        "`FAN_COMPARE_GOLEMS_OBJECTS=1` with `FAN_VERIFY_ONLY=1` in `ExpandFanEvidence` "
        "compares selected winning replays with all 32 object slots active. "
        "`classic-golems-object-comparisons.json` records those native rule comparisons; "
        "`python3 Tools/DifficultyDiagnostics/verify_golems_object_comparisons.py` checks "
        "their level and replay identities. These comparisons are not full source-physics checks.\n\n"
        f"{len(golems_alternative_records)} affected "
        f"{'level has' if len(golems_alternative_records) == 1 else 'levels have'} a separate "
        "strictly replayed win under Golems' 32-slot object rule. "
        "The alternative score and replay are in `classic-golems-alternative-evidence.json` "
        "and `classic-golems-alternative-solutions.json`. "
        "Set `FAN_GOLEMS_OBJECTS=1` and `FAN_VERIFY_ONLY=1` in `ExpandFanEvidence` "
        "to recheck these alternative replays. "
        "This is object-rule compatibility evidence, not full source physics parity.\n\n"
        "`classic-source-outcomes.json` compares unchanged published replay inputs against "
        "their saved-count and completion-tick headers. The `physics_parity` column flags saved-count "
        "differences and completion differences over five ticks. "
        f"Saved count and completion within five ticks match on "
        f"{summary['classicSourceOutcomeMatchesWithinFiveTicks']} of "
        f"{summary['classicSourceOutcomeComparisons']} unchanged source-input comparisons. "
        "A published header is limited "
        "outcome evidence, not a full simulation trace.\n\n"
        f"{len(classic_neo_derivations)} bundled Classic fan levels also have exact native wins "
        "from published Lemmings Plus I NeoLemmix replay inputs. Their source archive, "
        "per-replay digests and native replay digests are in "
        "`classic-neolemmix-replay-derivations.json`. "
        "Run `python3 Tools/DifficultyDiagnostics/verify_classic_neolemmix_replay_derivations.py` "
        "to check the identities, digests and input conversion; the optional source archive "
        "adds source-byte checks. These native wins do not establish source physics parity.\n\n"
        "Third-party replay archives and community styles remain in the ignored local build folder. "
        "The repository does not redistribute them. See `summary.json` for source digests.\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
