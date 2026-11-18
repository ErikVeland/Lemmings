#!/bin/zsh
# Compare current native presentation before import, after import and after reopening.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="${LEMMIX_PARITY_BUILD_DIR:-$project_dir/.build/ultimate-lemmix-asset-parity}"
module_dir="${LEMMIX_PARITY_MODULE_DIR:-$project_dir/.build/ultimate-lemmix-asset-parity-shared}"
base_app="${LEMMIX_PARITY_BASE_APP:-$project_dir/.build/ultimate-lemmix-2.4.2-build107/Ultimate Lemmix.app}"
source_app="${LEMMIX_PARITY_SOURCE_APP:-/Applications/Ultimate Lemmings.app}"
[[ "${LEMMINGS_TEST_WINDOWS:-offscreen}" == offscreen && "${LEMMINGS_TEST_AUDIO:-muted}" == muted ]] || {
  print -u2 'Asset parity requires offscreen windows and muted audio.'
  exit 2
}
mkdir -p "$build_dir" "$build_dir/fixture"
framework_dir="${LEMMIX_PARITY_FRAMEWORK_DIR:-$source_app/Contents/Frameworks}"
[[ -d "$framework_dir/Sparkle.framework" ]] || {
  print -u2 'Set LEMMIX_PARITY_FRAMEWORK_DIR to the cached Sparkle framework folder.'
  exit 2
}
test_app="$build_dir/AssetParity.app"
mkdir -p "$test_app/Contents/MacOS" "$test_app/Contents/Frameworks"
cp "$project_dir/Resources/Info.plist" "$test_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable AssetParity' "$test_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier academy.glasscode.lemmings.integration-tests.asset-parity' "$test_app/Contents/Info.plist"
# The importer validates the trusted base and rejects symlinked resource roots.
if [[ -L "$test_app/Contents/Resources" ]]; then rm "$test_app/Contents/Resources"; fi
mkdir -p "$test_app/Contents/Resources"
rsync -a --delete "$base_app/Contents/Resources/" "$test_app/Contents/Resources/"
xcrun swiftc --version > "$build_dir/compiler.txt"
shasum -a 256 "$module_dir"/lib{NxlvKit,LemmingsAppCore,LemmingsGameArt,LemmingsAudio,LemmingsMobileCore}.dylib \
  > "$build_dir/module-hashes.txt"
if [[ -n "${LEMMIX_PARITY_APPCORE_DIR:-}" ]]; then
  shasum -a 256 "$LEMMIX_PARITY_APPCORE_DIR/libLemmingsAppCore.dylib" >> "$build_dir/module-hashes.txt"
fi
if [[ "${LEMMIX_PARITY_SKIP_COMPILE:-0}" != 1 ]]; then
cat "$project_dir/Sources/LemmingsLocal/main.swift" "$project_dir/Tests/UltimateLemmixAssetParity/checks.swift" "$project_dir/Tests/UltimateLemmixAssetParity/persistence.swift" "$project_dir/Tests/UltimateLemmixAssetParity/neo.swift" > "$build_dir/main.swift"
sources=("$project_dir"/Sources/LemmingsLocal/*.swift)
sources=("${(@)sources:#*/main.swift}")
# The sequel files embed helpers for the broad integration suite. Exclude only those test blocks.
mkdir -p "$build_dir/sources"
for source in Lemmings2PlayWindow.swift Lemmings3PlayWindow.swift; do
  sed 's/#if APP_INTEGRATION_TESTS/#if APP_INTEGRATION_TESTS \&\& !ASSET_PARITY_TESTS/' \
    "$project_dir/Sources/LemmingsLocal/$source" > "$build_dir/sources/$source"
  sources=("${(@)sources:#*/$source}")
  sources+=("$build_dir/sources/$source")
done
# Keep the updater and feature gates real. Replace only its default network transport.
sed 's/fetch: @escaping Fetch = FanLevelUpdates.fetch/fetch: @escaping Fetch = { _, _ in throw CancellationError() }/' \
  "$project_dir/Sources/LemmingsLocal/FanLevelUpdates.swift" > "$build_dir/sources/FanLevelUpdates.swift"
sources=("${(@)sources:#*/FanLevelUpdates.swift}")
sources+=("$build_dir/sources/FanLevelUpdates.swift")
# Match the real importer success sequence before notifying the app shell.
cp "$project_dir/Sources/LemmingsLocal/OwnedGameImportWindow.swift" "$build_dir/sources/OwnedGameImportWindow.swift"
cat >> "$build_dir/sources/OwnedGameImportWindow.swift" <<'SWIFT'
#if ASSET_PARITY_TESTS
extension OwnedGameImportWindow {
  func parityFinishResourceImport(_ installed: OwnedResourceLibrary.Installation) {
    if let page { GameScreen.shared.dismiss(page) }
    page = nil
    onResourcesInstalled?(installed)
  }
}
#endif
SWIFT
sources=("${(@)sources:#*/OwnedGameImportWindow.swift}")
sources+=("$build_dir/sources/OwnedGameImportWindow.swift")
# This check needs private native frontend members. No package script builds this focused executable.
extra_module_flags=()
if [[ -n "${LEMMIX_PARITY_APPCORE_DIR:-}" ]]; then
  extra_module_flags=(-I "$LEMMIX_PARITY_APPCORE_DIR/modules" -L "$LEMMIX_PARITY_APPCORE_DIR")
fi
xcrun swiftc "${extra_module_flags[@]}" -module-cache-path "$build_dir/ModuleCache" -swift-version 6 -target "$(uname -m)-apple-macos12.3" \
  -D APP_INTEGRATION_TESTS -D ASSET_PARITY_TESTS -D ULTIMATE_LEMMIX_STORE \
  -I "$module_dir/modules" -L "$module_dir" \
  -lNxlvKit -lLemmingsGameArt -lLemmingsAppCore -lLemmingsAudio -lLemmingsMobileCore \
  -F "$framework_dir" -framework Sparkle -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  -Xlinker -rpath -Xlinker "${LEMMIX_PARITY_APPCORE_DIR:-$module_dir}" -Xlinker -rpath -Xlinker "$module_dir" -Xlinker -rpath -Xlinker "$framework_dir" \
  -o "$test_app/Contents/MacOS/AssetParity" "${sources[@]}" "$build_dir/main.swift"
fi
if [[ "${LEMMIX_PARITY_COMPILE_ONLY:-0}" == 1 ]]; then
  print 'PASS focused asset parity compilation only. No application flow was run.'
  exit 0
fi
run_token="$(uuidgen)"
for phase in reference import reopen; do
  fixture="$build_dir/fixture/$run_token/candidate"
  [[ "$phase" == reference ]] && fixture="$build_dir/fixture/$run_token/reference"
  mkdir -p "$fixture"
  LEMMIX_PARITY_PHASE="$phase" LEMMIX_PARITY_OUTPUT="$build_dir/$phase" \
    LEMMIX_PARITY_REFERENCE="$build_dir/reference" LEMMIX_PARITY_SOURCE="$source_app" LEMMIX_TEST_OWNED_GAMES_DIRECTORY="$fixture/OwnedGames" \
    LEMMINGS_TEST_APPLICATION_SUPPORT="$fixture/Support" \
    python3 "$project_dir/Tools/UITestRunner/run.py" arch "-$(uname -m)" "$test_app/Contents/MacOS/AssetParity"
done
python3 "$project_dir/Tests/UltimateLemmixAssetParity/compare.py" "$build_dir"
