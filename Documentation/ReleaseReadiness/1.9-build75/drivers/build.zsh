#!/bin/zsh
set -euo pipefail

project_dir="/Users/veland/Lemmings"
build_dir="${LEMMINGS_BUILD_DIR:-$project_dir/.build/local}"
build_dir="${build_dir:A}"
app_dir="$build_dir/Ultimate Lemmings.app"
contents_dir="$app_dir/Contents"
deployment_target="12.3"
architectures=(arm64 x86_64)
if [[ -n "${LEMMINGS_ARCHITECTURES:-}" ]]; then
  architectures=("${(@s: :)LEMMINGS_ARCHITECTURES}")
fi
swift_optimization="${LEMMINGS_SWIFT_OPTIMIZATION:--O}"

if [[ -n "${LEMMINGS_TELEMETRY_URL:-}" ]]; then
  if ! python3 - "$LEMMINGS_TELEMETRY_URL" <<'PYURL'
import sys
from urllib.parse import urlsplit

try:
    url = urlsplit(sys.argv[1])
    valid = (url.scheme == "https" and url.hostname is not None
             and url.username is None and url.password is None
             and not url.query and not url.fragment
             and (url.port is None or 1 <= url.port <= 65535))
except ValueError:
    valid = False
sys.exit(0 if valid else 1)
PYURL
  then
    print -u2 "LEMMINGS_TELEMETRY_URL must be an HTTPS URL without credentials, query or fragment."
    exit 1
  fi
fi

zsh "$project_dir/Scripts/check-local-build.sh"
cp -c -R "$project_dir/.build/release-1.8.5/standard/Ultimate Lemmings.app" "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources" "$contents_dir/Frameworks"
sparkle_framework="$(SPARKLE_FRAMEWORK_PATH="${SPARKLE_FRAMEWORK_PATH:-}" \
  LEMMINGS_BUILD_ROOT="$build_dir/dependencies" \
  zsh "$project_dir/Scripts/ensure-sparkle.sh")"
sparkle_framework_dir="${sparkle_framework:h}"

library_inputs=()
executable_inputs=()
for architecture in "${architectures[@]}"; do
  architecture_dir="$build_dir/$architecture"
  module_dir="$architecture_dir/modules"
  mkdir -p "$module_dir"
  target="$architecture-apple-macosx$deployment_target"
  # Below macOS 13 the Swift driver links libswiftCompatibility56. The Command Line
  # Tools ship that library for arm64 only, so the Intel slice is linked without it.
  # Its fixes apply to the Swift 5.6 concurrency runtime. The compiler still rejects
  # any API newer than the deployment target.
  compatibility=()
  [[ "$architecture" == x86_64 ]] && compatibility=(-runtime-compatibility-version none)

  if [[ "$architecture" == arm64 ]]; then
    cp "$project_dir/.build/release-1.9/engine/libNxlvKit.dylib" "$architecture_dir/libNxlvKit.dylib"
    cp "$project_dir/.build/release-1.9/engine/modules/"* "$module_dir/"
  else
  swiftc -swift-version 6 "$swift_optimization" -target "$target" "${compatibility[@]}" -parse-as-library \
    -module-cache-path "$build_dir/ModuleCache" \
    -emit-module -emit-library \
    -module-name NxlvKit \
    -emit-module-path "$module_dir/NxlvKit.swiftmodule" \
    -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib -Xlinker -w \
    -o "$architecture_dir/libNxlvKit.dylib" \
    "$project_dir"/Sources/NxlvKit/*.swift

  fi

  swiftc -swift-version 6 "$swift_optimization" -target "$target" "${compatibility[@]}" \
    -module-cache-path "$build_dir/ModuleCache" \
    -I "$module_dir" -L "$architecture_dir" -lNxlvKit \
    -F "$sparkle_framework_dir" -framework Sparkle \
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
if [[ -n "${LEMMINGS_TELEMETRY_URL:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :AnonymousTelemetryURL $LEMMINGS_TELEMETRY_URL" "$contents_dir/Info.plist"
fi
rsync -a --delete "$sparkle_framework" "$contents_dir/Frameworks/"
cp "$project_dir/THIRD_PARTY_NOTICES.md" "$contents_dir/Resources/Third Party Notices.md"
python3 - "$contents_dir/Resources" <<'BUNDLE'
import sys,json,pathlib,shutil
r=pathlib.Path(sys.argv[1]); project=pathlib.Path.cwd()
for name in ['Hints','Progression','Trolley']:
 shutil.rmtree(r/name)
 shutil.copytree(project/'Resources'/name,r/name)
shutil.copytree(project/'.build/mac-music-export',r/'MacMusic',dirs_exist_ok=True)
(r/'Trolley/engine-fingerprint.txt').write_text((project/'Resources/Trolley/engine-fingerprint.txt').read_text())
BUNDLE
codesign --force --deep --sign - "$app_dir"
