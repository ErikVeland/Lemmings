#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/sequel-mac-artwork"
art_python="${SEQUEL_ART_PYTHON:-python3}"
mac_art="${MAC_ARTWORK_ROOT:-$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources/MacArtwork}"
cd "$project_dir"
if [[ ! -f "$build_dir/libNxlvKit.dylib" ]]; then
  print -u2 "Run Scripts/run-sequel-mac-artwork-tests.sh first to build the tools."
  exit 1
fi
if [[ ! -f "$mac_art/lemmings/manifest.json" ]]; then
  mac_art="$build_dir/reference-mac"
  python3 Tools/MacArtwork/prepare.py "$mac_art"
fi
"$art_python" -c 'import PIL, numpy'
for tool in reference proof; do
  swiftc -O -swift-version 6 -target "$(uname -m)-apple-macos12.3" \
    -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
    -Xlinker -rpath -Xlinker "$build_dir" -o "$build_dir/$tool" "Tools/SequelMacArtwork/$tool.swift"
done
"$build_dir/reference" "$build_dir/references" "$mac_art"
"$art_python" Tools/SequelMacArtwork/analyse.py "$build_dir/references"
# Emit a candidate table for review. Never silently replace the checked-in rules.
"$art_python" Tools/SequelMacArtwork/learn.py "$build_dir/references" "$build_dir/candidate-rules.swift"
cmp "$build_dir/candidate-rules.swift" Sources/NxlvKit/Lemmings2MacRuleTables.swift
"$build_dir/proof" "$build_dir/proof-v2" "$mac_art"
"$art_python" Tools/SequelMacArtwork/sheets.py "$build_dir"
