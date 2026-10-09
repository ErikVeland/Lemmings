#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/music-playback-tests"
mkdir -p "$build_dir/modules"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$build_dir/ModuleCache" -parse-as-library -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib -o "$build_dir/libNxlvKit.dylib" \
  "$project_dir/Sources/NxlvKit/MusicPlaybackCatalogue.swift" "$project_dir/Sources/NxlvKit/SoundtrackCatalogue.swift"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" -o "$build_dir/MusicPlaybackTests" \
  "$project_dir/Tests/MusicPlaybackTests/main.swift"
"$build_dir/MusicPlaybackTests" "$project_dir/Resources/Music/recording-playback.json"
python3 "$project_dir/Tests/MusicPlaybackTests/check-assets.py"
cat "$project_dir/Sources/LemmingsLocal/MusicFileDeck.swift" \
  "$project_dir/Tests/MusicPlaybackTests/offline.swift" > "$build_dir/offline-main.swift"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" -framework AVFoundation \
  -o "$build_dir/OfflineMusicPlaybackTests" "$build_dir/offline-main.swift"
LEMMINGS_TEST_AUDIO=muted python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/OfflineMusicPlaybackTests"
