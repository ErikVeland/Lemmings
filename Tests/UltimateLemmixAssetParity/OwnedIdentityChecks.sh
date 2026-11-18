#!/bin/zsh
# No existing script builds only fresh AppCore and MobileCore for this contract.
set -euo pipefail
project_dir="${0:A:h:h:h}"
build_dir="$project_dir/.build/asset-parity-identity"
engine_dir="$project_dir/.build/ultimate-lemmix-2.4.2-build107/arm64"
developer_dir=/Applications/Xcode.app/Contents/Developer
export PATH="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH"
export SDKROOT="$developer_dir/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
export LEMMINGS_TEST_AUDIO=muted
target="$(uname -m)-apple-macosx12.3"
mkdir -p "$build_dir/modules" "$build_dir/ModuleCache"
cp "$engine_dir/libNxlvKit.dylib" "$build_dir/"
cp "$engine_dir/modules/"NxlvKit.swift* "$build_dir/modules/"
source_snapshot="$(mktemp -d "$build_dir/Source.XXXXXX")"
for name in LemmingsAppCore LemmingsMobileCore; do
  cp -R "$project_dir/Sources/$name" "$source_snapshot/"
done
sources=("$source_snapshot"/**/*.swift(N))
shasum -a 256 "${sources[@]}" > "$build_dir/source-freeze.sha256"
for name in LemmingsAppCore LemmingsMobileCore; do
  sources=("$source_snapshot/$name"/**/*.swift(N))
  dependencies=(-lNxlvKit)
  [[ "$name" == LemmingsMobileCore ]] && dependencies+=(-lLemmingsAppCore)
  swiftc -swift-version 6 -Onone -target "$target" -parse-as-library \
    -module-cache-path "$build_dir/ModuleCache" -emit-module -emit-library -module-name "$name" \
    -I "$build_dir/modules" -L "$build_dir" "${dependencies[@]}" \
    -emit-module-path "$build_dir/modules/$name.swiftmodule" \
    -Xlinker -install_name -Xlinker "@rpath/lib$name.dylib" \
    -o "$build_dir/lib$name.dylib" "${sources[@]}"
done
swiftc -swift-version 6 -O -target "$target" -parse-as-library \
  -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/modules" -L "$build_dir" \
  -lLemmingsAppCore -lLemmingsMobileCore -lNxlvKit -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/OwnedIdentityTests" "$project_dir/Tests/UltimateLemmixAssetParity/OwnedIdentityTests.swift"
"$build_dir/OwnedIdentityTests" "$build_dir/fixtures" "$1" "$2"
