#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
test_arch="${TEST_ARCH:-$(uname -m)}"
[[ "$test_arch" == arm64 || "$test_arch" == x86_64 ]] || exit 1
build_dir="$project_dir/.build/app-integration-tests-$test_arch"
mkdir -p "$build_dir/modules"
sparkle_framework="$(SPARKLE_FRAMEWORK_PATH="${SPARKLE_FRAMEWORK_PATH:-}" \
  LEMMINGS_BUILD_ROOT="$build_dir/dependencies" \
  zsh "$project_dir/Scripts/ensure-sparkle.sh")"
sparkle_framework_dir="${sparkle_framework:h}"
compatibility=()
[[ "$test_arch" == x86_64 ]] && compatibility=(-runtime-compatibility-version none)
optimization_flags=()
if [[ "${TEST_SCOPE:-all}" == performance || "${TEST_OPTIMIZE:-0}" == 1 ]]; then optimization_flags=(-O); fi
swiftc -swift-version 6 "${compatibility[@]}" "${optimization_flags[@]}" -target "$test_arch-apple-macos12.3" -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
# Keep the checks in the same file so production members can remain private.
cat "$project_dir/Sources/LemmingsLocal/main.swift" \
  "$project_dir/Tests/AppIntegrationTests/checks.swift" > "$build_dir/main.swift"
sources=("$project_dir"/Sources/LemmingsLocal/*.swift)
sources=("${(@)sources:#*/main.swift}")
test_app="$build_dir/AppIntegrationTests.app"
mkdir -p "$test_app/Contents/MacOS" "$test_app/Contents/Frameworks"
cp "$project_dir/Resources/Info.plist" "$test_app/Contents/Info.plist"
rsync -a --delete "$sparkle_framework" "$test_app/Contents/Frameworks/"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable AppIntegrationTests' "$test_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Lemmings Integration Tests ($test_arch)" "$test_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Lemmings Integration Tests ($test_arch)" "$test_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconFile' "$test_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier academy.glasscode.lemmings.integration-tests.$test_arch" "$test_app/Contents/Info.plist"
resource_app="${LEMMINGS_TEST_APP:-$project_dir/.build/local/Ultimate Lemmings.app}"
ln -sfn "$resource_app/Contents/Resources" "$test_app/Contents/Resources"
test_flags=()
if [[ "${TEST_SCOPE:-all}" == dialogs ]]; then test_flags+=(-D DIALOG_TESTS); fi
if [[ "${TEST_SCOPE:-all}" == transport ]]; then test_flags+=(-D TRANSPORT_TESTS); fi
if [[ "${TEST_SCOPE:-all}" == loading-latency ]]; then test_flags+=(-D LOADING_LATENCY_TESTS); fi
if [[ "${TEST_SCOPE:-all}" == cursor-input ]]; then test_flags+=(-D CURSOR_INPUT_TESTS); fi
if [[ "${TEST_SCOPE:-all}" == hot-seat ]]; then test_flags+=(-D HOT_SEAT_TESTS); fi
if [[ "${TEST_SCOPE:-all}" == hd-effects ]]; then test_flags+=(-D HD_EFFECTS_TESTS); fi
if [[ "${TEST_SCOPE:-all}" == variable-speed ]]; then test_flags+=(-D VARIABLE_SPEED_TESTS); fi
if [[ "${TEST_SCOPE:-all}" == performance ]]; then test_flags+=(-D PERFORMANCE_TESTS); fi
if [[ "${TEST_SCOPE:-all}" == release-blockers ]]; then test_flags+=(-D RELEASE_BLOCKER_TESTS); fi
if [[ "${TEST_SCOPE:-all}" == hints ]]; then test_flags+=(-D HINT_TESTS); fi
if [[ "${TEST_SCOPE:-all}" == controller ]]; then test_flags+=(-D CONTROLLER_QOL_TESTS); fi
if [[ "${TEST_SCOPE:-all}" == content-browser ]]; then test_flags+=(-D CONTENT_BROWSER_TESTS); fi
swiftc -swift-version 6 "${compatibility[@]}" "${optimization_flags[@]}" -target "$test_arch-apple-macos12.3" -D APP_INTEGRATION_TESTS "${test_flags[@]}" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -F "$sparkle_framework_dir" -framework Sparkle \
  -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  -o "$test_app/Contents/MacOS/AppIntegrationTests" "${sources[@]}" "$build_dir/main.swift"
if [[ "${TEST_COMPILE_ONLY:-0}" == 1 ]]; then
  print "PASS app integration test compilation only ($test_arch, ${TEST_SCOPE:-all})."
  print "The app, bundled content and input flows were not run."
  exit 0
fi
cd "$project_dir"
python3 "$project_dir/Tools/UITestRunner/run.py" arch "-$test_arch" "$test_app/Contents/MacOS/AppIntegrationTests"
