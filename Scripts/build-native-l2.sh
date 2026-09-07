#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/native-l2"
app_dir="$build_dir/Lemmings 2 Native.app"
export MACOSX_DEPLOYMENT_TARGET=13.0
mkdir -p "$build_dir/modules" "$app_dir/Contents/MacOS" "$app_dir/Contents/Frameworks"
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$app_dir/Contents/Frameworks/libNxlvKit.dylib" \
  "$project_dir"/Sources/NxlvKit/*.swift
# The shared music player retains a macOS 13-compatible AVAudioEngine call.
swiftc -O -swift-version 6 -warnings-as-errors -Wwarning DeprecatedDeclaration \
  -I "$build_dir/modules" -L "$app_dir/Contents/Frameworks" -lNxlvKit \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  -o "$app_dir/Contents/MacOS/Lemmings2Native" \
  "$project_dir/Tools/Lemmings2Native/main.swift" \
  "$project_dir/Sources/LemmingsLocal/Lemmings2PlayWindow.swift" \
  "$project_dir/Sources/LemmingsLocal/SequelArtworkRenderer.swift" \
  "$project_dir/Sources/LemmingsLocal/Lemmings2SoundPlayer.swift" \
  "$project_dir/Sources/LemmingsLocal/MusicPlayer.swift"
cp "$project_dir/Tools/Lemmings2Native/Info.plist" "$app_dir/Contents/Info.plist"
zsh "$project_dir/Scripts/bundle-game-data.sh" "$app_dir/Contents/Resources" l2
codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
