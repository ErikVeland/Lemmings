#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/nuke-audio-tests"
mkdir -p "$build_dir/modules"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
cat "$project_dir/Sources/LemmingsAudio/MusicFileDeck.swift" \
  "$project_dir/Sources/LemmingsAudio/ModuleMusicPlayer.swift" \
  "$project_dir/Sources/LemmingsAudio/VinylRamp.swift" \
  "$project_dir/Sources/LemmingsAudio/SoundEffectPlayer.swift" \
  "$project_dir/Sources/LemmingsAudio/FailureMusic.swift" \
  "$project_dir/Sources/LemmingsLocal/FailureMood.swift" \
  "$project_dir/Tests/NukeAudioTests/checks.swift" > "$build_dir/main.swift"
# The shared audio files join this single module here.
sed -i '' '/^import LemmingsAudio$/d' ""$build_dir/main.swift""
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/checks" "$build_dir/main.swift"
# All started engines render offline. No windows or hardware audio output.
LEMMINGS_TEST_AUDIO=muted "$build_dir/checks"
