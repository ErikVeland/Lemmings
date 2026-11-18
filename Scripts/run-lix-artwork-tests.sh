#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/lix-artwork-tests"
core_modules="$build_dir/modules"
core_library="$build_dir"
if [[ -n "${ULTIMATE_LEMMIX_CORE_BUILD_DIR:-}" ]]; then
  build_dir="$project_dir/.build/lix-artwork-packaged-core-tests"
  core_modules="$ULTIMATE_LEMMIX_CORE_BUILD_DIR/$(uname -m)/modules"
  core_library="$ULTIMATE_LEMMIX_CORE_BUILD_DIR/Ultimate Lemmix.app/Contents/Frameworks"
fi
mobile_rpath=()
[[ "$core_library" == "$build_dir" ]] || mobile_rpath=(-Xlinker -rpath -Xlinker "$build_dir")
pack="${LIX_ARTWORK_PACK:-$project_dir/.build/alternative-assets/lix}"
swift_compiler="${LEMMINGS_SWIFTC:-/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc}"
sdk_dir="${LEMMINGS_MACOS_SDK:-/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk}"
if [[ ! -x "$swift_compiler" ]]; then swift_compiler="$(xcrun --find swiftc)"; fi
if [[ ! -d "$sdk_dir" ]]; then sdk_dir="$(xcrun --sdk macosx --show-sdk-path)"; fi
export LEMMINGS_TEST_WINDOWS=offscreen
export LEMMINGS_TEST_AUDIO=muted
mkdir -p "$build_dir/modules"
if [[ -z "${ULTIMATE_LEMMIX_CORE_BUILD_DIR:-}" ]]; then
"$swift_compiler" -sdk "$sdk_dir" -target "$(uname -m)-apple-macosx12.3" \
  -swift-version 6 -warnings-as-errors -parse-as-library -emit-module -emit-library \
  -module-cache-path "$build_dir/ModuleCache" \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -framework CoreGraphics -framework ImageIO \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
fi
"$swift_compiler" -sdk "$sdk_dir" -target "$(uname -m)-apple-macosx12.3" \
  -swift-version 6 -warnings-as-errors -I "$core_modules" -L "$core_library" -lNxlvKit \
  -module-cache-path "$build_dir/ModuleCache" -framework CoreGraphics -framework ImageIO \
  -Xlinker -rpath -Xlinker "$core_library" \
  "$project_dir/Tests/LixArtworkTests/main.swift" -o "$build_dir/tests"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests" "$pack" "$build_dir"
"$swift_compiler" -sdk "$sdk_dir" -target "$(uname -m)-apple-macosx12.3" \
  -swift-version 6 -warnings-as-errors -parse-as-library -emit-module -emit-library \
  -I "$core_modules" -L "$core_library" -lNxlvKit \
  -module-cache-path "$build_dir/ModuleCache" -module-name LemmingsMobileCore \
  -emit-module-path "$build_dir/modules/LemmingsMobileCore.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libLemmingsMobileCore.dylib \
  -Xlinker -rpath -Xlinker "$core_library" \
  -o "$build_dir/libLemmingsMobileCore.dylib" "$project_dir"/Sources/LemmingsMobileCore/*.swift
"$swift_compiler" -sdk "$sdk_dir" -target "$(uname -m)-apple-macosx12.3" \
  -swift-version 6 -warnings-as-errors -parse-as-library -DMOBILE_CLEAN_CONTENT_STANDALONE \
  -I "$core_modules" -I "$build_dir/modules" -L "$core_library" -L "$build_dir" -lNxlvKit -lLemmingsMobileCore \
  -module-cache-path "$build_dir/ModuleCache" -framework CoreGraphics -framework ImageIO \
  -Xlinker -rpath -Xlinker "$core_library" "${mobile_rpath[@]}" \
  "$project_dir/Tests/LemmingsMobileCoreTests/CleanContentTests.swift" -o "$build_dir/mobile-tests"
LIX_ARTWORK_PACK="$pack" python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/mobile-tests"
