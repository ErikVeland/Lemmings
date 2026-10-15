#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
build_dir="$project_dir/.build/hot-seat-ghosts"
shared_dir="${LEMMINGS_GHOST_SHARED_BUILD:-$build_dir}"
mkdir -p "$build_dir" "$shared_dir/modules"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$build_dir/module-cache}"
if [[ -z "${LEMMINGS_GHOST_SHARED_BUILD:-}" ]]; then
  swiftc -swift-version 6 -target "$(uname -m)-apple-macos12.3" -parse-as-library -emit-module -emit-library \
    -module-name NxlvKit -emit-module-path "$shared_dir/modules/NxlvKit.swiftmodule" \
    -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
    -o "$shared_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
  zsh Scripts/build-shared-modules.sh "$shared_dir/modules" "$shared_dir" "$(uname -m)-apple-macos12.3"
fi
sparkle_framework="$(LEMMINGS_BUILD_ROOT="$build_dir/dependencies" zsh Scripts/ensure-sparkle.sh)"
test_app="$build_dir/HotSeatGhostTests.app"
mkdir -p "$test_app/Contents/MacOS"
cp Resources/Info.plist "$test_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable HotSeatGhostTests' "$test_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier academy.glasscode.lemmings.integration-tests.ghosts' "$test_app/Contents/Info.plist"
resource_dir="${LEMMINGS_TEST_RESOURCES:-$project_dir/Resources}"
ln -sfn "$resource_dir" "$test_app/Contents/Resources"
sources=(Sources/LemmingsLocal/*.swift)
sources=("${(@)sources:#*/main.swift}")
swiftc -swift-version 6 -D HOT_SEAT_GHOST_TESTS -target "$(uname -m)-apple-macos12.3" \
  -I "$shared_dir/modules" -L "$shared_dir" -lNxlvKit -lLemmingsMobileCore -lLemmingsGameArt -lLemmingsAudio -lLemmingsAppCore \
  -Xlinker -rpath -Xlinker "$shared_dir" -F "${sparkle_framework:h}" -framework Sparkle \
  -Xlinker -rpath -Xlinker "${sparkle_framework:h}" \
  -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  -o "$test_app/Contents/MacOS/HotSeatGhostTests" "${sources[@]}" Tests/HotSeatGhostTests/core.swift Tests/HotSeatGhostTests/main.swift
if [[ "${TEST_COMPILE_ONLY:-0}" != 1 ]]; then
  python3 Tools/UITestRunner/run.py "$test_app/Contents/MacOS/HotSeatGhostTests"
fi
