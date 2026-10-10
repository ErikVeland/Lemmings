#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/classic-progression-audit"
mkdir -p "$build_dir/modules" "$build_dir/source"
cp "$project_dir"/Sources/NxlvKit/*.swift "$build_dir/source/"
shasum -a 256 "$build_dir"/source/*.swift > "$build_dir/source-manifest.sha256"
export DIFFICULTY_SIMULATION_REVISION="$(shasum -a 256 "$build_dir/source-manifest.sha256" | cut -d ' ' -f 1)"
swiftc -O -swift-version 6 -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$build_dir"/source/*.swift
swiftc -O -swift-version 6 -parse-as-library -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  "$project_dir/Tools/DifficultyDiagnostics/ClassicCorpus.swift" \
  "$project_dir/Sources/LemmingsLocal/GameAssetCache.swift" \
  "$project_dir/Sources/LemmingsLocal/FanLevelLibrary.swift" \
  "$project_dir/Sources/LemmingsLocal/LevelPlaylistStore.swift" \
  -o "$build_dir/ClassicCorpus"
shasum -a 256 "$project_dir/Tools/DifficultyDiagnostics/ClassicCorpus.swift" \
  "$project_dir/Sources/LemmingsLocal/GameAssetCache.swift" \
  "$project_dir/Sources/LemmingsLocal/FanLevelLibrary.swift" \
  "$project_dir/Sources/LemmingsLocal/LevelPlaylistStore.swift" > "$build_dir/adapter-manifest.sha256"
python3 "$project_dir/Tools/DifficultyDiagnostics/classic_fan_replays.py" "$1/LevelPacks" "$3"
"$build_dir/ClassicCorpus" "${@:1:3}"
CLASSIC_AUDIT_REBUILD=1 "$build_dir/ClassicCorpus" "$@"
python3 "$project_dir/Tools/DifficultyDiagnostics/classic_report.py" "$3"
