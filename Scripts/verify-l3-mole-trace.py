#!/usr/bin/env python3
"""Check the original-engine Mole trace and excavation observations."""

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


project = Path(__file__).resolve().parents[1]
evidence = project / "Documentation/ReleaseReadiness/L3MoleVerification-2026-10-15"
runtime = project / "Sources/NxlvKit/Lemmings3Runtime.swift"
candidate_mode = sys.argv[1:] == ["--worktree-candidate"]
if sys.argv[1:] not in ([], ["--worktree-candidate"]):
    raise SystemExit("Usage: verify-l3-mole-trace.py [--worktree-candidate]")

source = json.loads((evidence / "original-steel-actor-trace.json").read_text())
comparison = json.loads((evidence / "prototype-steel-comparison.json").read_text())
followup = json.loads((evidence / "original-followup-traces.json").read_text())
tunnel_edges = json.loads((evidence / "original-tunnel-edge-check.json").read_text())
if not comparison["status"].startswith("isolated prototype"):
    raise SystemExit("FAIL Mole coordinate samples are not labelled as prototype evidence.")
baseline = json.loads((evidence / "baseline-provenance.json").read_text())
source_path = "Sources/NxlvKit/Lemmings3Runtime.swift"
baseline_commit = baseline["gitCommit"]
baseline_source = subprocess.run(
    ["git", "show", f"{baseline_commit}:{source_path}"],
    check=True,
    capture_output=True,
).stdout
if hashlib.sha256(baseline_source).hexdigest() != comparison["baselineRuntimeSHA256"]:
    raise SystemExit("FAIL prototype base source differs from the recorded baseline.")
baseline_text = baseline_source.decode()
movement_start = baseline_text.index("    private mutating func updateCreatures()")
movement_end = baseline_text.index("    public mutating func step()", movement_start)
baseline_movement_hash = hashlib.sha256(baseline_text[movement_start:movement_end].encode()).hexdigest()
if baseline_movement_hash != comparison["moleMovementSourceSHA256"]:
    raise SystemExit("FAIL recorded Mole movement checksum differs from the prototype baseline.")
with tempfile.TemporaryDirectory() as temporary_directory:
    prototype_root = Path(temporary_directory)
    prototype_source = prototype_root / source_path
    prototype_source.parent.mkdir(parents=True, exist_ok=True)
    prototype_source.write_bytes(baseline_source)
    subprocess.run(
        ["patch", "-p1", "-i", str(evidence / "mole-prototype.patch")],
        cwd=prototype_root,
        check=True,
        capture_output=True,
    )
    prototype_hash = hashlib.sha256(prototype_source.read_bytes()).hexdigest()
if prototype_hash != comparison["prototypeRuntimeSHA256"]:
    raise SystemExit("FAIL isolated prototype source differs from the recorded patch.")
source_by_tick = {sample["tick"]: sample for sample in source["samples"]}
first = comparison["firstTick"]
last = comparison["lastTick"]
interval = comparison["sampleIntervalTicks"]
expected_ticks = list(range(first, last + 1, interval))
samples = comparison["samples"]

if interval <= 0 or [sample["tick"] for sample in samples] != expected_ticks:
    raise SystemExit("FAIL Mole sample ticks do not match the recorded interval.")
for sample in samples:
    original = source_by_tick.get(sample["tick"])
    if original is None:
        raise SystemExit(f"FAIL DOS actor trace is missing tick {sample['tick']}.")
    source_position = (original["sourceLeft"] + 8, original["sourceTop"] + 18)
    native_position = (sample["nativeX"], sample["nativeY"])
    recorded_source = (sample["sourceX"], sample["sourceY"])
    if source_position != recorded_source or native_position != recorded_source or not sample["matches"]:
        raise SystemExit(f"FAIL Mole position differs at tick {sample['tick']}.")

