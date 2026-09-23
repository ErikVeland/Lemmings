#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="${LEMMINGS_BUILD_DIR:-$project_dir/.build/local}"
build_dir="${build_dir:A}"
app_dir="$build_dir/Ultimate Lemmings.app"
contents_dir="$app_dir/Contents"
deployment_target="13.0"
architectures=(arm64 x86_64)
if [[ -n "${LEMMINGS_ARCHITECTURES:-}" ]]; then
  architectures=("${(@s: :)LEMMINGS_ARCHITECTURES}")
fi
swift_optimization="${LEMMINGS_SWIFT_OPTIMIZATION:--O}"

zsh "$project_dir/Scripts/check-local-build.sh"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources" "$contents_dir/Frameworks"

library_inputs=()
executable_inputs=()
for architecture in "${architectures[@]}"; do
  architecture_dir="$build_dir/$architecture"
  module_dir="$architecture_dir/modules"
  mkdir -p "$module_dir"
  target="$architecture-apple-macosx$deployment_target"

  swiftc -swift-version 6 "$swift_optimization" -target "$target" -parse-as-library \
    -module-cache-path "$build_dir/ModuleCache" \
    -emit-module -emit-library \
    -module-name NxlvKit \
    -emit-module-path "$module_dir/NxlvKit.swiftmodule" \
    -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib -Xlinker -w \
    -o "$architecture_dir/libNxlvKit.dylib" \
    "$project_dir"/Sources/NxlvKit/*.swift

  swiftc -swift-version 6 "$swift_optimization" -target "$target" \
    -module-cache-path "$build_dir/ModuleCache" \
    -I "$module_dir" -L "$architecture_dir" -lNxlvKit \
    -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks -Xlinker -w \
    -o "$architecture_dir/LemmingsLocal" \
    "$project_dir"/Sources/LemmingsLocal/*.swift

  library_inputs+=("$architecture_dir/libNxlvKit.dylib")
  executable_inputs+=("$architecture_dir/LemmingsLocal")
done

if (( ${#library_inputs} == 1 )); then
  cp "${library_inputs[1]}" "$contents_dir/Frameworks/libNxlvKit.dylib"
  cp "${executable_inputs[1]}" "$contents_dir/MacOS/LemmingsLocal"
else
  lipo -create "${library_inputs[@]}" -output "$contents_dir/Frameworks/libNxlvKit.dylib"
  lipo -create "${executable_inputs[@]}" -output "$contents_dir/MacOS/LemmingsLocal"
fi
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
zsh "$project_dir/Scripts/build-app-icon.sh" "$contents_dir/Resources/AppIcon.icns"
zsh "$project_dir/Scripts/index-fan-levels.sh" "$build_dir/$(uname -m)"
zsh "$project_dir/Scripts/bundle-game-data.sh" "$contents_dir/Resources" all

# Seal the finished bundle after resources are copied. Capability builds use
# an Apple identity and matching provisioning profile.
capabilities_mode="${ENABLE_APPLE_CAPABILITIES:-auto}"
profile_args=()
if [[ -n "${APPLE_PROVISIONING_PROFILE:-}" ]]; then
  profile_args+=(--profile "$APPLE_PROVISIONING_PROFILE")
fi
if [[ "$capabilities_mode" == auto ]]; then
  if python3 "$project_dir/Scripts/sign-capabilities.py" "$app_dir" "${profile_args[@]}" --check >/dev/null 2>&1; then
    capabilities_mode=1
  else
    capabilities_mode=0
  fi
fi
if [[ "$capabilities_mode" != 0 && "$capabilities_mode" != 1 ]]; then
  echo "ENABLE_APPLE_CAPABILITIES must be auto, 0, or 1." >&2
  exit 1
fi
if [[ "$capabilities_mode" == 1 ]]; then
  python3 "$project_dir/Scripts/sign-capabilities.py" "$app_dir" "${profile_args[@]}"
else
  # Ad-hoc builds cannot use Game Center.
  python3 - "$contents_dir/Resources/GameCenter/leaderboards.json" <<'PYCONFIG'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
config = json.loads(path.read_text())
config['enabled'] = False
path.write_text(json.dumps(config, indent=2, sort_keys=True) + '\n')
PYCONFIG
  rm -f "$contents_dir/embedded.provisionprofile"
  codesign --force --deep --sign - "$app_dir"
fi

# Refresh the bundle timestamp so Finder can detect rebuilt app icons.
touch "$app_dir"

echo "$app_dir"
