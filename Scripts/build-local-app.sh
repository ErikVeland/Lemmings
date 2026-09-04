#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/local"
app_dir="$build_dir/Lemmings Local.app"
contents_dir="$app_dir/Contents"
deployment_target="13.0"
architectures=(arm64 x86_64)

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources" "$contents_dir/Frameworks"

library_inputs=()
executable_inputs=()
for architecture in "${architectures[@]}"; do
  architecture_dir="$build_dir/$architecture"
  module_dir="$architecture_dir/modules"
  mkdir -p "$module_dir"
  target="$architecture-apple-macosx$deployment_target"

  swiftc -swift-version 6 -target "$target" -parse-as-library \
    -module-cache-path "$build_dir/ModuleCache" \
    -emit-module -emit-library \
    -module-name NxlvKit \
    -emit-module-path "$module_dir/NxlvKit.swiftmodule" \
    -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib -Xlinker -w \
    -o "$architecture_dir/libNxlvKit.dylib" \
    "$project_dir"/Sources/NxlvKit/*.swift

  swiftc -swift-version 6 -target "$target" \
    -module-cache-path "$build_dir/ModuleCache" \
    -I "$module_dir" -L "$architecture_dir" -lNxlvKit \
    -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks -Xlinker -w \
    -o "$architecture_dir/LemmingsLocal" \
    "$project_dir"/Sources/LemmingsLocal/*.swift

  library_inputs+=("$architecture_dir/libNxlvKit.dylib")
  executable_inputs+=("$architecture_dir/LemmingsLocal")
done

lipo -create "${library_inputs[@]}" -output "$contents_dir/Frameworks/libNxlvKit.dylib"
lipo -create "${executable_inputs[@]}" -output "$contents_dir/MacOS/LemmingsLocal"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
zsh "$project_dir/Scripts/bundle-game-data.sh" "$contents_dir/Resources" all

# Seal the finished bundle after resources are copied. This local ad-hoc
# signature is replaced by a Developer ID signature for distribution builds.
codesign --force --deep --sign - "$app_dir"

echo "$app_dir"
