#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
build_dir="$project_dir/.build/audio-realtime-tests"
mkdir -p "$build_dir/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$build_dir/ModuleCache"
swift build --target NxlvKit --disable-sandbox --disable-automatic-resolution
products="$(swift build --show-bin-path --disable-sandbox --disable-automatic-resolution)"
cat Sources/LemmingsAudio/AudioPlaybackQueue.swift Sources/LemmingsAudio/BufferedAudioSource.swift Sources/LemmingsAudio/SoundEffectPlayer.swift \
    Tests/AudioPerformanceTests/RealtimeChecks.swift > "$build_dir/main.swift"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
    -I "$products" -module-cache-path "$build_dir/ModuleCache" \
    "$build_dir/main.swift" "$products/NxlvKit.o" -framework AVFoundation -o "$build_dir/tests"
LEMMINGS_TEST_AUDIO=muted python3 Tools/UITestRunner/run.py "$build_dir/tests"
