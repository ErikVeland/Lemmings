#!/bin/zsh
# Builds the Lemmings 2 route solver and solves one campaign level.
# Usage: zsh Scripts/solve-lemmings2-level.sh <tribe-NN> [--seed FILE] [--population N] [--beam N] [--depth N] [--budget SECONDS] [--cell PIXELS] [--refire TICKS] [--out DIR]
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/l2-solver"
cd "$project_dir"
data="$project_dir/Sources/Ports/Lemm2"
[[ -f "$data/LEVELS/LEVEL000.DAT" ]] || data="$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources/Ports/Lemm2"
[[ -f "$data/LEVELS/LEVEL000.DAT" ]] || { echo "Lemmings 2 data not found." >&2; exit 1; }
mkdir -p "$build_dir/modules"
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  Tools/Lemmings2Solver/*.swift -o "$build_dir/solver"
# Cap a slow candidate advance outside the solver's internal time checks.
python3 - "$build_dir/solver" "$data" "$@" <<'PYTHON'
import subprocess
import sys

solver, data, *args = sys.argv[1:]
budget = 900.0
if "--budget" in args:
    index = args.index("--budget")
    if index + 1 < len(args):
        try:
            budget = float(args[index + 1])
        except ValueError:
            pass
limit = max(1.0, budget) + 15.0
try:
    result = subprocess.run([solver, "level", data, *args], timeout=limit, check=False)
except subprocess.TimeoutExpired:
    print(f"TIMEOUT: L2 solver exceeded its {limit:g}-second wall limit.", file=sys.stderr)
    sys.exit(124)
sys.exit(result.returncode)
PYTHON
