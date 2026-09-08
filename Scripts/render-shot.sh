#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/shot"
mkdir -p "$build_dir/modules"

swiftc -swift-version 6 -parse-as-library \
  -emit-module -emit-library \
  -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib -Xlinker -w \
  -o "$build_dir/libNxlvKit.dylib" \
  "$project_dir"/Sources/NxlvKit/*.swift

swiftc -swift-version 6 \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -framework AppKit -framework Metal -framework QuartzCore \
  -Xlinker -rpath -Xlinker "$build_dir" -Xlinker -w \
  -o "$build_dir/LemmingsShot" \
  "$project_dir/Sources/LemmingsLocal/PlayfieldView.swift" \
  "$project_dir/Sources/LemmingsLocal/ExplosionHDR.swift" \
  "$project_dir/Sources/LemmingsLocal/MacInterfaceRenderer.swift" \
  "$project_dir/Sources/LemmingsLocal/PanelView.swift" \
  "$project_dir/Sources/LemmingsLocal/PanelGlyphs.swift" \
  "$project_dir/Sources/LemmingsLocal/GameSession.swift" \
  "$project_dir/Sources/LemmingsLocal/CRTShaders.swift" \
  "$project_dir/Sources/LemmingsLocal/CRTView.swift" \
  "$project_dir/Tools/LemmingsShot/main.swift"

"$build_dir/LemmingsShot" "$@"
