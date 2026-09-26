#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
analysis_python="${MUSIC_TIMING_PYTHON:-$project_dir/.build/music-analysis-venv/bin/python}"
music_dir="${1:-$project_dir/Sources/Music}"
cache_dir="$project_dir/.build/music-timing"
mkdir -p "$cache_dir"
swiftc -O -swift-version 6 -warnings-as-errors \
  "$project_dir/Sources/NxlvKit/ProTrackerModule.swift" \
  "$project_dir/Tools/MusicTiming/main.swift" -o "$cache_dir/render-modules"
"$cache_dir/render-modules" "$music_dir" "$cache_dir/modules"
"$analysis_python" "$project_dir/Tools/MusicTiming/analyze.py" \
  --music "$music_dir" --cache "$cache_dir" --output "$project_dir/Resources/Music/timing.json"
cp "$project_dir/Resources/Music/timing.json" "$music_dir/timing.json"
"$analysis_python" "$project_dir/Tools/MusicTiming/report.py"
