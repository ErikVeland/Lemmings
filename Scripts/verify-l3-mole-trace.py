#!/usr/bin/env python3
"""Check the recorded original-engine Mole positions against the native trace."""

import hashlib
import json
from pathlib import Path


project = Path(__file__).resolve().parents[1]
evidence = project / "Documentation/ReleaseReadiness/L3MoleVerification-2026-10-15"
runtime = project / "Sources/NxlvKit/Lemmings3Runtime.swift"

source = json.loads((evidence / "original-steel-actor-trace.json").read_text())
comparison = json.loads((evidence / "prototype-steel-comparison.json").read_text())
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
if runtime_hash != comparison["baselineRuntimeSHA256"]:
    raise SystemExit("FAIL Mole comparison baseline does not match the current runtime source.")
if comparison["coordinateDifferences"] != 0 or comparison["samplesCompared"] != len(samples):
    raise SystemExit("FAIL Mole comparison summary does not match its samples.")

print(f"PASS original DOS to native Mole trace: {len(samples)} positions, ticks {first}–{last}")
