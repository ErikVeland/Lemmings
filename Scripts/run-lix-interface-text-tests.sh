#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/lix-interface-text-tests"
font_dir="${LIX_INTERFACE_FONT_DIR:-$project_dir/.build/dependencies/lix-f1e805048fe439a4a0e9cc650c613713ababac8b/data/fonts}"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
compiler="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
sdk="$developer_dir/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
mkdir -p "$build_dir/modules"
export LEMMINGS_TEST_WINDOWS=offscreen
export LEMMINGS_TEST_AUDIO=muted
"$compiler" -swift-version 6 -warnings-as-errors -sdk "$sdk" -parse-as-library \
  -module-cache-path "$build_dir/ModuleCache" -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  "$project_dir/Sources/NxlvKit/LixInterfaceText.swift" -o "$build_dir/libNxlvKit.dylib"
"$compiler" -swift-version 6 -warnings-as-errors -sdk "$sdk" \
  -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" "$project_dir/Tests/LixInterfaceTextTests/main.swift" \
  -o "$build_dir/tests"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests" "$font_dir" "$build_dir/lix-font.png"
