#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/crt-probe"
mkdir -p "$build_dir"
swiftc -swift-version 6 -framework Metal -Xlinker -w \
  -o "$build_dir/CRTProbe" \
  "$project_dir/Sources/LemmingsLocal/CRTShaders.swift" \
  "$project_dir/Tools/CRTProbe/main.swift"
"$build_dir/CRTProbe"
