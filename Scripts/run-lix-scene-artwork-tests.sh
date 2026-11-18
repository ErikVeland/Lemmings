#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/lix-scene-tests"
pack="${LIX_ARTWORK_PACK:-$project_dir/.build/alternative-assets/lix}"
swift_compiler="${LEMMINGS_SWIFTC:-/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc}"
sdk_dir="${LEMMINGS_MACOS_SDK:-/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk}"
if [[ ! -x "$swift_compiler" ]]; then swift_compiler="$(xcrun --find swiftc)"; fi
if [[ ! -d "$sdk_dir" ]]; then sdk_dir="$(xcrun --sdk macosx --show-sdk-path)"; fi
export LEMMINGS_TEST_WINDOWS=offscreen
export LEMMINGS_TEST_AUDIO=muted
mkdir -p "$build_dir/modules"
"$swift_compiler" -sdk "$sdk_dir" -target "$(uname -m)-apple-macosx12.3" \
  -swift-version 6 -warnings-as-errors -enable-testing -parse-as-library -emit-module -emit-library \
  -module-cache-path "$build_dir/ModuleCache" -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -framework CoreGraphics -framework ImageIO \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
"$swift_compiler" -sdk "$sdk_dir" -target "$(uname -m)-apple-macosx12.3" \
  -swift-version 6 -warnings-as-errors -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -module-cache-path "$build_dir/ModuleCache" -framework CoreGraphics -framework ImageIO \
  -Xlinker -rpath -Xlinker "$build_dir" \
  "$project_dir/Tests/LixSceneArtworkTests/main.swift" -o "$build_dir/tests"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests" "$pack" "$build_dir"
