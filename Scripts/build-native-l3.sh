#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/native-l3"
app_dir="$build_dir/Lemmings 3 Native.app"
export MACOSX_DEPLOYMENT_TARGET=12.3
mkdir -p "$build_dir/modules" "$app_dir/Contents/MacOS" "$app_dir/Contents/Frameworks"
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$app_dir/Contents/Frameworks/libNxlvKit.dylib" \
  "$project_dir"/Sources/NxlvKit/*.swift
app_sources=("$project_dir"/Sources/LemmingsLocal/*.swift)
app_sources=("${(@)app_sources:#*/main.swift}")
swiftc -O -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -I "$build_dir/modules" -L "$app_dir/Contents/Frameworks" -lNxlvKit \
  -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  -o "$app_dir/Contents/MacOS/Lemmings3Native" \
  "$project_dir/Tools/Lemmings3Native/main.swift" "${app_sources[@]}"
cp "$project_dir/Tools/Lemmings3Native/Info.plist" "$app_dir/Contents/Info.plist"
zsh "$project_dir/Scripts/bundle-game-data.sh" "$app_dir/Contents/Resources" l3
codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
