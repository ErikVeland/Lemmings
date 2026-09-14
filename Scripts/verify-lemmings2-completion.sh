#!/bin/zsh
# Replays every recorded Lemmings 2 route twice and checks the committed manifest.
# Pass --require-all to require all levels and twelve continuous tribe runs.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/l2-completion"
cd "$project_dir"
data="$project_dir/Sources/Ports/Lemm2"
[[ -f "$data/LEVELS/LEVEL000.DAT" ]] || data="$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources/Ports/Lemm2"
[[ -f "$data/LEVELS/LEVEL000.DAT" ]] || { echo "Lemmings 2 data not found." >&2; exit 1; }
mkdir -p "$build_dir/modules"
python3 Tests/Lemmings2CompletionTests/test_chains.py
python3 Tools/Lemmings2Completion/report.py --check
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  Tools/Lemmings2Completion/main.swift -o "$build_dir/verify"
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  Tests/Lemmings2CompletionTests/events.swift -o "$build_dir/events"
"$build_dir/events" "$data"
if [[ "${1:-}" == --negative ]]; then
  swiftc -O -swift-version 6 -warnings-as-errors \
    -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
    -Xlinker -rpath -Xlinker "$build_dir" \
    Tests/Lemmings2CompletionTests/negative.swift -o "$build_dir/negative"
  exec "$build_dir/negative" "$data"
fi
python3 Tests/Lemmings2CompletionTests/test_chain_gate.py "$build_dir/verify" "$data"
"$build_dir/verify" "$data" "$@"
