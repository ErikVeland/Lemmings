#!/bin/zsh
# Compile only the importer boundary against the unchanged local engine module.
set -euo pipefail
project_dir="${0:A:h:h:h}"
build_dir="$project_dir/.build/asset-parity-import"
engine_dir="$project_dir/.build/ultimate-lemmix-2.4.2-build107/arm64"
developer_dir=/Applications/Xcode.app/Contents/Developer
export PATH="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH"
export SDKROOT="$developer_dir/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
export LEMMINGS_TEST_AUDIO=muted
target="$(uname -m)-apple-macosx12.3"
mkdir -p "$build_dir/modules" "$build_dir/ModuleCache"
cp "$engine_dir/libNxlvKit.dylib" "$build_dir/libNxlvKit.dylib"
cp "$engine_dir/modules/"NxlvKit.swift* "$build_dir/modules/"
source_snapshot="$(mktemp -d "$build_dir/AppCoreSource.XXXXXX")"
cp -R "$project_dir/Sources/LemmingsAppCore/." "$source_snapshot/"
sources=("$source_snapshot"/**/*.swift(N))
shasum -a 256 "${sources[@]}" > "$build_dir/appcore-source-freeze.sha256"
swiftc -swift-version 6 -Onone -target "$target" -parse-as-library \
  -module-cache-path "$build_dir/ModuleCache" -emit-module -emit-library \
  -module-name LemmingsAppCore -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -emit-module-path "$build_dir/modules/LemmingsAppCore.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libLemmingsAppCore.dylib \
  -o "$build_dir/libLemmingsAppCore.dylib" "${sources[@]}"
swiftc -swift-version 6 -O -target "$target" -parse-as-library \
  -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/modules" -L "$build_dir" \
  -lLemmingsAppCore -lNxlvKit -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/OwnedResourceTests" "$project_dir/Tests/UltimateLemmixAssetParity/OwnedResourceTests.swift"
"$build_dir/OwnedResourceTests" "$build_dir/fixtures"
