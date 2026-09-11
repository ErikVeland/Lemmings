#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
library_dir="${1:-$project_dir/.build/local/$(uname -m)}"
build_dir="$project_dir/.build/fan-catalog"
mkdir -p "$build_dir"
swiftc -O -swift-version 6 -I "$library_dir/modules" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" -o "$build_dir/Index" \
  "$project_dir/Tools/FanLevelCatalog/main.swift" "$project_dir/Sources/LemmingsLocal/FanLevelLibrary.swift"
"$build_dir/Index" "$project_dir/Content/LevelPacks"
