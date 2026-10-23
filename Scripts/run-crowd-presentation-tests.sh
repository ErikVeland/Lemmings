#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
build_dir="$project_dir/.build/crowd-presentation"
mkdir -p "$build_dir/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$build_dir/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$build_dir/ModuleCache"
if [[ "${CROWD_SKIP_BUILD:-0}" != 1 ]]; then
  swift build --disable-sandbox --disable-automatic-resolution --target LemmingsGameArt -j 4
fi
module_dir="$project_dir/.build/debug"
ln -sfn "$module_dir/LemmingsNativePort_NxlvKit.bundle" "$build_dir/LemmingsNativePort_NxlvKit.bundle"
objects=()
for module in NxlvKit LemmingsAppCore LemmingsMobileCore LemmingsTVCore LemmingsGameArt; do
  if [[ -f "$module_dir/$module.o" ]]; then
    objects+=("$module_dir/$module.o")
  else
    objects+=("$module_dir/$module.build/"*.swift.o)
  fi
done
[[ -d "$module_dir/Modules" ]] && module_dir="$module_dir/Modules"
swiftc -swift-version 6 -warnings-as-errors -parse-as-library -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$build_dir/ModuleCache" -I "$module_dir" \
  -framework AppKit -framework Metal -framework QuartzCore \
  Sources/LemmingsLocal/LemmingCrowdPresentation.swift Tests/CrowdPresentationTests/main.swift \
  "${objects[@]}" -o "$build_dir/CrowdAudit"
python3 Tools/UITestRunner/run.py "$build_dir/CrowdAudit"
