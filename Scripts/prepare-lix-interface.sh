#!/bin/zsh
# Rasterise only the pinned licensed Lix font for the existing shared interface renderer.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/lix-interface-export"
mkdir -p "$build_dir/ModuleCache"
compiler=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk
"$compiler" -swift-version 6 -O -sdk "$sdk" -module-cache-path "$build_dir/ModuleCache" \
  -framework CoreGraphics -framework CoreText -o "$build_dir/export" \
  "$project_dir/Sources/LemmingsGameArt/LixInterfaceText.swift" "$project_dir/Tools/LixInterface/main.swift"
"$build_dir/export" "$@"
