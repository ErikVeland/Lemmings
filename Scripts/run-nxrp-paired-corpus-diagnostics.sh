#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/nxrp-paired-corpus-diagnostics"
source_dir="$build_dir/source"

if (( $# != 3 )); then
  print -u2 "Usage: $0 <levels-directory> <replays-directory> <styles-directory>"
  exit 2
fi

mkdir -p "$build_dir/modules" "$source_dir"
rsync -a --delete "$project_dir/Sources/NxlvKit/" "$source_dir/"

swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library \
  -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" \
  "$source_dir"/*.swift

swiftc -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/NxrpPairedCorpusDiagnostics" \
  "$project_dir/Tests/NxrpPairedCorpusDiagnostics/main.swift"

"$build_dir/NxrpPairedCorpusDiagnostics" "$@"
