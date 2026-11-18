#!/bin/zsh
# Read local fixture bytes without executing the supplied preservation app.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/native-cursor-recovery-tests"
mkdir -p "$build_dir/ModuleCache"
compiler=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk
"$compiler" -swift-version 6 -warnings-as-errors -sdk "$sdk" -module-cache-path "$build_dir/ModuleCache" \
  -o "$build_dir/tests" "$project_dir/Sources/LemmingsLocal/NativeCursorRecovery.swift" \
  "$project_dir/Tests/NativeCursorRecoveryTests/main.swift"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests"
