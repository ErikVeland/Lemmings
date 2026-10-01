#!/bin/zsh
# Builds the Lemmings 3 route solver and searches the named levels.
# Usage: zsh Scripts/solve-lemmings3-levels.sh <level number>... | missing [--budget SECONDS] [--beam N]
#        [--fewer-inputs-first] [--promote] [--out DIR]
# A route counts only after two replays agree. --promote writes it into
# Tests/Lemmings3CompletionTests/Fixtures when it keeps more lemmings than the existing route.
# Then run python3 Tools/CampaignCompletion/report.py and Scripts/verify-l3-completion.sh.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/l3-solver"
cd "$project_dir"
mkdir -p "$build_dir/modules"
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  Tools/Lemmings3Completion/Replay.swift Tools/Lemmings3Solver/*.swift -o "$build_dir/solver"
# Enforce an outer wall limit when a long candidate step misses the solver's
# internal time checks. The budget applies to each requested level.
python3 - "$build_dir/solver" "$@" <<'PYTHON'
import subprocess
import sys

solver, *args = sys.argv[1:]
options = {"--budget", "--beam", "--depth", "--out"}
budget = 600.0
levels = 0
skip = False
for index, argument in enumerate(args):
    if skip:
        skip = False
        continue
    if argument in options:
        if argument == "--budget" and index + 1 < len(args):
            try:
                budget = float(args[index + 1])
            except ValueError:
                pass
        skip = True
    elif argument == "missing":
        levels = 90
    elif argument.isdigit():
        levels += 1

limit = max(1, levels) * (max(1.0, budget) + 15.0)
try:
    result = subprocess.run([solver, *args], timeout=limit, check=False)
except subprocess.TimeoutExpired:
    print(f"TIMEOUT: L3 solver exceeded its {limit:g}-second wall limit.", file=sys.stderr)
    sys.exit(124)
sys.exit(result.returncode)
PYTHON
