#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/playfield-draw-tests"
mkdir -p "$build_dir/modules"

swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift

swiftc -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/PlayfieldDrawTests" \
  "$project_dir/Sources/LemmingsLocal/GameCursor.swift" \
  "$project_dir/Sources/LemmingsLocal/SkillCursorBadge.swift" \
  "$project_dir/Sources/LemmingsLocal/ControllerPointer.swift" \
  "$project_dir/Sources/LemmingsLocal/LemmingFocusHighlight.swift" \
  "$project_dir/Sources/LemmingsLocal/LemmingAssignmentPulse.swift" \
  "$project_dir/Sources/LemmingsLocal/FailureMood.swift" \
  "$project_dir/Sources/LemmingsLocal/RewindTransportCue.swift" \
  "$project_dir/Sources/LemmingsLocal/GameplayPresentation.swift" \
  "$project_dir/Sources/LemmingsLocal/PlayfieldView.swift" \
  "$project_dir/Sources/LemmingsLocal/ExplosionHDR.swift" \
  "$project_dir/Sources/LemmingsLocal/MacInterfaceRenderer.swift" \
  "$project_dir/Sources/LemmingsLocal/GameMenuArtwork.swift" \
  "$project_dir/Sources/LemmingsLocal/PanelView.swift" \
  "$project_dir/Sources/LemmingsLocal/PanelGlyphs.swift" \
  "$project_dir/Sources/LemmingsLocal/RunRecovery.swift" \
  "$project_dir/Sources/LemmingsLocal/GameSession.swift" \
  "$project_dir/Tests/PlayfieldDrawTests/main.swift"
"$build_dir/PlayfieldDrawTests"
