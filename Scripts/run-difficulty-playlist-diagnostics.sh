#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
swift build --target NxlvKit
product_dir="$(swift build --show-bin-path)"
build_dir="$project_dir/.build/difficulty-playlist-diagnostics"
mkdir -p "$build_dir"
if [[ -f "$product_dir/NxlvKit.o" ]]; then
  module_dir="$product_dir"
  objects=("$product_dir/NxlvKit.o")
else
  module_dir="$product_dir/Modules"
  objects=("$product_dir"/NxlvKit.build/*.o)
fi
swiftc -swift-version 6 -I "$module_dir" "${objects[@]}" \
  "$project_dir/Tools/DifficultyDiagnostics/Playlists.swift" \
  -o "$build_dir/DifficultyPlaylistDiagnostics"
"$build_dir/DifficultyPlaylistDiagnostics" "$@"
