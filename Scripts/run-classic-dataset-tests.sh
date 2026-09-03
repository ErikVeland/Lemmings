#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/classic-dataset-tests"
mkdir -p "$build_dir/modules"
swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
swiftc -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/ClassicDataSetTests" "$project_dir/Tests/ClassicDataSetTests/main.swift"

if [[ $# -gt 0 ]]; then
  "$build_dir/ClassicDataSetTests" "$@"
  exit 0
fi

# Collect every directory that holds a level archive we recognise.
dirs=()
for candidate in "$project_dir/Content"/*(N/) "$project_dir/Sources/Ports"/*(N/); do
  for prefix in LEVEL DLVEL; do
    # The two titles differ in case, so test both rather than glob.
    if [[ -f "$candidate/${prefix}000.DAT" || -f "$candidate/${prefix}000.dat" ]]; then
      dirs+=("$candidate")
      break
    fi
  done
done

if (( ${#dirs} == 0 )); then
  print "No Lemmings data directories found. Pass one explicitly."
  exit 0
fi
"$build_dir/ClassicDataSetTests" "${dirs[@]}"
