#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/rewind-feedback"
module_dir="$build_dir/modules"
mkdir -p "$module_dir" "$build_dir/ModuleCache"
cd "$project_dir"
export LEMMINGS_TEST_AUDIO=muted
export LEMMINGS_TEST_WINDOWS=offscreen
target="$(uname -m)-apple-macos12.3"
swiftc -swift-version 6 -target "$target" -parse-as-library \
  -module-cache-path "$build_dir/ModuleCache" -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$module_dir/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
zsh Scripts/build-shared-modules.sh "$module_dir" "$build_dir" "$target" \
  -module-cache-path "$build_dir/ModuleCache"
sparkle="$(LEMMINGS_BUILD_ROOT="$build_dir/dependencies" zsh Scripts/ensure-sparkle.sh)"
swiftc -swift-version 6 -target "$target" -typecheck \
  -module-cache-path "$build_dir/ModuleCache" -I "$module_dir" -F "${sparkle:h}" \
  Sources/LemmingsLocal/*.swift
cat Sources/LemmingsLocal/Lemmings2PlayWindow.swift Sources/LemmingsLocal/Lemmings3PlayWindow.swift \
  Tests/RewindFeedbackTests/checks.swift > "$build_dir/main.swift"
app_sources=(Sources/LemmingsLocal/*.swift)
app_sources=("${(@)app_sources:#*/main.swift}")
app_sources=("${(@)app_sources:#*/Lemmings2PlayWindow.swift}")
app_sources=("${(@)app_sources:#*/Lemmings3PlayWindow.swift}")
swiftc -swift-version 6 -target "$target" -module-cache-path "$build_dir/ModuleCache" \
  -I "$module_dir" -L "$build_dir" -lNxlvKit -lLemmingsAppCore -lLemmingsAudio -lLemmingsMobileCore -lLemmingsGameArt \
  -Xlinker -rpath -Xlinker "$build_dir" -F "${sparkle:h}" -framework Sparkle \
  -Xlinker -rpath -Xlinker "${sparkle:h}" \
  -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  "$build_dir/main.swift" "${app_sources[@]}" -o "$build_dir/views"
python3 Tools/UITestRunner/run.py "$build_dir/views"
cat Sources/LemmingsAudio/BufferedAudioSource.swift Sources/LemmingsAudio/SoundEffectPlayer.swift Tests/SpatialAudioTests/checks.swift > "$build_dir/main.swift"
swiftc -swift-version 6 -target "$target" -module-cache-path "$build_dir/ModuleCache" \
  -I "$module_dir" -L "$build_dir" -lNxlvKit -Xlinker -rpath -Xlinker "$build_dir" \
  "$build_dir/main.swift" -o "$build_dir/audio"
python3 Tools/UITestRunner/run.py "$build_dir/audio"
