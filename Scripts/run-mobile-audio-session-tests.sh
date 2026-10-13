#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/mobile-audio-session"
mkdir -p "$build_dir/ModuleCache"
cd "$project_dir"
export LEMMINGS_TEST_AUDIO=muted
export LEMMINGS_TEST_WINDOWS=offscreen
swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -target "$(uname -m)-apple-macos12.3" -module-cache-path "$build_dir/ModuleCache" \
  Sources/LemmingsMobileUI/MobileAudioSessionRequests.swift \
  Tests/MobileAudioSessionTests/main.swift -o "$build_dir/checks"
"$build_dir/checks"
