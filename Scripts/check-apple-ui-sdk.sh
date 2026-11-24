#!/bin/zsh
# Compile shared Apple frontends without booting or showing a Simulator.
set -euo pipefail
project_dir="${0:A:h:h}"
case "${1:-}" in
  ios) sdk_name=iphonesimulator; target=arm64-apple-ios16.0-simulator; module_target=arm64-apple-ios-simulator; application=UltimateLemmingsIOS ;;
  tvos) sdk_name=appletvsimulator; target=arm64-apple-tvos16.0-simulator; module_target=arm64-apple-tvos-simulator; application=UltimateLemmingsTV ;;
  *) print -u2 "Usage: zsh Scripts/check-apple-ui-sdk.sh ios|tvos"; exit 2 ;;
esac
build_dir="${APPLE_UI_SDK_BUILD_DIR:-$project_dir/.build/apple-ui-sdk/$1}"
mkdir -p "$build_dir/ModuleCache" "$build_dir/Modules" "$build_dir/Sources"
sdk="$(xcrun --sdk "$sdk_name" --show-sdk-path)"
sdk_modules=(NxlvKit LemmingsAppCore LemmingsMobileCore LemmingsAudio LemmingsTVCore LemmingsGameArt LemmingsMobileUI LemmingsTVUI)
for module in "${sdk_modules[@]}"; do
  rm -rf "$build_dir/Sources/$module"
  cp -R "$project_dir/Sources/$module" "$build_dir/Sources/$module"
done
cp "$project_dir"/Apps/SharedAppleMobile/{AppDelegate,LaunchURL}.swift "$build_dir/Sources/"
mkdir -p "$build_dir/Sources/UXTests"
for suite in MobileDestinationBackTests MobileDuoHUDTransitionTests MobileJourneyReturnTests MobileMenuPreviewTargetTests MobileOverlayReturnTests; do
  cp "$project_dir/Tests/LemmingsMobileUITests/$suite.swift" "$build_dir/Sources/UXTests/"
done
python3 - "$build_dir/Sources" "$build_dir/inputs.json" <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
files = {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
         for path in sorted(root.rglob('*.swift'))}
pathlib.Path(sys.argv[2]).write_text(json.dumps(files, indent=2, sort_keys=True) + '\n')
PY
for module in "${sdk_modules[@]}"; do
  mkdir -p "$build_dir/Modules/$module.swiftmodule"
  local_sources=("${(@f)$(rg --files "$build_dir/Sources/$module" -g '*.swift')}")
  swiftc -swift-version 6 -parse-as-library -enable-testing -target "$target" -sdk "$sdk" \
    -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/Modules" \
    -module-name "$module" -emit-module \
    -emit-module-path "$build_dir/Modules/$module.swiftmodule/$module_target.swiftmodule" \
    "${local_sources[@]}"
  print "PASS $module $1 SDK module"
done
swiftc -swift-version 6 -parse-as-library -target "$target" -sdk "$sdk" \
  -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/Modules" \
  -typecheck "$build_dir"/Sources/{AppDelegate,LaunchURL}.swift
print "PASS $application application entry point"
developer="$(xcode-select -p)"
platform_dir="$(xcrun --sdk "$sdk_name" --show-sdk-platform-path)/Developer"
swiftc -swift-version 6 -parse-as-library -target "$target" -sdk "$sdk" \
  -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/Modules" \
  -load-plugin-library "$developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib" \
  -F "$platform_dir/Library/Frameworks" -I "$platform_dir/usr/lib" \
  -module-name UXPlatformTests -typecheck "$build_dir"/Sources/UXTests/*.swift
print "PASS $1 UIKit regression sources typechecked"
