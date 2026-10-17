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
fetched_commit = subprocess.run(
    ["git", "rev-parse", "FETCH_HEAD"], check=True, capture_output=True, text=True
).stdout.strip()
main_record = json.loads((evidence / "current-main-steel-contact-183bc8a8-2026-10-17.json").read_text())
main_source = subprocess.run(
    ["git", "show", f"{current_commit}:{source_path}"], check=True, capture_output=True
).stdout
runtime_hash = hashlib.sha256(main_source).hexdigest()
if current_commit != fetched_commit or main_record["headCommit"] != current_commit:
    raise SystemExit("FAIL current-main Mole evidence does not match fetched HEAD.")
if hashlib.sha256(runtime.read_bytes()).hexdigest() != runtime_hash:
    raise SystemExit("FAIL worktree runtime source differs from HEAD.")
if main_record["runtimeSourceSHA256"] != runtime_hash:
    raise SystemExit("FAIL current-main runtime source differs from its evidence record.")


def compare_trace(case_name, trace, expected_matches, expected_ranges):
    case = next(item for item in followup["cases"] if item["name"] == case_name)
    source_positions = {tick: (left + 8, top + 18) for tick, left, top, *_ in case["samples"]}
    trace_name = Path(trace["trace"]).name
    trace_bytes = (evidence / trace_name).read_bytes()
    if hashlib.sha256(trace_bytes).hexdigest() != trace["traceSHA256"]:
        raise SystemExit(f"FAIL {case_name} trace hash differs from its record.")
    native = {sample["tick"]: (sample["x"], sample["y"]) for sample in json.loads(trace_bytes)}
    matches = [tick for tick, position in source_positions.items() if native.get(tick) == position]
    ranges = []
    for tick in matches:
        if not ranges or tick > ranges[-1][-1] + 1:
            ranges.append([tick])
        else:
            ranges[-1].append(tick)
    actual_ranges = [[ticks[0], ticks[-1]] for ticks in ranges]
    if len(matches) != expected_matches or actual_ranges != expected_ranges:
        raise SystemExit(f"FAIL {case_name} trace positions differ from its summary.")
    return len(source_positions), len(matches)


left = main_record["sourceTraces"]["steel-left-facing"]
air = main_record["sourceTraces"]["steel-air-gap"]
left_count, left_matches = compare_trace(
    "steel-left-facing", left, left["exactPositionMatches"], left["matchingTickRanges"]
)
air_count, air_matches = compare_trace(
    "steel-air-gap", air, air["exactPositionMatches"], air["matchingTickRanges"]
)
parity_summary = f"current main traces match {left_matches}/{left_count} left-facing and {air_matches}/{air_count} air-gap positions"
audit_bytes = (evidence / "current-head-fixture-audit-183bc8a8.json").read_bytes()
if hashlib.sha256(audit_bytes).hexdigest() != main_record["fixtureAudit"]["rawReportFileSHA256"]:
    raise SystemExit("FAIL current-main fixture audit hash differs from its record.")
audit = json.loads(audit_bytes)
exact_routes = sum(result["passed"] and result["routeStatus"] == "exact" for result in audit["results"])
route_failures = sum(result["routeStatus"] == "route-fails" for result in audit["results"])
if (len(audit["results"]), exact_routes, route_failures) != (
    main_record["fixtureAudit"]["fixtures"],
    main_record["fixtureAudit"]["exactDoubleReplays"],
    main_record["fixtureAudit"]["routeFailures"],
):
    raise SystemExit("FAIL current-main fixture audit counts differ from its record.")
print(f"PASS current main {current_commit[:8]} matches freshly fetched origin/main")

if comparison["coordinateDifferences"] != 0 or comparison["samplesCompared"] != len(samples):
    raise SystemExit("FAIL Mole comparison summary does not match its samples.")
print(f"PASS recorded DOS/prototype samples: {len(samples)} positions, ticks {first}–{last}")
print("PASS isolated prototype patch reconstructs from its recorded baseline")
print("PASS current-main source and trace hashes match the retained evidence")
print(f"PASS current-main fixture audit: {exact_routes}/{len(audit['results'])} exact, {route_failures} route failures")
print(f"OPEN production-to-DOS trajectory parity: {parity_summary}")
print("OPEN source fall transition and full Mole rules remain unmatched")

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
