#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/keychain-tests"
export LEMMINGS_TEST_AUDIO=muted
export LEMMINGS_TEST_WINDOWS=offscreen
mkdir -p "$build_dir/ModuleCache"
swiftc -swift-version 6 -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$build_dir/ModuleCache" \
  "$project_dir/Sources/LemmingsAppCore/Records/BackgroundKeychain.swift" \
  "$project_dir/Tests/BackgroundKeychainTests/main.swift" -o "$build_dir/tests"
"$build_dir/tests"
