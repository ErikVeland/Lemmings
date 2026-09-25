#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/music-catalogue-tests"
mkdir -p "$build_dir"
swiftc -swift-version 6 -warnings-as-errors \
  "$project_dir/Sources/NxlvKit/SoundtrackCatalogue.swift" \
  "$project_dir/Tests/MusicCatalogueTests/main.swift" -o "$build_dir/MusicCatalogueTests"
"$build_dir/MusicCatalogueTests" "$project_dir"
python3 "$project_dir/Tests/MusicCatalogueTests/check-assets.py"