runtime_hash = hashlib.sha256(runtime.read_bytes()).hexdigest()
report = json.loads(current_report.read_text())
current_commit = subprocess.run(
    ["git", "rev-parse", "HEAD"], check=True, capture_output=True, text=True
).stdout.strip()
if report["headCommit"] != current_commit:
    raise SystemExit("FAIL current production report does not match HEAD.")
current_head = report["currentHeadRerun"]
if current_head["runtimeSourceSHA256"] != runtime_hash:
    raise SystemExit("FAIL production runtime source differs from the current-head report.")
if current_head["freshTraceProduced"]:
    if "exactPositionMatches" not in current_head or "traceSHA256" not in current_head:
        raise SystemExit("FAIL fresh current-head trace summary is incomplete.")
    parity_summary = (
        f"fresh current-head trace matches "
        f"{current_head['exactPositionMatches']}/{current_head['samples']} positions"
    )
else:
    cell_carve = report["cellCarveVariant"]
    if cell_carve["candidateRuntimeSHA256"] != runtime_hash:
        raise SystemExit("FAIL current production source differs from its recorded cell-carve evidence.")
    if current_head["sourceHashMatchedEvidence"] != "cellCarveVariant":
        raise SystemExit("FAIL isolated candidate evidence is not identified in the current-head report.")
    parity_summary = (
        f"matching source hash has prior {current_head['candidateExactMatches']}/"
        f"{current_head['samples']} candidate matches, not a fresh current-head trace"
    )
if comparison["coordinateDifferences"] != 0 or comparison["samplesCompared"] != len(samples):
    raise SystemExit("FAIL Mole comparison summary does not match its samples.")

air_gap = report.get("currentHeadAirGapRerun")
if not air_gap or air_gap["runtimeSourceSHA256"] != runtime_hash:
    raise SystemExit("FAIL current air-gap trace does not match the production runtime source.")
if air_gap["headCommit"] != current_commit:
    raise SystemExit("FAIL current air-gap trace does not match HEAD.")
air_gap_trace_path = project / air_gap["productionTracePath"]
air_gap_trace_bytes = air_gap_trace_path.read_bytes()
if hashlib.sha256(air_gap_trace_bytes).hexdigest() != air_gap["traceSHA256"]:
    raise SystemExit("FAIL current air-gap production trace hash differs from its record.")
air_gap_trace = json.loads(air_gap_trace_bytes)
air_gap_source = next(case for case in followup["cases"] if case["name"] == "steel-air-gap")
air_gap_source_positions = {
    tick: (left + 8, top + 18)
    for tick, left, top, _width, _height in air_gap_source["samples"]
}
air_gap_native = {sample["tick"]: (sample["x"], sample["y"]) for sample in air_gap_trace}
air_gap_matches = [
    tick for tick, position in air_gap_source_positions.items()
    if air_gap_native.get(tick) == position
]
air_gap_ranges = []
for tick in air_gap_matches:
    if not air_gap_ranges or tick > air_gap_ranges[-1][-1] + 1:
        air_gap_ranges.append([tick])
    else:
        air_gap_ranges[-1].append(tick)
air_gap_first_mismatch_tick = next(
    tick for tick in sorted(air_gap_source_positions)
    if air_gap_native.get(tick) != air_gap_source_positions[tick]
)
if len(air_gap_matches) != air_gap["exactPositionMatches"] or len(air_gap_source_positions) != air_gap["samples"]:
    raise SystemExit("FAIL current air-gap position count differs from its record.")
if [[ticks[0], ticks[-1]] for ticks in air_gap_ranges] != air_gap["matchingTickRanges"]:
    raise SystemExit("FAIL current air-gap matching ranges differ from its record.")
if air_gap_first_mismatch_tick != air_gap["firstMismatch"]["tick"]:
    raise SystemExit("FAIL current air-gap first mismatch differs from its record.")
for tick in (167, 173, 182):
    expected_source = air_gap["fallTransitionComparison"][f"sourceTick{tick}"]
    expected_native = air_gap["fallTransitionComparison"][f"productionTick{tick}"]
    if list(air_gap_source_positions[tick]) != expected_source or list(air_gap_native[tick]) != expected_native:
        raise SystemExit(f"FAIL current air-gap fall sample differs at tick {tick}.")

