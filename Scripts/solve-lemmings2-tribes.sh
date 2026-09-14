#!/bin/zsh
# Builds the Lemmings 2 route solver and runs one tribe chain for each named tribe, in parallel.
# Usage: zsh Scripts/solve-lemmings2-tribes.sh [tribe ...] [-- solver options]
# Without tribe names, all twelve tribes run. Logs go to .build/l2-solver/tribes/<tribe>.log.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/l2-solver"
cd "$project_dir"
data="$project_dir/Sources/Ports/Lemm2"
[[ -f "$data/LEVELS/LEVEL000.DAT" ]] || data="$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources/Ports/Lemm2"
[[ -f "$data/LEVELS/LEVEL000.DAT" ]] || { echo "Lemmings 2 data not found." >&2; exit 1; }
tribes=()
while (( $# )) && [[ "$1" != -- ]]; do tribes+=("$1"); shift; done
[[ "${1:-}" == -- ]] && shift
(( ${#tribes} )) || tribes=(classic beach cavelem circus egyptian highland medieval outdoor polar shadow space sports)
mkdir -p "$build_dir/modules" "$build_dir/tribes"
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  Tools/Lemmings2Solver/*.swift -o "$build_dir/solver"
pids=()
for tribe in "${tribes[@]}"; do
  "$build_dir/solver" tribe "$data" "$tribe" "$@" > "$build_dir/tribes/$tribe.log" 2>&1 &
  pids+=($!)
done
# A tribe whose chain breaks exits 2. That is a result, so only an error (exit 1) fails the script.
failed=0
for pid in "${pids[@]}"; do
  wait "$pid" && code=0 || code=$?
  (( code == 1 )) && failed=1
done
for tribe in "${tribes[@]}"; do grep -E '^(TRIBE|ERROR)' "$build_dir/tribes/$tribe.log" || tail -n 1 "$build_dir/tribes/$tribe.log"; done
exit $failed
