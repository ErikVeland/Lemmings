#!/bin/zsh
# Builds the Lemmings 3 guide trace with its focused source-backed test.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/l3-guide-trace-tests"
cd "$project_dir"
mkdir -p "$build_dir/modules"
export CLANG_MODULE_CACHE_PATH="$build_dir/module-cache"
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  Tools/Lemmings3Completion/Replay.swift Tools/Lemmings3Completion/GuideTrace.swift \
  Tests/Lemmings3GuideTraceTests/main.swift -o "$build_dir/GuideTraceTests"
"$build_dir/GuideTraceTests"
