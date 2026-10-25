#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
build_dir="$project_dir/.build/stone-button-art"
mkdir -p "$build_dir/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$build_dir/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$build_dir/ModuleCache"
if [[ "${STONE_ART_SKIP_BUILD:-0}" != 1 ]]; then
  swift build --disable-sandbox --disable-automatic-resolution --target LemmingsGameArt -j 4
fi
debug_dir="$project_dir/.build/debug"
test_app="$build_dir/StoneButtonAudit.app"
mkdir -p "$test_app/Contents/MacOS" "$test_app/Contents/Resources"
ln -sfn "$project_dir/.build/mac-artwork/export" "$test_app/Contents/Resources/MacArtwork"
ln -sfn "$debug_dir/LemmingsNativePort_NxlvKit.bundle" "$test_app/Contents/Resources/LemmingsNativePort_NxlvKit.bundle"
objects=()
module_dir="$debug_dir/Modules"
for module in NxlvKit LemmingsAppCore LemmingsMobileCore LemmingsTVCore LemmingsGameArt; do
  if [[ -f "$debug_dir/$module.o" ]]; then
    objects+=("$debug_dir/$module.o")
    module_dir="$debug_dir"
  else
    objects+=("$debug_dir/$module.build/"*.swift.o)
  fi
done
swiftc -swift-version 6 -parse-as-library -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$build_dir/ModuleCache" -I "$module_dir" \
  -framework AppKit -framework CoreGraphics -framework ImageIO \
  "$project_dir/Sources/LemmingsLocal/PanelGlyphs.swift" \
  "$project_dir"/Tests/StoneButtonArtTests/*.swift "${objects[@]}" \
  -o "$test_app/Contents/MacOS/StoneButtonAudit"
python3 "$project_dir/Tools/UITestRunner/run.py" "$test_app/Contents/MacOS/StoneButtonAudit" "$build_dir/renders"
