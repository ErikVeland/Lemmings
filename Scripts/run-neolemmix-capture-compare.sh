#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/neolemmix-capture-compare"

if (( $# != 2 )); then
  print -u2 "Usage: $0 <native-capture-directory> <ce-capture-directory>"
  exit 2
fi

mkdir -p "$build_dir"
swiftc -swift-version 6 -warnings-as-errors \
  -framework CoreGraphics -framework ImageIO \
  -o "$build_dir/NeoLemmixCaptureCompare" \
  "$project_dir/Tools/NeoLemmixCaptureCompare/main.swift"

"$build_dir/NeoLemmixCaptureCompare" "$@"
