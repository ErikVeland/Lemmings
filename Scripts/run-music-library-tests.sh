#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/music-library-tests"
mkdir -p "$build_dir/modules"
swiftc -swift-version 6 -warnings-as-errors -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib -o "$build_dir/libNxlvKit.dylib" \
  "$project_dir/Sources/NxlvKit/MusicLibraryCatalogue.swift" \
  "$project_dir/Sources/NxlvKit/MusicRhythmCatalogue.swift" \
  "$project_dir/Sources/NxlvKit/MusicTimingCatalogue.swift" \
  "$project_dir/Sources/NxlvKit/SoundtrackCatalogue.swift"
cat "$project_dir/Sources/LemmingsLocal/MusicLibrary.swift" \
  "$project_dir/Tests/MusicLibraryTests/main.swift" > "$build_dir/main.swift"
swiftc -swift-version 6 -warnings-as-errors -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" "$build_dir/main.swift" -o "$build_dir/tests"
"$build_dir/tests" "$project_dir"
python3 "$project_dir/Tests/MusicLibraryTests/check-packs.py"
