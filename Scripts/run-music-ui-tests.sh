#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
app_root="${LEMMINGS_TEST_APP:-$project_dir/.build/music-1.6-app/Ultimate Lemmings.app}"
module_root="${app_root:h}/$(uname -m)"
build_dir="$project_dir/.build/music-ui-tests"
test_app="$build_dir/MusicUI.app"
[[ -f "$module_root/modules/NxlvKit.swiftmodule" && -d "$app_root/Contents/Resources/MacArtwork" ]] || {
  print -u2 'Build the local app first and set LEMMINGS_TEST_APP to its path.'; exit 1
}
mkdir -p "$test_app/Contents/MacOS"
ln -sfn "$app_root/Contents/Resources" "$test_app/Contents/Resources"
cat > "$test_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.ultimatelemmings.music-ui-tests</string><key>CFBundleExecutable</key><string>Tests</string></dict></plist>
PLIST
cat Sources/LemmingsLocal/SettingsWindow.swift Sources/LemmingsLocal/MusicLibraryWindow.swift \
  Sources/LemmingsLocal/AppUpdates.swift \
  Sources/LemmingsLocal/Lemmings2PlayWindow.swift Sources/LemmingsLocal/Lemmings3PlayWindow.swift \
  Tests/MusicUITests/checks.swift > "$build_dir/main.swift"
app_sources=(Sources/LemmingsLocal/*.swift)
for omitted in main.swift AppUpdates.swift SettingsWindow.swift MusicLibraryWindow.swift Lemmings2PlayWindow.swift Lemmings3PlayWindow.swift; do
  app_sources=("${(@)app_sources:#*/$omitted}")
done
swiftc -Onone -swift-version 6 -target "$(uname -m)-apple-macos12.3" \
  -F "$app_root/Contents/Frameworks" -framework Sparkle \
  -I "$module_root/modules" -L "$module_root" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$module_root" -Xlinker -rpath -Xlinker "$app_root/Contents/Frameworks" -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  -o "$test_app/Contents/MacOS/Tests" "$build_dir/main.swift" "${app_sources[@]}"
python3 Tools/UITestRunner/run.py "$test_app/Contents/MacOS/Tests"
