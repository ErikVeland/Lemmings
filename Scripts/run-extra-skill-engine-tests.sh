#!/bin/zsh
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$project_dir/.build/extra-skill-engine"
export LEMMINGS_TEST_AUDIO=muted
mkdir -p "$build_dir/modules"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$build_dir/ModuleCache" -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" -o "$build_dir/tests" \
  "$project_dir/Tests/ExtraSkillEngineTests/main.swift"
"$build_dir/tests"
