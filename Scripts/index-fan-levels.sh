#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
library_dir="${1:-$project_dir/.build/local/$(uname -m)}"
build_dir="$project_dir/.build/fan-catalog"
architecture="${library_dir:t}"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
mkdir -p "$build_dir"
python3 "$project_dir/Tools/FanLevelCatalog/prune.py" "$project_dir/Content/LevelPacks" --apply
swiftc -O -swift-version 6 -sdk "$sdk_path" -target "$architecture-apple-macosx12.3" \
  -I "$library_dir/modules" -L "$library_dir" -lNxlvKit -lLemmingsAppCore \
  -Xlinker -rpath -Xlinker "$library_dir" -o "$build_dir/Index" \
  "$project_dir/Tools/FanLevelCatalog/main.swift" "$project_dir/Sources/LemmingsLocal/GameAssetCache.swift" \
  "$project_dir/Sources/LemmingsLocal/GameResources.swift" \
  "$project_dir/Sources/LemmingsLocal/FanLevelLibrary.swift"
"$build_dir/Index" "$project_dir/Content/LevelPacks"
