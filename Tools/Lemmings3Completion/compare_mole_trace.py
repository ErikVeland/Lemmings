#!/usr/bin/env python3
"""Compare a current L3 Mole run with the retained original-engine trace."""

import json
from pathlib import Path
import sys


if len(sys.argv) != 4:
    raise SystemExit("Usage: compare_mole_trace.py <trace.json> <source-traces.json> <case>")

production = json.loads(Path(sys.argv[1]).read_text())
source_document = json.loads(Path(sys.argv[2]).read_text())
case = next(case for case in source_document["cases"] if case["name"] == sys.argv[3])
production_by_tick = {sample["tick"]: (sample["x"], sample["y"]) for sample in production}
mismatches = []
for tick, left, top, _width, _height in case["samples"]:
    expected = (left + 8, top + 18)
    actual = production_by_tick.get(tick)
    if actual != expected:
        mismatches.append({"tick": tick, "source": expected, "production": actual})

matches = len(case["samples"]) - len(mismatches)
print(f"Compared {len(case['samples'])} source positions; exact matches: {matches}.")
if mismatches:
    print("First mismatch:", json.dumps(mismatches[0], sort_keys=True))
    raise SystemExit(1)
print("PASS production Mole positions match the original-engine trace.")
