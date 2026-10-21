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
cp "$project_dir/Apps/$application/AppDelegate.swift" "$build_dir/Sources/AppDelegate.swift"
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
  swiftc -swift-version 6 -parse-as-library -target "$target" -sdk "$sdk" \
    -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/Modules" \
    -module-name "$module" -emit-module \
    -emit-module-path "$build_dir/Modules/$module.swiftmodule/$module_target.swiftmodule" \
    "${local_sources[@]}"
  print "PASS $module $1 SDK module"
done
swiftc -swift-version 6 -parse-as-library -target "$target" -sdk "$sdk" \
  -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/Modules" \
  -typecheck "$build_dir/Sources/AppDelegate.swift"
print "PASS $application application entry point"
