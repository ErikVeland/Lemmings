#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/audio-performance-tests"
mkdir -p "$build_dir/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$build_dir/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$build_dir/ModuleCache"
cd "$project_dir"
swift build --target NxlvKit --disable-sandbox --disable-automatic-resolution
products="$(swift build --show-bin-path --disable-sandbox --disable-automatic-resolution)"
cat Sources/LemmingsAudio/MusicRewindBuffer.swift Sources/LemmingsAudio/MusicFileDeck.swift Sources/LemmingsAudio/ModuleMusicPlayer.swift Sources/LemmingsAudio/VinylRamp.swift \
    Sources/LemmingsAudio/SoundEffectPlayer.swift Tests/AudioPerformanceTests/main.swift > "$build_dir/main.swift"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" -I "$products" \
    -module-cache-path "$build_dir/ModuleCache" "$build_dir/main.swift" "$products/NxlvKit.o" \
    -framework AVFoundation -o "$build_dir/tests"
if [[ "${1:-}" != "--compile-only" ]]; then python3 Tools/UITestRunner/run.py "$build_dir/tests"; fi
cat Sources/LemmingsAudio/SoundEffectPlayer.swift Tests/SpatialAudioTests/checks.swift > "$build_dir/spatial.swift"
cp "$build_dir/spatial.swift" "$build_dir/main.swift"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" -I "$products" \
    -module-cache-path "$build_dir/ModuleCache" "$build_dir/main.swift" "$products/NxlvKit.o" \
    -framework AVFoundation -o "$build_dir/spatial-tests"
if [[ "${1:-}" != "--compile-only" ]]; then python3 Tools/UITestRunner/run.py "$build_dir/spatial-tests"; fi
cat Sources/LemmingsAudio/AdaptiveDJPlayer.swift Sources/LemmingsAudio/MusicLibrary.swift \
    Sources/LemmingsAudio/MusicRewindBuffer.swift Sources/LemmingsAudio/MusicFileDeck.swift Sources/LemmingsAudio/ModuleMusicPlayer.swift \
    Sources/LemmingsAudio/SoundtrackPlayer.swift Sources/LemmingsAudio/VinylRamp.swift \
    Tests/AdaptiveDJPlaybackTests/main.swift > "$build_dir/main.swift"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" -I "$products" \
    -module-cache-path "$build_dir/ModuleCache" "$build_dir/main.swift" "$products/NxlvKit.o" \
    -framework AVFoundation -framework AppKit -o "$build_dir/dj-tests"
if [[ "${1:-}" != "--compile-only" ]]; then python3 Tools/UITestRunner/run.py "$build_dir/dj-tests" --signal-only; fi
