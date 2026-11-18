#!/bin/zsh
# Validate the personal preview without foreground windows or audible output.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="${ULTIMATE_LEMMIX_TEST_BUILD_DIR:-$project_dir/.build/personal-preview-app-tests}"
candidate="${ULTIMATE_LEMMIX_PERSONAL_BUILD_DIR:-$project_dir/.build/ultimate-lemmix-personal-preview}/Ultimate Lemmix.app"
base="${ULTIMATE_LEMMIX_CORE_BUILD_DIR:-$project_dir/.build/ultimate-lemmix-app-store-universal}"
architecture="$(uname -m)"
module_dir="${ULTIMATE_LEMMIX_CORE_MODULE_DIR:-$base/$architecture/modules}"
framework_dir="${ULTIMATE_LEMMIX_CORE_LIBRARY_DIR:-$base/Ultimate Lemmix.app/Contents/Frameworks}"
compiler=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk
[[ -f "$candidate/Contents/Info.plist" && -d "$candidate/Contents/Resources" && -f "$module_dir/NxlvKit.swiftmodule" ]] || {
  print -u2 'Prepare the personal preview resources and base Mac core before these checks.'; exit 1
}
test_app="$build_dir/PersonalPreviewAppTests.app"
mkdir -p "$test_app/Contents/MacOS" "$build_dir/ModuleCache" "$build_dir/captures"
python3 - "$candidate/Contents/Info.plist" "$test_app/Contents/Info.plist" "${LEMMIX_PREVIEW_TEST_CLEAN:-0}" <<'PLIST'
import plistlib,sys
from pathlib import Path
info=plistlib.loads(Path(sys.argv[1]).read_bytes())
info.update({'CFBundleIdentifier':'academy.glasscode.lemmix.integration-tests.personal-preview',
 'CFBundleExecutable':'PersonalPreviewAppTests','CFBundleName':'Personal Preview App Tests','LSUIElement':True,
 'UltimateLemmixStore':True,'UltimateLemmixPersonalPreview':sys.argv[3]!='1'})
Path(sys.argv[2]).write_bytes(plistlib.dumps(info))
PLIST
ln -sfn "$candidate/Contents/Resources" "$test_app/Contents/Resources"
cat "$project_dir/Sources/LemmingsLocal/main.swift" \
  "$project_dir/Tests/PersonalPreviewAppTests/checks.swift" > "$build_dir/main.swift"
sources=("$project_dir"/Sources/LemmingsLocal/*.swift)
sources=("${(@)sources:#*/main.swift}")
"$compiler" -swift-version 6 -sdk "$sdk" -target "$architecture-apple-macosx12.3" \
  -DAPP_INTEGRATION_TESTS -DULTIMATE_LEMMIX_STORE -module-cache-path "$build_dir/ModuleCache" \
  -I "$module_dir" -L "$framework_dir" -lNxlvKit \
  -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  -Xlinker -rpath -Xlinker "$framework_dir" \
  -o "$test_app/Contents/MacOS/PersonalPreviewAppTests" "${sources[@]}" "$build_dir/main.swift"
if [[ "${TEST_COMPILE_ONLY:-0}" == 1 ]]; then
  print 'PASS personal-preview native test compilation only.'
  exit 0
fi
export LEMMINGS_TEST_WINDOWS=offscreen
export LEMMINGS_TEST_AUDIO=muted
export LEMMIX_TEST_CAPTURES="$build_dir/captures"
fixture=""
trap '[[ -z "$fixture" ]] || rm -rf -- "$fixture"' EXIT
cd "$project_dir"
scopes=(home settings browser menus starter-browser starter starter2 starter3 fan hud hud-paused hud-undo hud-small)
[[ "${LEMMIX_PREVIEW_TEST_CLEAN:-0}" != 1 ]] || scopes=(home menus starter-browser hud)
[[ -z "${LEMMIX_PREVIEW_TEST_SCOPE:-}" ]] || scopes=("$LEMMIX_PREVIEW_TEST_SCOPE")
for scope in "${scopes[@]}"; do
  fixture="$(mktemp -d "$build_dir/fixture-$scope.XXXXXX")"
  mkdir -p "$fixture/tool-home" "$fixture/owned"
  CFFIXED_USER_HOME="$fixture/tool-home" LEMMIX_TEST_STORAGE_ROOT="$fixture" \
    LEMMIX_TEST_OWNED_GAMES_DIRECTORY="$fixture/owned" LEMMIX_PREVIEW_TEST_SCOPE="$scope" \
    python3 "$project_dir/Tools/UITestRunner/run.py" "$test_app/Contents/MacOS/PersonalPreviewAppTests"
  rm -rf -- "$fixture"
  fixture=""
done
