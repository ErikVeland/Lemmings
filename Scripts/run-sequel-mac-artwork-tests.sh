#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/sequel-mac-artwork"
mkdir -p "$build_dir/modules" "$build_dir/app-test"
cd "$project_dir"
swiftc -O -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos13.0" \
  -parse-as-library -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos13.0" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" -o "$build_dir/tests" Tests/SequelMacArtworkTests/main.swift
"$build_dir/tests" "$@"
cat Sources/LemmingsLocal/Lemmings2PlayWindow.swift Sources/LemmingsLocal/Lemmings3PlayWindow.swift \
  Sources/LemmingsLocal/SettingsWindow.swift \
  Tests/SequelMacArtworkAppTests/checks.swift > "$build_dir/app-test/main.swift"
app_sources=(Sources/LemmingsLocal/*.swift)
app_sources=("${(@)app_sources:#*/main.swift}")
app_sources=("${(@)app_sources:#*/Lemmings2PlayWindow.swift}")
app_sources=("${(@)app_sources:#*/Lemmings3PlayWindow.swift}")
app_sources=("${(@)app_sources:#*/SettingsWindow.swift}")
swiftc -O -swift-version 6 -target "$(uname -m)-apple-macos13.0" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  -o "$build_dir/app-test/Views" "$build_dir/app-test/main.swift" "${app_sources[@]}"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/app-test/Views"
