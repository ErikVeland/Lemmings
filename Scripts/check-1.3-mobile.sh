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
grep -q 'MTKView' Sources/LemmingsMobileUI/MobileMetalView.swift
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
if runtime_json="$(xcrun simctl list runtimes -j 2>/dev/null)" \
    && [[ "$runtime_json" == *com.apple.CoreSimulator.SimRuntime.iOS* ]]; then
  runtime_available=1
fi
if (( require_sdk && !runtime_available )); then
  print -u2 "FAILED: Install an iOS Simulator runtime in Xcode before running the required 1.3 gate."
  exit 1
fi

asset_settings=()
if (( !runtime_available )); then
  asset_settings=(EXCLUDED_SOURCE_FILE_NAMES=Assets.xcassets)
fi

zsh Scripts/run-swift-tests.sh --disable-sandbox \
  --test-product LemmingsNativePortPackageTests \
  --filter LemmingsMobileCoreTests
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
