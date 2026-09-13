#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/bottom-fall-audio-tests"
app_dir="${LEMMINGS_TEST_APP:-$project_dir/.build/local/Ultimate Lemmings.app}"
mkdir -p "$build_dir/modules"
swiftc -swift-version 6 -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
swiftc -swift-version 6 -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  "$project_dir/Sources/LemmingsLocal/SoundEffectPlayer.swift" \
  "$project_dir/Sources/LemmingsLocal/Lemmings2SoundPlayer.swift" \
  "$project_dir/Tests/BottomFallAudioTests/main.swift" -o "$build_dir/BottomFallAudioTests"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/BottomFallAudioTests" "$app_dir/Contents/Resources"
