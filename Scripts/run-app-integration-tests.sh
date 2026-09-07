#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
test_arch="${TEST_ARCH:-$(uname -m)}"
[[ "$test_arch" == arm64 || "$test_arch" == x86_64 ]] || exit 1
build_dir="$project_dir/.build/app-integration-tests-$test_arch"
mkdir -p "$build_dir/modules"
swiftc -swift-version 6 -target "$test_arch-apple-macos13.0" -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
# Keep the checks in the same file so production members can remain private.
cat "$project_dir/Sources/LemmingsLocal/main.swift" \
  "$project_dir/Tests/AppIntegrationTests/checks.swift" > "$build_dir/main.swift"
sources=("$project_dir"/Sources/LemmingsLocal/*.swift)
sources=("${(@)sources:#*/main.swift}")
test_app="$build_dir/AppIntegrationTests.app"
mkdir -p "$test_app/Contents/MacOS"
cp "$project_dir/Resources/Info.plist" "$test_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable AppIntegrationTests' "$test_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier academy.glasscode.lemmings.integration-tests.$test_arch" "$test_app/Contents/Info.plist"
ln -sfn "$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources" "$test_app/Contents/Resources"
swiftc -swift-version 6 -target "$test_arch-apple-macos13.0" -D APP_INTEGRATION_TESTS \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$test_app/Contents/MacOS/AppIntegrationTests" "${sources[@]}" "$build_dir/main.swift"
cd "$project_dir"
arch "-$test_arch" "$test_app/Contents/MacOS/AppIntegrationTests"
