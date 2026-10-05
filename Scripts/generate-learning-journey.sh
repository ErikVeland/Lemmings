#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
swift build --target NxlvKit
product_dir="$(swift build --show-bin-path)"
build_dir="$project_dir/.build/learning-journey"
mkdir -p "$build_dir"
if [[ -f "$product_dir/NxlvKit.o" ]]; then
  module_dir="$product_dir"
  objects=("$product_dir/NxlvKit.o")
else
  module_dir="$product_dir/Modules"
  objects=("$product_dir"/NxlvKit.build/*.o)
fi
swiftc -swift-version 6 -I "$module_dir" "${objects[@]}" \
  "$project_dir/Tools/DifficultyDiagnostics/LearningJourney.swift" \
  -o "$build_dir/LearningJourneyTool"
LEARNING_EXPORT_POOL=1 "$build_dir/LearningJourneyTool" "$project_dir/Artifacts/ClassicProgression/audit.json" \
  "$project_dir/Resources/Progression/learning.json" \
  "$project_dir/Artifacts/LearningJourney/fan-evidence.json" \
  "$project_dir/Artifacts/LearningJourney/scenarios.json"

resources="${1:-$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources}"
swiftc -O -swift-version 6 -I "$module_dir" "${objects[@]}" \
  "$project_dir/Tools/DifficultyDiagnostics/JourneyResources/main.swift" \
  "$project_dir/Sources/LemmingsLocal/GameAssetCache.swift" \
  "$project_dir/Sources/LemmingsLocal/FanLevelLibrary.swift" \
  -o "$build_dir/JourneyResources"
"$build_dir/JourneyResources" "$build_dir/pool.json" "$resources" \
  "$project_dir/Artifacts/LearningJourney/source-resources.json"
python3 "$project_dir/Tools/DifficultyDiagnostics/human_journey.py"
