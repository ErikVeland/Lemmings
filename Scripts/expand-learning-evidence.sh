#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
build_dir="$project_dir/.build/learning-evidence"
resources_dir="${1:-$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources}"
output_dir="${2:-$build_dir/output}"
mkdir -p "$build_dir/modules" "$build_dir/source" "$output_dir"
cp Sources/NxlvKit/*.swift "$build_dir/source/"
shasum -a 256 "$build_dir"/source/*.swift > "$output_dir/source-manifest.sha256"
swiftc -O -swift-version 6 -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$build_dir"/source/*.swift
swiftc -O -swift-version 6 -parse-as-library -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" Tools/DifficultyDiagnostics/ExpandFanEvidence.swift \
  Sources/LemmingsLocal/GameAssetCache.swift Sources/LemmingsLocal/FanLevelLibrary.swift \
  -o "$build_dir/ExpandFanEvidence"
FAN_REACTIVE_SEARCH=1 FAN_APPROXIMATE_SEARCH=1 "$build_dir/ExpandFanEvidence" "$resources_dir" \
  "$project_dir/Artifacts/ClassicProgression/audit.json" "$output_dir"

FAN_SEMANTICS_ONLY=1 "$build_dir/ExpandFanEvidence" "$resources_dir" \
  "$output_dir/audit.json" "$output_dir"
