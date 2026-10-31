#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/mobile-deferred-preparation-tests"
mkdir -p "$build_dir"
swiftc -parse-as-library -swift-version 6 -warnings-as-errors \
  -target "$(uname -m)-apple-macos12.3" \
  "$project_dir/Sources/LemmingsMobileCore/MobileDeferredPreparation.swift" \
  "$project_dir/Tests/MobileDeferredPreparationTests/main.swift" \
  -o "$build_dir/tests"
LEMMINGS_TEST_AUDIO=muted LEMMINGS_TEST_WINDOWS=offscreen \
  python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests"
