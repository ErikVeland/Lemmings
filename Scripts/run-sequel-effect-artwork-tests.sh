#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/sequel-effect-artwork"
mkdir -p "$build_dir/ModuleCache"
cd "$project_dir"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$build_dir/ModuleCache" -framework AppKit \
  -o "$build_dir/tests" \
  Sources/LemmingsLocal/SequelEffectArtwork.swift \
  Tests/SequelEffectArtworkTests/main.swift
python3 Tools/UITestRunner/run.py "$build_dir/tests"
