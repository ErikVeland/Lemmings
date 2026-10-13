#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/music-rewind"
mkdir -p "$build_dir/modules" "$build_dir/ModuleCache"
cd "$project_dir"
export LEMMINGS_TEST_AUDIO=muted
export LEMMINGS_TEST_WINDOWS=offscreen
target="$(uname -m)-apple-macos12.3"
swiftc -swift-version 6 -target "$target" -parse-as-library -module-cache-path "$build_dir/ModuleCache" \
  -emit-module -emit-library -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
cat Sources/LemmingsAudio/MusicRewindBuffer.swift Sources/LemmingsAudio/MusicFileDeck.swift \
  Sources/LemmingsAudio/ModuleMusicPlayer.swift Sources/LemmingsAudio/VinylRamp.swift \
  Sources/LemmingsAudio/SoundtrackPlayer.swift Sources/LemmingsAudio/MusicLibrary.swift \
  Sources/LemmingsAudio/AdaptiveDJPlayer.swift Tests/MusicRewindTests/checks.swift > "$build_dir/main.swift"
swiftc -swift-version 6 -warnings-as-errors -target "$target" -module-cache-path "$build_dir/ModuleCache" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit -Xlinker -rpath -Xlinker "$build_dir" \
  -framework AVFoundation -framework AppKit "$build_dir/main.swift" -o "$build_dir/checks"
python3 Tools/UITestRunner/run.py "$build_dir/checks"
