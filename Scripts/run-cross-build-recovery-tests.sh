#!/bin/zsh
# Saved runs must survive any later build. Restores Classic runs saved the way
# earlier builds saved them.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/cross-build-recovery-tests"
mkdir -p "$build_dir/modules"
cd "$project_dir"
library_dir="${SAVE_TEST_LIBRARY_DIR:-$build_dir}"
if [[ -z "${SAVE_TEST_LIBRARY_DIR:-}" ]]; then
  swiftc -O -swift-version 6 -target "$(uname -m)-apple-macos12.3" -parse-as-library -emit-module -emit-library \
    -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
    -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
    -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
fi
swiftc -O -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -I "$library_dir/modules" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" -o "$build_dir/tests" \
  Sources/LemmingsLocal/GameSession.swift Sources/LemmingsLocal/RunRecovery.swift Tests/CrossBuildRecoveryTests/main.swift
ports="${CROSS_BUILD_PORTS:-$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources/Ports}"
"$build_dir/tests" "$ports/oh_no_more_lemmings_dos-1991-11-14_2232"