print(f"PASS recorded DOS/prototype samples: {len(samples)} positions, ticks {first}–{last}")
print("PASS isolated prototype patch reconstructs from its recorded baseline")
print("PASS current production runtime hash matches the current-head report")
print(f"OPEN production-to-DOS trajectory parity: {parity_summary}")
print(f"OPEN current air-gap trace matches {len(air_gap_matches)}/{len(air_gap_source_positions)} positions; source fall transition remains unmatched")

if followup["schemaVersion"] != 1 or not followup["headless"] or followup["audio"] != "muted":
    raise SystemExit("FAIL original-engine follow-up metadata is incomplete.")
if len(followup["sourceExecutableSHA256"]) != 64:
    raise SystemExit("FAIL original-engine executable fingerprint is invalid.")
if followup["sourceExecutableSHA256"] != source["sourceExecutableSHA256"]:
    raise SystemExit("FAIL original-engine traces do not use the same executable.")
followup_count = 0
for case in followup["cases"]:
    if case["columns"] != ["tick", "left", "top", "width", "height"]:
        raise SystemExit(f"FAIL unexpected sample columns in {case['name']}.")
    if case["coordinateMapping"] != {"centerX": "left + 8", "feetY": "top + 18"}:
        raise SystemExit(f"FAIL unexpected coordinate mapping in {case['name']}.")
    if case["repeatPositionDifferences"] != 0 or case["repeatedSamplesCompared"] != len(case["samples"]):
        raise SystemExit(f"FAIL repeated capture mismatch in {case['name']}.")
    ticks = [sample[0] for sample in case["samples"]]
    omitted = set(range(ticks[0], ticks[-1] + 1)) - set(ticks)
    if not omitted.issubset(set(case["excludedInvalidRecordTicks"])):
        raise SystemExit(f"FAIL unexplained sample gap in {case['name']}.")
    previous_tick = None
    for tick, left, top, width, height in case["samples"]:
        if width != 16 or height != 18 or (previous_tick is not None and tick <= previous_tick):
            raise SystemExit(f"FAIL invalid actor sample in {case['name']} at tick {tick}.")
        if not isinstance(left, int) or not isinstance(top, int):
            raise SystemExit(f"FAIL invalid actor coordinates in {case['name']} at tick {tick}.")
        previous_tick = tick
    followup_count += len(case["samples"])

if len(followup["cases"]) != 2 or followup_count != 673:
    raise SystemExit("FAIL expected two complete follow-up traces (673 samples).")
if len(tunnel_edges["witnesses"]) != 4:
    raise SystemExit("FAIL expected four tunnel-edge counterexamples.")
source_only = proposal_only = 0
for witness in tunnel_edges["witnesses"]:
    background = witness["backgroundRGB"]
    after = witness["sourceAfterRGB"]
    difference = max(abs(a - b) for a, b in zip(background, after))
    if difference != witness["sourceBackgroundMaxChannelDifference"]:
        raise SystemExit(f"FAIL source colour difference mismatch at {witness['x']},{witness['y']}.")
    source_clear = difference <= tunnel_edges["colourTolerancePerChannel"]
    if source_clear != witness["sourceMatchesBackground"]:
        raise SystemExit(f"FAIL source terrain classification mismatch at {witness['x']},{witness['y']}.")
    if source_clear and not witness["prototypeCleared"]:
        source_only += 1
    elif not source_clear and witness["prototypeCleared"]:
        proposal_only += 1
if (source_only, proposal_only) != (2, 2):
    raise SystemExit("FAIL expected two source-only and two proposal-only tunnel-edge clears.")

print(f"PASS repeated original-engine traces: {len(followup['cases'])} cases, {followup_count} samples")
print("PASS tunnel-edge evidence: two source-only and two proposal-only clears")
