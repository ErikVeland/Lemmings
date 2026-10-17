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
if sys.argv[1:]:
    raise SystemExit("Usage: verify-l3-mole-trace.py")

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

current_commit = subprocess.run(
    ["git", "rev-parse", "HEAD"], check=True, capture_output=True, text=True
).stdout.strip()
origin_main_commit = subprocess.run(
    ["git", "rev-parse", "refs/remotes/origin/main"], check=True, capture_output=True, text=True
).stdout.strip()
if current_commit != origin_main_commit:
    raise SystemExit("FAIL HEAD does not match origin/main.")

runtime_bytes = subprocess.run(
    ["git", "show", f"{current_commit}:{source_path}"], check=True, capture_output=True
).stdout
runtime_hash = hashlib.sha256(runtime_bytes).hexdigest()
main_records = [
    json.loads(path.read_text()) for path in sorted(evidence.glob("current-main-*.json"), reverse=True)
]
current_record = next(
    (
        record for record in main_records
        if isinstance(record, dict)
        and record.get("runtimeSourceSHA256") == runtime_hash
        and record.get("headCommit")
        and subprocess.run(
            ["git", "merge-base", "--is-ancestor", record["headCommit"], current_commit],
            check=False,
        ).returncode == 0
        and "sourceTraces" in record
    ),
    None,
)
if current_record is None:
    raise SystemExit("FAIL origin/main Mole source has no matching retained evidence.")
recorded_engine_commit = current_record["headCommit"]
record_label = f"current-main engine source recorded at {recorded_engine_commit[:8]}"
if current_record["runtimeSourceSHA256"] != runtime_hash:
    raise SystemExit(f"FAIL {record_label} runtime source differs from its evidence record.")


def compare_trace(case_name, trace, expected_matches, expected_ranges):
    case = next(item for item in followup["cases"] if item["name"] == case_name)
    source_positions = {tick: (left + 8, top + 18) for tick, left, top, *_ in case["samples"]}
    trace_name = Path(trace["trace"]).name
    trace_bytes = (evidence / trace_name).read_bytes()
    if hashlib.sha256(trace_bytes).hexdigest() != trace["traceSHA256"]:
        raise SystemExit(f"FAIL {case_name} trace hash differs from its record.")
    native = {sample["tick"]: (sample["x"], sample["y"]) for sample in json.loads(trace_bytes)}
    matches = [tick for tick, position in source_positions.items() if native.get(tick) == position]
    mismatches = [
        (tick, source_positions[tick], native.get(tick))
        for tick in source_positions
        if native.get(tick) != source_positions[tick]
    ]
    ranges = []
    for tick in matches:
        if not ranges or tick > ranges[-1][-1] + 1:
            ranges.append([tick])
        else:
            ranges[-1].append(tick)
    actual_ranges = [[ticks[0], ticks[-1]] for ticks in ranges]
    if len(matches) != expected_matches or actual_ranges != expected_ranges:
        raise SystemExit(f"FAIL {case_name} trace positions differ from its summary.")
    return len(source_positions), len(matches), mismatches


left = current_record["sourceTraces"]["steel-left-facing"]
air = current_record["sourceTraces"]["steel-air-gap"]
left_count, left_matches, _ = compare_trace(
    "steel-left-facing", left, left["exactPositionMatches"], left["matchingTickRanges"]
)
air_count, air_matches, air_mismatches = compare_trace(
    "steel-air-gap", air, air["exactPositionMatches"], air["matchingTickRanges"]
)
parity_summary = f"{record_label} traces match {left_matches}/{left_count} left-facing and {air_matches}/{air_count} air-gap positions"
post_drop = current_record["sourceBasis"]["postDropPatrol"]
first_mismatch = next(mismatch for mismatch in air_mismatches if mismatch[0] > 182)
first_mismatch_tick, first_source_position, first_runtime_position = first_mismatch
expected_first = post_drop["firstDivergence"]
if (
    first_mismatch_tick != expected_first["tick"]
    or list(first_source_position) != expected_first["sourceCentreFeet"]
    or list(first_runtime_position) != expected_first["runtimeCentreFeet"]
):
    raise SystemExit("FAIL recorded first post-drop source mismatch differs from the traces.")
tick_positions = {
    tick: (source_x, runtime_x)
    for tick, source_x, runtime_x in zip(
        range(182, 191),
        post_drop["sourceCentreXByTick182Through190"],
        post_drop["runtimeCentreXByTick182Through190"],
    )
}
air_source_case = next(item for item in followup["cases"] if item["name"] == "steel-air-gap")
air_source_positions = {
    tick: left + 8 for tick, left, top, *_ in air_source_case["samples"]
}
air_runtime_samples = json.loads((evidence / Path(air["trace"]).name).read_text())
air_runtime_positions = {sample["tick"]: sample["x"] for sample in air_runtime_samples}
for tick, (source_x, runtime_x) in tick_positions.items():
    if source_x != air_source_positions[tick]:
        raise SystemExit(f"FAIL recorded source post-drop position differs at tick {tick}.")
    if runtime_x != air_runtime_positions[tick]:
        raise SystemExit(f"FAIL recorded runtime post-drop position differs at tick {tick}.")
audit_name = Path(current_record["fixtureAudit"]["rawReport"]).name
audit_bytes = (evidence / audit_name).read_bytes()
if hashlib.sha256(audit_bytes).hexdigest() != current_record["fixtureAudit"]["rawReportFileSHA256"]:
    raise SystemExit(f"FAIL {record_label} fixture audit hash differs from its record.")
audit = json.loads(audit_bytes)
exact_routes = sum(result["passed"] and result["routeStatus"] == "exact" for result in audit["results"])
route_failures = sum(result["routeStatus"] == "route-fails" for result in audit["results"])
if (len(audit["results"]), exact_routes, route_failures) != (
    current_record["fixtureAudit"]["fixtures"],
    current_record["fixtureAudit"]["exactDoubleReplays"],
    current_record["fixtureAudit"]["routeFailures"],
):
    raise SystemExit(f"FAIL {record_label} fixture audit counts differ from its record.")
print(f"PASS current main {current_commit[:8]} matches origin/main")
print(
    f"PASS current main uses Mole runtime source recorded at {recorded_engine_commit[:8]}"
)

if comparison["coordinateDifferences"] != 0 or comparison["samplesCompared"] != len(samples):
    raise SystemExit("FAIL Mole comparison summary does not match its samples.")
print(f"PASS recorded DOS/prototype samples: {len(samples)} positions, ticks {first}–{last}")
print("PASS isolated prototype patch reconstructs from its recorded baseline")
print(f"PASS {record_label} source and trace hashes match the retained evidence")
print(
    f"PASS post-drop mismatch is recorded at tick {first_mismatch_tick}: "
    f"source={first_source_position}, runtime={first_runtime_position}"
)
print(f"PASS {record_label} fixture audit: {exact_routes}/{len(audit['results'])} exact, {route_failures} route failures")
print(f"OPEN production-to-DOS trajectory parity: {parity_summary}")
print("OPEN post-drop movement cadence and full Mole rules remain unmatched")

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
