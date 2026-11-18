#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/local-import-transfer-tests"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
compiler="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
sdk="$developer_dir/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
mkdir -p "$build_dir/modules" "$build_dir/ModuleCache"
export LEMMINGS_TEST_AUDIO=muted
export LEMMINGS_TEST_WINDOWS=offscreen
"$compiler" -swift-version 6 -sdk "$sdk" -target "$(uname -m)-apple-macosx12.3" \
  -warnings-as-errors -parse-as-library -module-cache-path "$build_dir/ModuleCache" \
  -emit-module -emit-library -module-name LemmingsMobileCore \
  -emit-module-path "$build_dir/modules/LemmingsMobileCore.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libLemmingsMobileCore.dylib \
  "$project_dir/Sources/LemmingsMobileCore/LocalImportTransfer.swift" \
  -o "$build_dir/libLemmingsMobileCore.dylib"
"$compiler" -swift-version 6 -sdk "$sdk" -target "$(uname -m)-apple-macosx12.3" \
  -warnings-as-errors -parse-as-library -module-cache-path "$build_dir/ModuleCache" \
  -I "$build_dir/modules" -L "$build_dir" -lLemmingsMobileCore \
  -Xlinker -rpath -Xlinker "$build_dir" -framework Network \
  "$project_dir/Sources/LemmingsMobileUI/TVGameImportServer.swift" \
  "$project_dir/Tests/LocalImportTransferTests/main.swift" -o "$build_dir/tests"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests"
