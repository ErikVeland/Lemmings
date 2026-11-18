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
if [[ "${LEMMINGS_GAME_ART_ONLY:-0}" != 1 ]]; then
for shared_module in LemmingsAppCore LemmingsAudio LemmingsMobileCore LemmingsTVCore; do
  [[ "${LEMMINGS_APP_CORE_ONLY:-0}" == 1 && "$shared_module" != LemmingsAppCore ]] && continue
  dependencies=(-lNxlvKit)
  [[ "$shared_module" == LemmingsAudio ]] && dependencies+=(-lLemmingsAppCore)
  [[ "$shared_module" == LemmingsMobileCore ]] && dependencies+=(-lLemmingsAppCore)
  [[ "$shared_module" == LemmingsTVCore ]] && dependencies+=(-lLemmingsAppCore -lLemmingsMobileCore)
  print "Compiling shared module: $shared_module"
  sources=("$project_dir"/Sources/$shared_module/**/*.swift(N))
  "${SWIFTC:-swiftc}" -swift-version 6 "${compatibility[@]}" "$@" -target "$target" -parse-as-library \
    -emit-module -emit-library -module-name "$shared_module" \
    -I "$module_dir" -L "$library_dir" "${dependencies[@]}" \
    -emit-module-path "$module_dir/$shared_module.swiftmodule" \
    -Xlinker -install_name -Xlinker "@rpath/lib$shared_module.dylib" \
    -o "$library_dir/lib$shared_module.dylib" "${sources[@]}"
done
fi
[[ "${LEMMINGS_APP_CORE_ONLY:-0}" == 1 || "${LEMMINGS_SKIP_GAME_ART_BUILD:-0}" == 1 ]] && exit 0
"${SWIFTC:-swiftc}" -swift-version 6 "${compatibility[@]}" "$@" -target "$target" -parse-as-library \
  -emit-module -emit-library -module-name LemmingsGameArt \
  -I "$module_dir" -L "$library_dir" -lNxlvKit -lLemmingsAppCore -lLemmingsMobileCore -lLemmingsTVCore \
  -emit-module-path "$module_dir/LemmingsGameArt.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libLemmingsGameArt.dylib \
  -o "$library_dir/libLemmingsGameArt.dylib" "$project_dir"/Sources/LemmingsGameArt/**/*.swift(N)
