#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/user-resource-access-tests"
mkdir -p "$build_dir/ModuleCache"
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc \
  -swift-version 6 -warnings-as-errors -parse-as-library \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk \
  -target "$(uname -m)-apple-macosx12.3" \
  -module-cache-path "$build_dir/ModuleCache" -o "$build_dir/tests" \
  "$project_dir/Sources/LemmingsLocal/UserResourceAccess.swift" \
  "$project_dir/Tests/UserResourceAccessTests/main.swift"
"$build_dir/tests"
