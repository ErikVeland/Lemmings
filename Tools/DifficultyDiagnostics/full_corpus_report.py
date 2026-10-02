"""Combine Classic and NeoLemmix scores with explicit completion evidence."""

import base64
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
INDEPENDENT_SOURCE_CHECKS = ROOT / "Artifacts/DifficultyEvaluation/classic-independent-source-checks.json"
STATE_HASH_ALIASES = ROOT / "Artifacts/DifficultyEvaluation/classic-state-hash-alias-checks.json"
CLASSIC_NEO_DERIVATIONS = ROOT / "Artifacts/DifficultyEvaluation/classic-neolemmix-replay-derivations.json"
OUTPUT = ROOT / "Artifacts/DifficultyEvaluation"
SOURCE_FAMILIES = OUTPUT / "source-engine-families.json"
GOLEMS_SELECTED_ORDINARY = OUTPUT / "classic-golems-selected-ordinary.json"
GOLEMS_HATCH_RECHECK = OUTPUT / "classic-golems-hatch-recheck.json"
GOLEMS_HATCH_RECOVERY = OUTPUT / "classic-golems-hatch-recovery.json"
GOLEMS_HATCH_REJECTIONS = OUTPUT / "classic-golems-hatch-rejections.json"
FAN_SOLUTIONS = ROOT / "Artifacts/LearningJourney/candidate-solutions.json"
GOLEMS_PHASE_EVIDENCE = [
    OUTPUT / f"classic-golems-phase-shift-{name}.json"
    for name in ("alternatives", "targeted", "second", "third", "fourth", "fifth", "sixth", "seventh")
] + [OUTPUT / "classic-golems-mining-rule.json",
     OUTPUT / "classic-golems-current-source-recheck.json",
     OUTPUT / "classic-golems-hatch-recovery.json"]
