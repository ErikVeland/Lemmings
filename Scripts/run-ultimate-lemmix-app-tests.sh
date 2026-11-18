#!/bin/zsh
# Exercise the clean Mac app through silent, offscreen native captures.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/ultimate-lemmix-app-tests"
candidate_root="${ULTIMATE_LEMMIX_BUILD_DIR:-$project_dir/.build/ultimate-lemmix-app-store}"
candidate_root="${candidate_root:A}"
candidate="$candidate_root/Ultimate Lemmix.app"
architecture="$(uname -m)"
module_dir="$candidate_root/$architecture/modules"
framework_dir="$candidate/Contents/Frameworks"
compiler=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk
[[ -x "$compiler" && -d "$sdk" ]] || { print -u2 'The matching Xcode compiler and macOS SDK are required.'; exit 1; }
[[ -f "$framework_dir/libNxlvKit.dylib" && -f "$module_dir/NxlvKit.swiftmodule" ]] || {
  print -u2 'Build the Ultimate Lemmix store candidate before running its app checks.'; exit 1
}
test_app="$build_dir/UltimateLemmixAppTests.app"
mkdir -p "$test_app/Contents/MacOS" "$build_dir/ModuleCache" "$build_dir/captures"
python3 - "$test_app/Contents/Info.plist" <<'PLIST'
import plistlib,sys
from pathlib import Path
Path(sys.argv[1]).write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'academy.glasscode.lemmix.integration-tests.store',
    'CFBundleExecutable': 'UltimateLemmixAppTests',
    'CFBundleName': 'Ultimate Lemmix App Tests',
    'CFBundleVersion': '1', 'CFBundleShortVersionString': '1.0',
    'CFBundlePackageType': 'APPL', 'LSUIElement': True,
    'UltimateLemmixStore': True,
}))
PLIST
ln -sfn "$candidate/Contents/Resources" "$test_app/Contents/Resources"
cat "$project_dir/Sources/LemmingsLocal/Lemmings2PlayWindow.swift" \
  "$project_dir/Sources/LemmingsLocal/Lemmings3PlayWindow.swift" \
  "$project_dir/Sources/LemmingsLocal/main.swift" \
  "$project_dir/Tests/UltimateLemmixAppTests/checks.swift" > "$build_dir/main.swift"
sources=("$project_dir"/Sources/LemmingsLocal/*.swift)
sources=("${(@)sources:#*/main.swift}")
sources=("${(@)sources:#*/Lemmings2PlayWindow.swift}")
sources=("${(@)sources:#*/Lemmings3PlayWindow.swift}")
"$compiler" -swift-version 6 -sdk "$sdk" -target "$architecture-apple-macosx12.3" \
  -DAPP_INTEGRATION_TESTS -DULTIMATE_LEMMIX_STORE -module-cache-path "$build_dir/ModuleCache" \
  -I "$module_dir" -L "$framework_dir" -lNxlvKit \
  -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  -Xlinker -rpath -Xlinker "$framework_dir" \
  -o "$test_app/Contents/MacOS/UltimateLemmixAppTests" "${sources[@]}" "$build_dir/main.swift"
if [[ "${TEST_COMPILE_ONLY:-0}" == 1 ]]; then
  print 'PASS Ultimate Lemmix app-test compilation only.'
  exit 0
fi
export LEMMINGS_TEST_WINDOWS=offscreen
export LEMMINGS_TEST_AUDIO=muted
export LEMMIX_TEST_OWNED_GAMES_DIRECTORY="$(mktemp -d "$build_dir/owned-games.XXXXXX")"
trap 'rm -rf "$LEMMIX_TEST_OWNED_GAMES_DIRECTORY"' EXIT
export LEMMIX_TEST_CAPTURES="$build_dir/captures"
export LEMMIX_TEST_PORTS_DIRECTORY="$project_dir/Sources/Ports"
cd "$project_dir"
python3 "$project_dir/Tools/UITestRunner/run.py" "$test_app/Contents/MacOS/UltimateLemmixAppTests"
LEMMIX_TEST_IMPORTER_ONLY=1 python3 "$project_dir/Tools/UITestRunner/run.py" "$test_app/Contents/MacOS/UltimateLemmixAppTests"
