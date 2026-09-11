#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/run-recovery-file-tests"
mkdir -p "$build_dir/modules"
cd "$project_dir"
library_dir="${SAVE_TEST_LIBRARY_DIR:-$build_dir}"
if [[ -z "${SAVE_TEST_LIBRARY_DIR:-}" ]]; then
  swiftc -O -swift-version 6 -target "$(uname -m)-apple-macos13.0" -parse-as-library -emit-module -emit-library \
    -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
    -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
    -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
fi
swiftc -O -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos13.0" \
  -I "$library_dir/modules" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" -o "$build_dir/tests" \
  Sources/LemmingsLocal/RunRecovery.swift Tests/RunRecoveryFileTests/main.swift
"$build_dir/tests"
