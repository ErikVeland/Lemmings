#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/adaptive-dj-playback-tests"
mkdir -p "$build_dir/modules"

swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos13.0" -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift

swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos13.0" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -framework AppKit -framework AVFoundation \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/AdaptiveDJPlaybackTests" \
  "$project_dir/Sources/LemmingsLocal/AdaptiveDJPlayer.swift" \
  "$project_dir/Sources/LemmingsLocal/MusicPlayer.swift" \
  "$project_dir/Sources/LemmingsLocal/SoundtrackPlayer.swift" \
  "$project_dir/Tests/AdaptiveDJPlaybackTests/main.swift"
"$build_dir/AdaptiveDJPlaybackTests" "${1:-$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources/Music}"
