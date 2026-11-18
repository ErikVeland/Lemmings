#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/open-starter-tests"
swift_compiler="${LEMMINGS_SWIFTC:-/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc}"
sdk_dir="${LEMMINGS_MACOS_SDK:-/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk}"
if [[ ! -x "$swift_compiler" ]]; then swift_compiler="$(xcrun --find swiftc)"; fi
if [[ ! -d "$sdk_dir" ]]; then sdk_dir="$(xcrun --sdk macosx --show-sdk-path)"; fi
export LEMMINGS_TEST_AUDIO=muted
export LEMMINGS_TEST_WINDOWS=offscreen
export CLANG_MODULE_CACHE_PATH="$build_dir/xcode-module-cache"
mkdir -p "$build_dir/modules" "$CLANG_MODULE_CACHE_PATH"
"$swift_compiler" -sdk "$sdk_dir" -target "$(uname -m)-apple-macosx12.3" \
  -swift-version 6 -warnings-as-errors -parse-as-library \
  -module-cache-path "$CLANG_MODULE_CACHE_PATH" \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
"$swift_compiler" -sdk "$sdk_dir" -target "$(uname -m)-apple-macosx12.3" \
  -swift-version 6 -warnings-as-errors \
  -module-cache-path "$CLANG_MODULE_CACHE_PATH" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/OpenStarterContentTests" "$project_dir/Tests/OpenStarterContentTests/main.swift"
"$build_dir/OpenStarterContentTests"
