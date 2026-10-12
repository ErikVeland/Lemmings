#!/bin/zsh
# Build shared Mac modules in dependency order. NxlvKit must already be built.
# Usage: build-shared-modules.sh MODULE_DIR LIBRARY_DIR TARGET [SWIFTC_FLAGS ...]
set -euo pipefail
project_dir="${0:A:h:h}"
module_dir="$1"
library_dir="$2"
target="$3"
shift 3
compatibility=()
[[ "$target" == x86_64-* ]] && compatibility=(-runtime-compatibility-version none)
for shared_module in LemmingsAppCore LemmingsAudio LemmingsMobileCore; do
  dependencies=(-lNxlvKit)
  [[ "$shared_module" == LemmingsMobileCore ]] && dependencies+=(-lLemmingsAppCore)
  sources=("$project_dir"/Sources/$shared_module/**/*.swift(N))
  swiftc -swift-version 6 "${compatibility[@]}" "$@" -target "$target" -parse-as-library \
    -emit-module -emit-library -module-name "$shared_module" \
    -I "$module_dir" -L "$library_dir" "${dependencies[@]}" \
    -emit-module-path "$module_dir/$shared_module.swiftmodule" \
    -Xlinker -install_name -Xlinker "@rpath/lib$shared_module.dylib" \
    -o "$library_dir/lib$shared_module.dylib" "${sources[@]}"
done
swiftc -swift-version 6 "${compatibility[@]}" "$@" -target "$target" -parse-as-library \
  -emit-module -emit-library -module-name LemmingsGameArt \
  -I "$module_dir" -L "$library_dir" -lNxlvKit -lLemmingsAppCore -lLemmingsMobileCore \
  -emit-module-path "$module_dir/LemmingsGameArt.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libLemmingsGameArt.dylib \
  -o "$library_dir/libLemmingsGameArt.dylib" "$project_dir"/Sources/LemmingsGameArt/*.swift
