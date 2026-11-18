#!/bin/zsh
# Rasterise only the pinned licensed Lix font for the existing shared interface renderer.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/lix-interface-export"
mkdir -p "$build_dir/ModuleCache"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
compiler="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
sdk="${SDKROOT:-$(DEVELOPER_DIR="$developer_dir" xcrun --sdk macosx --show-sdk-path)}"
"$compiler" -swift-version 6 -O -sdk "$sdk" -target "$(uname -m)-apple-macosx12.3" \
  -module-cache-path "$build_dir/ModuleCache" \
  -framework CoreGraphics -framework CoreText -o "$build_dir/export" \
  "$project_dir/Sources/NxlvKit/LixInterfaceText.swift" "$project_dir/Tools/LixInterface/main.swift"
"$build_dir/export" "$@"
