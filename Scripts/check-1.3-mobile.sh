#!/bin/zsh
# Validate the data-independent iPhone and iPad 1.3 source gate.
set -euo pipefail

project_dir="${0:A:h:h}"
require_sdk=0

if [[ "${1:-}" == "--require-sdk" ]]; then
  require_sdk=1
elif (( $# > 0 )); then
  print -u2 "Usage: zsh Scripts/check-1.3-mobile.sh [--require-sdk]"
  exit 2
fi

cd "$project_dir"

developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
if ! DEVELOPER_DIR="$developer_dir" xcrun --sdk iphonesimulator --show-sdk-path >/dev/null 2>&1 \
    && [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  developer_dir=/Applications/Xcode.app/Contents/Developer
fi
export DEVELOPER_DIR="$developer_dir"
# This gate runs mechanical checks only. Preserve the player's audio settings.
export LEMMINGS_TEST_AUDIO=muted

plutil -lint \
  Apps/UltimateLemmingsIOS/Info.plist \
  Apps/UltimateLemmingsIOS/PrivacyInfo.xcprivacy \
  Apps/UltimateLemmingsIOS/UltimateLemmingsIOS.xcodeproj/project.pbxproj >/dev/null

grep -q 'LemmingsMobileCore' Package.swift
grep -q 'LemmingsMobileUI' Package.swift
grep -q 'com.apple.product-type.application' \
  Apps/UltimateLemmingsIOS/UltimateLemmingsIOS.xcodeproj/project.pbxproj
grep -q 'TARGETED_DEVICE_FAMILY = "1,2"' \
  Apps/UltimateLemmingsIOS/UltimateLemmingsIOS.xcodeproj/project.pbxproj
grep -q 'MTKView' Sources/LemmingsMobileUI/MobileCRTView.swift
grep -q 'MobileCheckpointStore' Sources/LemmingsMobileCore/MobileCheckpoint.swift
grep -q 'AppIcon-1024.png' Apps/UltimateLemmingsIOS/Assets.xcassets/AppIcon.appiconset/Contents.json
grep -q 'import LemmingsMobileCore' Apps/UltimateLemmingsIOS/UITests/MobileCoreIOSSmokeTests.swift

for source in Sources/LemmingsMobileCore/*.swift Sources/LemmingsMobileUI/*.swift \
  Apps/UltimateLemmingsIOS/AppDelegate.swift Apps/UltimateLemmingsIOS/UITests/*.swift; do
  swiftc -frontend -parse "$source"
done

print "PASS 1.3 mobile project, target and source contracts"

if ! command -v xcodebuild >/dev/null 2>&1 || ! xcrun --sdk iphonesimulator --show-sdk-path >/dev/null 2>&1; then
  if (( require_sdk )); then
    print -u2 "FAILED: A full Xcode installation with the iOS Simulator SDK is required."
    exit 1
  fi
  print "SKIP iOS compilation: this Mac has Command Line Tools but no iOS SDK."
  exit 0
fi

runtime_available=0
runtime_query_failed=0
runtime_diagnostic="$(mktemp -t lemmings-mobile-runtimes)"
if runtime_json="$(xcrun simctl list runtimes -j 2>"$runtime_diagnostic")"; then
  if ! runtime_available="$(print -r -- "$runtime_json" | python3 -c '
import json, sys
runtimes = json.load(sys.stdin)["runtimes"]
print(int(any(r.get("isAvailable") is True and
              r.get("identifier", "").startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
              for r in runtimes)))
')"; then
    runtime_query_failed=1
  fi
else
  runtime_query_failed=1
fi
if (( require_sdk && runtime_query_failed )); then
  print -u2 "FAILED: Could not query iOS Simulator runtimes. Check CoreSimulator service access."
  cat "$runtime_diagnostic" >&2
  rm -f "$runtime_diagnostic"
  exit 1
fi
rm -f "$runtime_diagnostic"
if (( require_sdk && !runtime_available )); then
  print -u2 "FAILED: Install an available iOS Simulator runtime in Xcode before running the required 1.3 gate."
  exit 1
fi

asset_settings=()
if (( !runtime_available )); then
  asset_settings=(EXCLUDED_SOURCE_FILE_NAMES=Assets.xcassets)
fi

zsh Scripts/run-swift-tests.sh --disable-sandbox \
  --filter 'LemmingsMobileCoreTests|LemmingsAppCoreTests'
xcodebuild -quiet \
  -project Apps/UltimateLemmingsIOS/UltimateLemmingsIOS.xcodeproj \
  -target UltimateLemmingsIOSUITests \
  -configuration Debug \
  -sdk iphonesimulator \
  -clonedSourcePackagesDirPath "$project_dir/.build/ios-packages" \
  OBJROOT="$project_dir/.build/ios-obj" \
  SYMROOT="$project_dir/.build/ios-products" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  "${asset_settings[@]}" \
  build

xcodebuild -quiet \
  -project Apps/UltimateLemmingsIOS/UltimateLemmingsIOS.xcodeproj \
  -target UltimateLemmingsIOS \
  -configuration Release \
  -sdk iphonesimulator \
  -clonedSourcePackagesDirPath "$project_dir/.build/ios-packages" \
  OBJROOT="$project_dir/.build/ios-release-obj" \
  SYMROOT="$project_dir/.build/ios-release-products" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  "${asset_settings[@]}" \
  build

xcodebuild -quiet \
  -project Apps/UltimateLemmingsIOS/UltimateLemmingsIOS.xcodeproj \
  -target UltimateLemmingsIOS \
  -configuration Release \
  -sdk iphoneos \
  -clonedSourcePackagesDirPath "$project_dir/.build/ios-packages" \
  OBJROOT="$project_dir/.build/ios-device-release-obj" \
  SYMROOT="$project_dir/.build/ios-device-release-products" \
  CODE_SIGNING_ALLOWED=NO \
  "${asset_settings[@]}" \
  build

if (( runtime_available )); then
  print "PASS 1.3 tests, Debug and Release Simulator builds, and unsigned Release device build"
else
  print "PASS 1.3 tests, Debug and Release Simulator code builds, and unsigned Release device code build"
  print "SKIP asset catalogue and launch validation: no iOS Simulator runtime is installed."
fi
