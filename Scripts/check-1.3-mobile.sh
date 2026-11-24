#!/bin/zsh
# Validate the selected product’s iPhone and iPad targets.
set -euo pipefail

project_dir="${0:A:h:h}"
require_sdk=0
ui_destination=""
ui_result=""

if [[ "${1:-}" == "--require-sdk" && $# == 1 ]]; then
  require_sdk=1
elif [[ "${1:-}" == "--ui-test" && $# == 3 ]]; then
  require_sdk=1
  ui_destination="$2"
  ui_result="$3"
elif (( $# > 0 )); then
  print -u2 "Usage: zsh Scripts/check-1.3-mobile.sh [--require-sdk | --ui-test <destination> <result-bundle>]"
  exit 2
fi

cd "$project_dir"

product="$(python3 -c 'import json; print(json.load(open("Product.json"))["product"])')"
case "$product" in
  ultimate-lemmings) target=UltimateLemmingsIOS ;;
  ultimate-lemmix) target=UltimateLemmixIOS ;;
  *) print -u2 "FAILED: Unknown iOS product: $product"; exit 2 ;;
esac
app_dir="Apps/$target"
xcodeproject="$app_dir/$target.xcodeproj"
ui_target="${target}UITests"

run_store_xcode() {
  local resource_dir="${ULTIMATE_LEMMIX_RESOURCES_DIR:-$project_dir/.build/publication-resources/ultimate-lemmix}"
  local fan_runtime="${ULTIMATE_LEMMIX_FAN_RUNTIME:-$project_dir/.build/FanRuntime.zip}"
  if [[ ! -f "$resource_dir/ultimate-lemmix-mobile-resources.json" || ! -f "$fan_runtime" ]]; then
    print -u2 "FAILED: Ultimate Lemmix requires its prepared Store resource inventory and pinned FanRuntime.zip. See Apps/UltimateLemmixSupport/README.md."
    return 1
  fi
  ULTIMATE_LEMMIX_FAN_RUNTIME="$fan_runtime" zsh Apps/UltimateLemmixSupport/build.sh ios \
    "ULTIMATE_LEMMIX_RESOURCES_DIR=$resource_dir" "$@"
}

developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
if ! DEVELOPER_DIR="$developer_dir" xcrun --sdk iphonesimulator --show-sdk-path >/dev/null 2>&1 \
    && [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  developer_dir=/Applications/Xcode.app/Contents/Developer
fi
export DEVELOPER_DIR="$developer_dir"
# This gate runs mechanical checks only. Preserve the player's audio settings.
export LEMMINGS_TEST_AUDIO=muted
export IOS_SOURCE_GATE_ONLY=1
export IOS_MUSIC_SCOPE=main

plutil -lint \
  "$app_dir/Info.plist" \
  "$app_dir/PrivacyInfo.xcprivacy" \
  "$xcodeproject/project.pbxproj" >/dev/null

grep -q 'LemmingsMobileCore' Package.swift
grep -q 'LemmingsMobileUI' Package.swift
grep -q 'com.apple.product-type.application' \
  "$xcodeproject/project.pbxproj"
grep -q 'TARGETED_DEVICE_FAMILY = "1,2"' \
  "$xcodeproject/project.pbxproj"
grep -q 'MTKView' Sources/LemmingsMobileUI/MobileCRTView.swift
grep -q 'MobileCheckpointStore' Sources/LemmingsMobileCore/MobileCheckpoint.swift
grep -q 'AppIcon-1024.png' "$app_dir/Assets.xcassets/AppIcon.appiconset/Contents.json"
grep -q 'import LemmingsMobileCore' Apps/SharedAppleMobile/UITests/MobileCoreIOSSmokeTests.swift

for source in Sources/LemmingsMobileCore/*.swift Sources/LemmingsMobileUI/*.swift \
  Apps/SharedAppleMobile/AppDelegate.swift Apps/SharedAppleMobile/LaunchURL.swift \
  Apps/SharedAppleMobile/UITests/*.swift; do
  swiftc -frontend -parse "$source"
done

print "PASS $product iOS project, target and source contracts"

if ! command -v xcodebuild >/dev/null 2>&1 || ! xcrun --sdk iphonesimulator --show-sdk-path >/dev/null 2>&1; then
  if (( require_sdk )); then
    print -u2 "FAILED: A full Xcode installation with the iOS Simulator SDK is required."
    exit 1
  fi
  print "SKIP iOS compilation: this Mac has Command Line Tools but no iOS SDK."
  exit 0
fi

if [[ -n "$ui_destination" ]]; then
  if [[ "$product" == ultimate-lemmix ]]; then
    run_store_xcode test -destination "$ui_destination"   \
      "-only-testing:$ui_target/MobileCoreIOSSmokeTests" -resultBundlePath "$ui_result" CODE_SIGNING_ALLOWED=NO
  else
    xcodebuild test -project "$xcodeproject" -scheme "$target" -destination "$ui_destination"   \
      "-only-testing:$ui_target/MobileCoreIOSSmokeTests" -resultBundlePath "$ui_result" CODE_SIGNING_ALLOWED=NO
  fi
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

zsh Scripts/run-source-tests.sh
if [[ "$product" == ultimate-lemmix ]]; then
  run_store_xcode -configuration Debug -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$project_dir/.build/lemmix-ios-debug" CODE_SIGNING_ALLOWED=NO build-for-testing
  run_store_xcode -configuration Release -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$project_dir/.build/lemmix-ios-release" CODE_SIGNING_ALLOWED=NO build
  run_store_xcode -configuration Release -destination 'generic/platform=iOS' \
    -derivedDataPath "$project_dir/.build/lemmix-ios-device" CODE_SIGNING_ALLOWED=NO build
  print "PASS Ultimate Lemmix tests, Simulator builds and unsigned Release device build"
  exit 0
fi

xcodebuild -quiet \
  -project "$xcodeproject" \
  -target "$ui_target" \
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
  -project "$xcodeproject" \
  -target "$target" \
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
  -project "$xcodeproject" \
  -target "$target" \
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