PARTIAL_SOURCE_ASSIGNMENTS = {
    "NeoLemmix_Introduction_Pack/Advanced_Training/Beam_Up_The_Equipment!.nxlv":
        ("aa256c48ee1bb20077d0b22b7ccfee6ed4b6835467422fc318e0770c2bdcac7d", 5),
    "NeoLemmix_Introduction_Pack/Advanced_Training/Curse_Of_The_Gold.nxlv":
        ("437ad8f26c6a13ad6f7f83ec26e138c64be10be8d2f3d9f7ad0a54455e82106e", 11),
    "NeoLemmix_Introduction_Pack/Basic_Training_2/Counterclockwise.nxlv":
        ("2acdf4bf8dd221d1cc9b3287f38eda854e1f58522c6aaf54b274ae16f7099c67", 16),
}
NATIVE_OBSTRUCTIONS = {
    ("fan:lldb-66", "Lemmy556 My little levels 2.dat#9"): {
        "sourceRevision": "963dd4d3cd016df98aedcb0890f7eff91b6255e57858474295da25d7a8216756",
        "initialHash": "1bfbdc625156837f956e92a596690f2c704b96021276293a336d6a5598aa5774",
        "issue": "Sole lemming falls out at tick 94; no stocked skill accepts an assignment before then",
    },
    ("fan:lldb-537", "Holiday cLemmings Flurry 1.DAT#2"): {
        "sourceRevision": "d4a17f5380fd0315dd62fc6947535c459088a28d620a6fa3d0ff27c34e50e540",
        "initialHash": "e356fa325bdbfd6f7ee00a062d1e4f700fae14cbafd3360907716b91381a3113",
        "issue": "Sole lemming enters fire at tick 89; no stocked skill accepts an assignment before then",
    },
    ("fan:lldb-211", "More Levels/5)Sacrifice.ini#-1"): {
        "sourceRevision": "4fc97baad0e98022cd89fd9983569a8a2961258619ed83e490491d7f75a788c2",
        "initialHash": "9de18503cf98b718bd9f67590ed6a60d478b45d178dd59b0a880911bd31b9128",
        "issue": "Both lemmings spawn at y=181 below the native maximum y=163 and are lost at ticks 54 and 82 before a skill can be assigned",
    },
    ("fan:lldb-469", "blessed_are_the_bricks.ini#-1"): {
        "sourceRevision": "96c8a2546b2b5e249c66111e6553ed3146c55f570cc47ccf33ad96b9359060c2",
        "initialHash": "8cead17b2e52c361976969e3165a559e6a1c122b987abc98bd999207b34de332",
        "issue": "Only native exit trigger starts at y=284 below the maximum playable y=163",
    },
    ("fan:lldb-204", "Gronklems #5/9) Optical Fibre Land.ini#-1"): {
        "sourceRevision": "75a78c065d97fb8d712aadf84ecf22464ae05f6018758a6902737ea7e1c7d716",
        "initialHash": "e885b76ac5c9d3b42ed8c5de0d90614d3e2c075b2376cfb752a3ac7f04d72005",
        "issue": "Only native exit trigger starts at y=212 below the maximum playable y=163",
    },
    ("fan:lldb-369", "03 - Reciprocity.ini#-1"): {
        "sourceRevision": "50356f4c0234731587eeb93030ee4e771ab9f7b73abd76195a19af50aef284dc",
        "initialHash": "3c9f58c102633349339a22a2159a0ef75ab4aadb866a046ce4f6ee9af66fd1b7",
        "issue": "Only native exit trigger starts at y=280 below the maximum playable y=163",
    },
    ("fan:lldb-203", "Gronklems 6 v2/8) Just Over the Hill.ini#-1"): {
        "sourceRevision": "1900e4554d946d2e464f8a69cff2f2a915c72294c9c57bc2b563cbea3ebb9af0",
        "initialHash": "fa4ec99ff512e3db8742144aa0255ebe96ec7b37e1cc7918b32860ea84581e10",
        "issue": "Only hatch is at y=170 and only exit starts at y=220 below the maximum playable y=163",
    },
    ("fan:lldb-208", "Gronklems 7/8) Industrial Park.ini#-1"): {
        "sourceRevision": "653a50ccce0eac0c98c88c590d3de2b462ac3b990e26d01636d9085c22325ca8",
        "initialHash": "ef58792caad2084636d546eb4e73815060def8cb640f70adc1a6c1cdf4a31103",
        "issue": "Requires 3/3 saves but two of three native hatches are at y=236 below the maximum playable y=163",
    },
    ("fan:lldb-200", "Gronklems #4 (v3)/6) Welcome to Lemmingopolis.ini#-1"): {
        "sourceRevision": "df9f798f55c909c8f0ef925a70b9dea3a607455ce9b63b3d40ebded40ff0d29f",
        "initialHash": "376c3484ab3796b4beccda22739131ae3d08de61f3ba7f6c1143fd3c9dc52ebf",
        "issue": "Only native exit trigger starts at y=216 below the maximum playable y=163",
    },
    ("fan:lldb-203", "Original Levels/8) Just Over the Hill.ini#-1"): {
        "sourceRevision": "1900e4554d946d2e464f8a69cff2f2a915c72294c9c57bc2b563cbea3ebb9af0",
        "initialHash": "8f393575f18965873170e5fd49a21d589d611925a42c72bfb6aaf71e01319e92",
        "issue": "Only hatch is at y=170 and only exit starts at y=228 below the maximum playable y=163",
    },
    ("fan:lldb-206", "8 Tres Hombres.ini#-1"): {
        "sourceRevision": "a7fbd3d48290b5fcf49cb6ca7a8b24b010546ab3d8ab1c5feb7f09821d59e9c2",
        "initialHash": "2b666731fe53452f221de84f15f5fded5385fc60cd27177ed0ae017221a22844",
        "issue": "Requires 3/3 saves but two of three native hatches are at y=182 and y=180 below the maximum playable y=163",
    },
    ("fan:lldb-397", "2010 CONTEST/05pieuw.ini#-1"): {
        "sourceRevision": "7cb5a7b687cccdbe290028ae7648bb15809b3248a3cf9330d418ce16240d63f2",
        "initialHash": "050a40a4c721470ecd550ae11e1d3259885f184d55600d6a3ddaac210ef4e776",
        "issue": "Both native exit triggers start at y=272 below the maximum playable y=163",
    },
    ("fan:lldb-215", "6 Last Lemming Standing.ini#-1"): {
        "sourceRevision": "9ca65d28f41157293456671bdf2ff1ee84d1ec8525cb7cbc5dcf63fa574058a5",
        "initialHash": "f4fcd13ecbf93f6368d0d1af52d496d6452f97d45951c6b5e56e8e2957b801d9",
        "issue": "Only native exit trigger starts at y=268 below the maximum playable y=163",
    },
}
NATIVE_RATE_SWEEPS = {}


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
    independent_source_records = read(INDEPENDENT_SOURCE_CHECKS)["records"] if INDEPENDENT_SOURCE_CHECKS.exists() else []
    independent_source_checks = {
        (record["identity"]["packID"], record["identity"]["levelID"]): record
        for record in independent_source_records
    }
    assert len(independent_source_checks) == len(independent_source_records)
    state_hash_aliases = read(STATE_HASH_ALIASES)["records"] if STATE_HASH_ALIASES.exists() else []
    for record in state_hash_aliases:
        target = classic[json.dumps({"engine": "classic", **record["identity"]}, sort_keys=True)]
        donor = classic[json.dumps({"engine": "classic", **record["donorIdentity"]}, sort_keys=True)]
        assert record["initialStateHash"] == donor["initialHash"]
        if superseded := record.get("currentSelectedMechanics"):
            assert superseded["mechanics"] == "golems"
            assert superseded["initialStateHash"] == target["initialHash"]
            assert target["initialHash"] != record["initialStateHash"]
        else:
            assert record["initialStateHash"] == target["initialHash"]
        assert record["archiveSHA256"] == target["entry"]["sourceRevision"]
        assert record["sceneGeometrySHA256"] != record["donorSceneGeometrySHA256"]
        assert record["puzzleScenarioSHA256"] != record["donorPuzzleScenarioSHA256"]
        assert record["donorOutcome"]["status"] == "win"
        assert record["targetOutcome"]["status"] != "win"
    neo = read(NEO)
    neo_failures = {}
    for failure in read(NEO_REPORT)["failures"]:
        path, _, reason = failure.partition(": ")
        neo_failures[path] = reason
    passive = {row["path"]: row for row in read(PASSIVE)} if PASSIVE.exists() else {}
    assert len(fan) == 6020, len(fan)
    assert len(neo) == 794, len(neo)
    lemmini_pack_ids = {
        f"fan:lldb-{pack_id}" for pack_id in read(SOURCE_FAMILIES)["lemminiPackIDs"]
    }
    source_families = read(SOURCE_FAMILIES)
    golems_pack_ids = {
        f"fan:lldb-{pack_id}" for pack_id in source_families["golemsPackIDs"]
    }
    golems_level_ids = {
        (pack_id, level_id)
        for pack_id, level_ids in source_families["golemsLevelIDs"].items()
        for level_id in level_ids
    }
    ordinary_records = read(GOLEMS_SELECTED_ORDINARY)["records"]
    assert len(ordinary_records) == len(golems_level_ids)
    assert {(record["identity"]["packID"], record["identity"]["levelID"])
            for record in ordinary_records} == golems_level_ids
    solutions = read(FAN_SOLUTIONS)
    for record in ordinary_records:
        row = classic[json.dumps(record["identity"], sort_keys=True)]
        profile = row["profile"]
        revision = profile["key"]["replayRevision"]
        replay = solutions[revision]
        assert record["ordinaryPlayerAssignments"]
        assert (record["sourceActionDerivationVerified"]
                or record.get("terminalAbandonAsNuke")
                or record.get("nativeInputRetiming")
                or record.get("nativeCandidateProvenanceOpen"))
        if record.get("nativeCandidateProvenanceOpen"):
            assert not record["sourceActionDerivationVerified"]
        assert not replay.get("sourceRules") and replay["expected"]["didWin"]
        assert replay["initialStateHash"] == record["initialStateHash"] == row["initialHash"]
        assert record["bundledArchiveSHA256"] == row["entry"]["sourceRevision"]
        assert record["nativeReplaySHA256"] == revision.rsplit(" ", 1)[-1]
        assert record["nativeSaved"] == replay["expected"]["saved"]
        assert record["required"] == replay["expected"]["required"]
        assert record["nativeCompletionTick"] == replay["expected"]["ticks"]
        assert record["difficultyScore"] == profile["overallScore"]
    hatch_recheck = read(GOLEMS_HATCH_RECHECK)
    assert hatch_recheck["selectedReplaysChecked"] == (
        hatch_recheck["baseAuditChecked"] + hatch_recheck["fanEvidenceOverlayChecked"]
    )
    assert hatch_recheck["strictFailures"] == 0
    assert len(hatch_recheck["records"]) == 7
    for record in hatch_recheck["records"]:
        row = classic[json.dumps(record["identity"], sort_keys=True)]
        current = solutions[row["profile"]["key"]["replayRevision"]]
        previous = solutions["SHA256 digest: " + record["previousReplaySHA256"]]
        replay_path = ROOT / record["replayPath"]
        profile_path = ROOT / record["profilePath"]
        assert digest(replay_path) == record["currentReplaySHA256"]
        assert read(profile_path) == row["profile"]
        assert row["entry"]["sourceRevision"] == record["bundledArchiveSHA256"]
        assert row["initialHash"] == current["initialStateHash"] == record["initialStateHash"]
        assert previous["expected"]["saved"] == record["previousSaved"]
        assert previous["expected"]["ticks"] == record["previousCompletionTick"]
        assert current["expected"]["didWin"]
        assert current["expected"]["saved"] == record["currentSaved"]
        assert current["expected"]["required"] == record["required"]
        assert current["expected"]["ticks"] == record["currentCompletionTick"]
        assert row["profile"]["overallScore"] == record["currentDifficultyScore"]
        assert row["profile"]["key"]["replayRevision"].rsplit(" ", 1)[-1] == record["currentReplaySHA256"]
    hatch_recovery = read(GOLEMS_HATCH_RECOVERY)
    assert hatch_recovery["unalignedHatchCandidates"] == 30
    assert hatch_recovery["strictNativeWinningInputs"] == 18
    assert hatch_recovery["newWinningLevels"] == hatch_recovery["strictPostMergeVerified"] == 17
    assert hatch_recovery["sourceHeaderSavedMatches"] == 18
    assert hatch_recovery["sourceHeaderCompletionWithinFiveTicks"] == 18
    assert hatch_recovery["directSourceActionMappings"] == 18
    assert len(hatch_recovery["records"]) == 17
    hatch_recovery_by_id = {
        (record["identity"]["packID"], record["identity"]["levelID"]): record
        for record in hatch_recovery["records"]
    }
    assert len(hatch_recovery["attempts"]) == hatch_recovery["unalignedHatchCandidates"]
    assert Counter(attempt["status"] for attempt in hatch_recovery["attempts"]) == {
        "verified win": 18, "assignment error": 10, "completed loss": 2
    }
    assert all(any(delta != 0 for delta in attempt["hatchSourceDeltas"])
               for attempt in hatch_recovery["attempts"])
    hatch_rejections = read(GOLEMS_HATCH_REJECTIONS)
    rejected_attempts = {
        (attempt["identity"]["packID"], attempt["identity"]["levelID"],
         attempt["sourceReplaySHA256"]): attempt
        for attempt in hatch_recovery["attempts"] if attempt["status"] == "assignment error"
    }
    assert hatch_rejections["nativeBaselineAssignmentErrors"] == 10
    assert hatch_rejections["scratchReplayTrialAssignmentErrors"] == 10
    assert len(hatch_rejections["records"]) == len(rejected_attempts) == 10
    assert Counter(record["observedCause"] for record in hatch_rejections["records"]) == {
        "state or terrain assignment guard": 4,
        "no stocked skill": 3,
        "target already lost": 3,
    }
    for record in hatch_rejections["records"]:
        key = (record["identity"]["packID"], record["identity"]["levelID"],
               record["sourceReplaySHA256"])
        attempt = rejected_attempts.pop(key)
        assert record["bundledInitialStateHash"] == attempt["nativeInitialStateHash"]
        assert record["firstRejectedNativeTick"] > 0
        assert record["sourceDirectAssignmentTrialFirstRejection"]["nativeTick"] >= record["firstRejectedNativeTick"]
    assert not rejected_attempts
    independent_rejection = hatch_rejections["independentSourceCheck"]
    assert independent_rejection["sourceReplayRawSHA256"] == next(
        record["sourceReplaySHA256"] for record in hatch_rejections["records"]
        if record["identity"] == independent_rejection["identity"]
    )
    assert independent_rejection["sourceSaved"] == independent_rejection["sourceRequired"] == 2
    assert independent_rejection["sourceCompletionCycle"] == 381
    assert not independent_rejection["sourceErrors"] and not independent_rejection["proxyErrors"]
    height_timing_trial = independent_rejection["scratchHeightTimingTrial"]
    assert height_timing_trial["variants"] == (
        len(height_timing_trial["hatchYOffsets"])
        * len(height_timing_trial["eventTickShiftsFromNativeMinusOne"])
    ) == 56
    assert height_timing_trial["wins"] == 0
    for record in hatch_recovery["records"]:
        row = classic[json.dumps(record["identity"], sort_keys=True)]
        replay = solutions[row["profile"]["key"]["replayRevision"]]
        assert record["identity"]["engine"] == "classic"
        assert record["nativeReplaySHA256"] == digest(ROOT / record["replayPath"])
        assert read(ROOT / record["profilePath"]) == row["profile"]
        assert row["entry"]["sourceRevision"] == record["bundledArchiveSHA256"]
        assert row["initialHash"] == replay["initialStateHash"] == record["initialStateHash"]
        assert replay["expected"]["didWin"] and replay["expected"]["saved"] == record["nativeSaved"]
        assert replay["expected"]["required"] == record["required"]
        assert replay["expected"]["ticks"] == record["nativeCompletionTick"]
        assert record["sourceActionDerivationVerified"] and record["ordinaryPlayerAssignments"]
        assert record["sourceHeaderSaved"] == record["nativeSaved"]
        assert abs(record["sourceHeaderTicks"] - record["nativeCompletionTick"]) <= 5
    golems_phase_records = [record for path in GOLEMS_PHASE_EVIDENCE
                            for record in read(path)["records"]]
    assert len(golems_phase_records) == len({
        (record["identity"]["packID"], record["identity"]["levelID"])
        for record in golems_phase_records
    })
    assert lemmini_pack_ids <= manifest_pack_ids
    assert golems_pack_ids <= manifest_pack_ids
    assert {pack_id for pack_id, _ in golems_level_ids} <= manifest_pack_ids
    assert golems_level_ids <= {
        (row["entry"]["identity"]["packID"], row["entry"]["identity"]["levelID"])
        for row in fan
    }
    assert not lemmini_pack_ids & golems_pack_ids
    assert all(
        row["entry"]["identity"]["levelID"].lower().endswith((".ini#-1", ".lvl#-1"))
        for row in fan if row["entry"]["identity"]["packID"] in lemmini_pack_ids
    )
    rows = []
    for row in fan:
        profile = row["profile"]
        revision = profile["key"]["replayRevision"]
        verified = profile["confidence"] != "low"
        level_id = row["entry"]["identity"]
        lemmini_source = level_id["packID"] in lemmini_pack_ids
        golems_source = (level_id["packID"] in golems_pack_ids or
                         (level_id["packID"], level_id["levelID"]) in golems_level_ids)
        limit = structural.get((level_id["packID"], level_id["levelID"]))
        native_obstruction = NATIVE_OBSTRUCTIONS.get((level_id["packID"], level_id["levelID"]))
        rate_sweep = NATIVE_RATE_SWEEPS.get((level_id["packID"], level_id["levelID"]))
        if native_obstruction:
            assert not verified
            assert row["entry"]["sourceRevision"] == native_obstruction["sourceRevision"]
            assert row["initialHash"] == native_obstruction["initialHash"]
        if rate_sweep:
            assert not verified
            assert row["entry"]["sourceRevision"] == rate_sweep["sourceRevision"]
            assert row["initialHash"] == rate_sweep["initialHash"]
        object_comparison = golems_objects.get((level_id["packID"], level_id["levelID"]))
        object_alternative = golems_alternatives.get((level_id["packID"], level_id["levelID"]))
        source_outcome = source_outcomes.get((level_id["packID"], level_id["levelID"]))
        independent_source = independent_source_checks.get((level_id["packID"], level_id["levelID"]))
        if source_outcome:
            assert verified
            assert source_outcome["levelSourceRevision"] == row["entry"]["sourceRevision"]
        if independent_source:
            assert independent_source["levelSourceRevision"] == row["entry"]["sourceRevision"]
            if fragment := independent_source.get("publishedReplayURLFragment"):
                assert fragment.startswith("~")
                encoded = fragment[1:]
                raw = base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4))
                assert hashlib.sha256(raw).hexdigest() == independent_source["publishedReplaySHA256"]
                assert raw[0] & 15 == 3
                assert raw[1] == independent_source["sourceSaved"]
                assert int.from_bytes(raw[2:4], "little") == independent_source["sourceCompletionCycles"]
            selected_mechanics = independent_source.get("currentSelectedMechanics")
            if selected_mechanics:
                assert selected_mechanics["mechanics"] == "golems"
                assert selected_mechanics["initialStateHash"] == row["initialHash"]
                assert selected_mechanics["replaySHA256"] == profile["key"]["replayRevision"].rsplit(" ", 1)[-1]
                assert selected_mechanics["initialStateHash"] != independent_source["nativeInitialHash"]
            elif independent_source.get("comparisonMechanics"):
                assert independent_source["comparisonMechanics"] == "golems"
                assert independent_source["auditInitialHash"] == row["initialHash"]
                if independent_source.get("hatchCoordinateEvidencePath"):
                    assert independent_source["nativeInitialHash"] == row["initialHash"]
                else:
                    assert independent_source["nativeInitialHash"] != row["initialHash"]
            else:
                assert independent_source["nativeInitialHash"] == row["initialHash"]
            assert independent_source["sourceRequired"] == independent_source["nativeRequired"]
            assert independent_source["sourceTotal"] == independent_source["nativeTotal"]
            if independent_source["sourcePhysicsParity"] == "outcome mismatch":
                assert independent_source["nativeSaved"] is not None
                assert independent_source["sourceSaved"] != independent_source["nativeSaved"]
            elif independent_source["sourcePhysicsParity"] == "saved-count match; completion-time mismatch":
                assert verified
                assert independent_source["nativeSaved"] == independent_source["sourceSaved"]
                assert abs(independent_source["sourceCompletionCycles"]
                           - independent_source["nativeReplayEndTick"]) > 5
                assert independent_source["nativeReplaySHA256"] == revision.rsplit(" ", 1)[-1]
            elif independent_source["sourcePhysicsParity"] == "assignment mismatch":
                assert independent_source["nativeSaved"] is None
                assert independent_source["nativeFirstRejectedAssignment"]
            else:
                assert independent_source["sourcePhysicsParity"] == "outcome and completion-time match"
                assert verified and source_outcome
                assert independent_source["nativeSaved"] == independent_source["sourceSaved"]
                assert independent_source["nativeSaved"] == source_outcome["nativeSaved"]
                assert independent_source["sourceCompletionCycles"] == independent_source["nativeReplayEndTick"]
                assert independent_source["nativeReplayEndTick"] == source_outcome["nativeCompletionTicks"]
                assert independent_source["nativeReplaySHA256"] == profile["key"]["replayRevision"].rsplit(" ", 1)[-1]
            if independent_source["sourcePhysicsParity"] in ("outcome mismatch", "assignment mismatch") and not selected_mechanics:
                assert not verified
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
        if independent_source:
            observation = {
                "outcome mismatch": "independent source/native replay outcome mismatch",
                "saved-count match; completion-time mismatch": "independent saved count matches; completion differs; terrain unverified",
                "assignment mismatch": "independent source replay assignment rejected natively",
                "outcome and completion-time match": "independent outcome and timing match; terrain unverified",
            }[independent_source["sourcePhysicsParity"]]
            if independent_source.get("currentSelectedMechanics"):
                observation = "historical Original-rule " + observation
            parity_observations.append(observation)
        recovery = hatch_recovery_by_id.get((level_id["packID"], level_id["levelID"]))
        if recovery:
            assert verified and recovery["nativeReplaySHA256"] == revision.rsplit(" ", 1)[-1]
            parity_observations.append("archived Golems replay headers agree; terrain unverified")
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
                     "independent source win; native replay fails" if independent_source and not verified else
                     limit["reason"] if limit else
                     "native obstruction traced" if native_obstruction else
                     "fixed release-rate sweep" if rate_sweep else "bounded search or metadata only",
                     "issue": (f"Exit object in inactive slot(s) {', '.join(map(str, limit['exitObjectSlots']))}"
                               if limit["exitObjectSlots"] else "No exit object in the bundled level")
                     if limit and limit["reason"] == "no functional exit" else
                     f"Requires {limit['requiredToSave']} saves from {limit['totalLemmings']} lemmings"
                     if limit else native_obstruction["issue"] if native_obstruction else
                     rate_sweep["issue"] if rate_sweep else row.get("issue") or "",
                     "source_engine": "Lemmini" if lemmini_source else
                     "Golems" if golems_source else "not independently classified"})
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
                     or run.get("issue", ""), "source_engine": "NeoLemmix"})
    rows.sort(key=lambda row: (row["source"], row["pack"], row["level"]))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with (OUTPUT / "levels.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    sources = {str(path.relative_to(ROOT)): digest(path) for path in (CLASSIC, FAN, NEO, NEO_REPORT)}
    pack_manifest = BUNDLED_FAN_PACKS / "packs.json"
    sources[str(pack_manifest.relative_to(ROOT))] = digest(pack_manifest)
    sources[str(SOURCE_FAMILIES.relative_to(ROOT))] = digest(SOURCE_FAMILIES)
    sources[str(GOLEMS_SELECTED_ORDINARY.relative_to(ROOT))] = digest(GOLEMS_SELECTED_ORDINARY)
    sources[str(GOLEMS_HATCH_RECHECK.relative_to(ROOT))] = digest(GOLEMS_HATCH_RECHECK)
    sources[str(GOLEMS_HATCH_RECOVERY.relative_to(ROOT))] = digest(GOLEMS_HATCH_RECOVERY)
    sources[str(GOLEMS_HATCH_REJECTIONS.relative_to(ROOT))] = digest(GOLEMS_HATCH_REJECTIONS)
    for path in GOLEMS_PHASE_EVIDENCE:
        sources[str(path.relative_to(ROOT))] = digest(path)
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
    if INDEPENDENT_SOURCE_CHECKS.exists():
        sources[str(INDEPENDENT_SOURCE_CHECKS.relative_to(ROOT))] = digest(INDEPENDENT_SOURCE_CHECKS)
    if STATE_HASH_ALIASES.exists():
        sources[str(STATE_HASH_ALIASES.relative_to(ROOT))] = digest(STATE_HASH_ALIASES)
    classic_neo_derivations = read(CLASSIC_NEO_DERIVATIONS)["records"] if CLASSIC_NEO_DERIVATIONS.exists() else []
    if CLASSIC_NEO_DERIVATIONS.exists():
        sources[str(CLASSIC_NEO_DERIVATIONS.relative_to(ROOT))] = digest(CLASSIC_NEO_DERIVATIONS)
    counts = Counter((row["source"], row["completion"]) for row in rows)
    lemmini_rows = [row for row in rows if row["source_engine"] == "Lemmini"]
    assert len(lemmini_rows) == 299, len(lemmini_rows)
    golems_rows = [row for row in rows if row["source_engine"] == "Golems"]
    expected_golems_packs = Counter({
        "fan:lldb-290": 10, "fan:lldb-433": 2,
        "fan:lldb-495": 10, "fan:lldb-496": 10,
    })
    for pack_id, _ in golems_level_ids:
        if pack_id not in golems_pack_ids:
            expected_golems_packs[pack_id] += 1
    assert Counter(row["pack"] for row in golems_rows) == expected_golems_packs
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
               "fixedRateSweepFan": len(NATIVE_RATE_SWEEPS),
               "lemminiSourceLevelsInClassicLane": len(lemmini_rows),
               "golemsSourceLevelsInClassicLane": len(golems_rows),
               "lemminiSourceLevelsWithoutVerifiedWin": sum(
                   row["completion"] == "no verified win" for row in lemmini_rows),
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
               "classicStateHashAliasChecks": len(state_hash_aliases),
               "independentPhysicsParityVerified": 0,
               "partialSourceAssignmentMatches": sum(
                   row["physics_parity"].startswith("partial source assignment match")
                   for row in rows
               ),
               "neoPlaytestStatuses": dict(Counter(row["playtest"] for row in rows if row["source"] == "NeoLemmix"))}
    (OUTPUT / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    (OUTPUT / "README.md").write_text(
        "# Difficulty evaluation\n\n"
        f"This ledger covers {len(fan)} bundled fan levels in the native Classic playback lane "
        f"and {len(neo)} bundled NeoLemmix levels. "
        "A row has a difficulty score only when a winning replay supports it. "
        "Low-confidence metadata estimates remain outside the score column.\n\n"
        f"{len(lemmini_rows)} rows in the Classic playback lane come from 20 packs that "
        "LLDB identifies as Lemmini. Two have a native Classic win and replay-based score; "
        f"{summary['lemminiSourceLevelsWithoutVerifiedWin']} remain unverified. "
        "The `source_engine` column separates known source families from the current "
        "playback lane; most other fan packs are not independently classified there. "
        "Classic's 160-pixel playfield cannot represent several of these levels' hatch "
        "and exit coordinates. This is an engine-family compatibility gap, not proof that "
        "the source puzzles are unsolvable. See `validation.md` for the pack list.\n\n"
        f"{len(golems_rows)} classified levels use the Golems source player, including "
        "exact levels in mixed-evidence packs. "
        "Their source-engine label does not establish native physics parity. "
        "See `validation.md` and `classic-independent-source-checks.json`.\n\n"
        f"The ten Golems replay evidence files hold {len(golems_phase_records)} "
        "distinct exact-level native wins with ten-probe scores. "
        f"{len(ordinary_records)} selected levels have strict ordinary-input wins under Golems "
        "mechanics on their exact bundled levels. "
        "The native Golems exit starts on first trigger contact, as the pinned source does. "
        "Their selected digests and scores are in `levels.csv`. "
        "The two-player alternative stays outside the learning path. "
        "See `classic-golems-mining-rule.json`, "
        "`classic-golems-selected-ordinary.json` and `validation.md`.\n\n"
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
        "`classic-independent-source-checks.json` records Golems browser runs of published "
        "`Holy Cow!` and `It's Raining Lemmings` replays. The source engine wins both. "
        "The earlier unshifted `Holy Cow!` input lost under Original mechanics, and "
        "the unshifted `It's Raining Lemmings` input rejected a Builder. Their selected "
        "Golems-rule replays now win on the exact bundled levels and have scores. "
        "The published `Diving Area` replay saves 4 of 4 in the source player, while its "
        "one-tick-translated native input saves 2 of 4 on matching level and graphics bytes. "
        "Its input timing and intermediate state difference remain open.\n\n"
        "The native Golems profile includes a later hatch rule and a raised fall limit. "
        "The selected routes pass strict native playback; their saved counts and timing "
        "do not establish full source physics parity. "
        "See `validation.md` and `classic-independent-source-checks.json`.\n\n"
        "Bundled Classic fan playback uses the Golems timed-level clock, which allows two more "
        "update cycles than the DOS clock. Official Classic levels retain the DOS clock. "
        "[The clock audit](classic-fan-clock-audit.json) replayed 2,138 earlier fan witnesses: "
        "all retained their wins. The selected fan witnesses were then rescored with ten probes "
        "on the bundled levels. Three earlier replay-key mismatches were repaired from commands "
        "that won again under both clocks; their provenance is in "
        "`source-clock-candidates/replay-integrity-repairs.json`. See `validation.md` and "
        "`Tools/DifficultyDiagnostics/ClassicFanClockAudit/main.swift` for the source check.\n\n"
        "The Classic replay initial-state hash covers the starting counters, workers and terrain "
        "mask. It omits entrance and trigger geometry. "
        f"{len(state_hash_aliases)} unscored levels share that hash with scored levels but have different geometry. "
        "None won with a transferred replay. See `classic-state-hash-alias-checks.json`. "
        "Verify the exact archive fingerprint, level identity and native replay outcome for each row. "
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
