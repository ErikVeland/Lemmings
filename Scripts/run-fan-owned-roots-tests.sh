#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/fan-owned-roots-tests"
library_dir="${FAN_TEST_LIBRARY_DIR:-$build_dir}"
swift_compiler="${LEMMINGS_SWIFTC:-/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc}"
sdk_dir="${LEMMINGS_MACOS_SDK:-/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk}"
if [[ ! -x "$swift_compiler" ]]; then swift_compiler="$(xcrun --find swiftc)"; fi
if [[ ! -d "$sdk_dir" ]]; then sdk_dir="$(xcrun --sdk macosx --show-sdk-path)"; fi
mkdir -p "$build_dir"
if [[ -z "${FAN_TEST_LIBRARY_DIR:-}" ]]; then
  mkdir -p "$library_dir/modules"
  "$swift_compiler" -sdk "$sdk_dir" -target "$(uname -m)-apple-macosx12.3" \
    -module-cache-path "$build_dir/ModuleCache" -swift-version 6 -warnings-as-errors \
    -parse-as-library -emit-module -emit-library -module-name NxlvKit \
    -emit-module-path "$library_dir/modules/NxlvKit.swiftmodule" \
    -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
    -framework CoreGraphics -framework ImageIO \
    -o "$library_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
fi
"$swift_compiler" -sdk "$sdk_dir" -target "$(uname -m)-apple-macosx12.3" \
  -module-cache-path "$build_dir/ModuleCache" \
  -O -swift-version 6 -warnings-as-errors -I "$library_dir/modules" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" -o "$build_dir/tests" \
  "$project_dir/Tests/FanOwnedRootsTests/main.swift" \
  "$project_dir/Sources/LemmingsLocal/GameAssetCache.swift" \
  "$project_dir/Sources/LemmingsLocal/GameResources.swift" \
  "$project_dir/Sources/LemmingsLocal/FanLevelLibrary.swift"
cd "$project_dir"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests"
