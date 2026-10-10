#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/verify-golems-phase-alternatives"
resources_dir="${1:-$project_dir/.build/learning-evidence/resources}"
mkdir -p "$build_dir/modules"

swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
swiftc -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/VerifyGolemsPhaseAlternatives" \
  "$project_dir/Tools/DifficultyDiagnostics/VerifyGolemsPhaseAlternatives/main.swift" \
  "$project_dir/Sources/LemmingsLocal/FanLevelLibrary.swift" \
  "$project_dir/Sources/LemmingsLocal/GameAssetCache.swift"

LEMMINGS_TEST_AUDIO=muted "$build_dir/VerifyGolemsPhaseAlternatives" \
  "$project_dir" "$resources_dir"
