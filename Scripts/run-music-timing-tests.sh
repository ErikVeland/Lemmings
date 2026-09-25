#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/music-timing-tests"
mkdir -p "$build_dir"
swiftc -swift-version 6 -warnings-as-errors \
  "$project_dir/Sources/NxlvKit/MusicTimingCatalogue.swift" \
  "$project_dir/Tests/MusicTimingTests/main.swift" -o "$build_dir/tests"
"$build_dir/tests" "$project_dir/Resources/Music/timing.json"
python3 "$project_dir/Tests/MusicTimingTests/check-assets.py"
