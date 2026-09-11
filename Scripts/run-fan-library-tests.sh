#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/fan-library-tests"
library_dir="${FAN_TEST_LIBRARY_DIR:-$build_dir}"
mkdir -p "$build_dir"
if [[ -z "${FAN_TEST_LIBRARY_DIR:-}" ]]; then
  mkdir -p "$library_dir/modules"
  swiftc -O -swift-version 6 -parse-as-library -emit-module -emit-library \
    -module-name NxlvKit -emit-module-path "$library_dir/modules/NxlvKit.swiftmodule" \
    -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
    -o "$library_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
fi
swiftc -O -swift-version 6 -I "$library_dir/modules" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" -o "$build_dir/Tests" \
  "$project_dir/Tests/FanLevelLibraryTests/main.swift" \
  "$project_dir/Sources/LemmingsLocal/FanLevelLibrary.swift" \
  "$project_dir/Sources/LemmingsLocal/FanLevelUpdates.swift"
cd "$project_dir"
"$build_dir/Tests" "$@"
