#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/spatial-audio-tests"
mkdir -p "$build_dir/modules"
swiftc -swift-version 6 -target "$(uname -m)-apple-macos13.0" -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
cat "$project_dir/Sources/LemmingsLocal/SoundEffectPlayer.swift" \
  "$project_dir/Tests/SpatialAudioTests/checks.swift" > "$build_dir/main.swift"
swiftc -swift-version 6 -target "$(uname -m)-apple-macos13.0" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  "$build_dir/main.swift" -o "$build_dir/spatial-audio-tests"
"$build_dir/spatial-audio-tests"
mkdir -p "$build_dir/l2"
cp "$project_dir/Tests/SpatialAudioTests/l2-checks.swift" "$build_dir/l2/main.swift"
swiftc -swift-version 6 -target "$(uname -m)-apple-macos13.0" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  "$project_dir/Sources/LemmingsLocal/Lemmings2SoundPlayer.swift" "$build_dir/l2/main.swift" \
  -o "$build_dir/l2-spatial-audio-tests"
cd "$project_dir"
"$build_dir/l2-spatial-audio-tests"
