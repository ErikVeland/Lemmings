#!/bin/zsh
set -euo pipefail
project_dir="/Users/veland/.codex/worktrees/release-1-7-9/Lemmings"
build_dir="$project_dir/.build/replay-movie-tests"
mkdir -p "$build_dir/modules"
cd "$project_dir"
library_dir="${REPLAY_TEST_LIBRARY_DIR:-$build_dir}"
if [[ -z "${REPLAY_TEST_LIBRARY_DIR:-}" ]]; then
swiftc -O -swift-version 6 -target "$(uname -m)-apple-macos12.3" -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
fi
sparkle_framework="$(zsh "$project_dir/Scripts/ensure-sparkle.sh")"
sparkle_framework_dir="${sparkle_framework:h}"
sources=(Sources/LemmingsLocal/*.swift)
sources=("${(@)sources:#*/main.swift}")
sources=("${(@)sources:#*/ReplayWindow.swift}")
cat Sources/LemmingsLocal/ReplayWindow.swift Tests/ReplayMovieTests/main.swift > "$build_dir/main.swift"
swiftc -O -swift-version 6 -target "$(uname -m)-apple-macos12.3" \
  -I "$library_dir/modules" -L "$library_dir" -lNxlvKit \
  -F "$sparkle_framework_dir" -framework Sparkle -Xlinker -rpath -Xlinker "$sparkle_framework_dir" \
  -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  -Xlinker -rpath -Xlinker "$library_dir" \
  -o "$build_dir/tests" "${sources[@]}" "$build_dir/main.swift"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests"
