#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/lix-soundtrack-tests"
candidate="${ULTIMATE_LEMMIX_TEST_BUILD_DIR:-$project_dir/.build/ultimate-lemmix-app-store}"
architecture="$(uname -m)"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
compiler="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
sdk="$developer_dir/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
mkdir -p "$build_dir/ModuleCache"
export LEMMINGS_TEST_AUDIO=muted
export LEMMINGS_TEST_WINDOWS=offscreen
"$compiler" -swift-version 6 -sdk "$sdk" -target "$architecture-apple-macosx12.3" \
  -parse-as-library -module-cache-path "$build_dir/ModuleCache" \
  -I "$candidate/$architecture/modules" -L "$candidate/Ultimate Lemmix.app/Contents/Frameworks" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$candidate/Ultimate Lemmix.app/Contents/Frameworks" \
  "$project_dir/Sources/LemmingsLocal/LixSoundtrack.swift" \
  "$project_dir/Tests/LixSoundtrackTests/main.swift" -o "$build_dir/tests"
"$build_dir/tests" "$candidate/Ultimate Lemmix.app/Contents/Resources"
