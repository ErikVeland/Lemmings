#!/bin/zsh
# Build the separate sandboxed Mac App Store candidate without legacy resources.
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="${ULTIMATE_LEMMIX_BUILD_DIR:-$project_dir/.build/ultimate-lemmix-app-store-build4-universal}"
build_dir="${build_dir:A}"
app_dir="$build_dir/Ultimate Lemmix.app"
contents_dir="$app_dir/Contents"
resources_only=0
audit_only=0
adhoc=0

fail() { print -u2 "FAILED: $*"; exit 1; }

for argument in "$@"; do
  case "$argument" in
    --resources-only) resources_only=1 ;;
    --audit) audit_only=1 ;;
    --adhoc) adhoc=1 ;;
    --help|-h)
      print 'Usage: build-ultimate-lemmix-app-store.sh [--adhoc] [--resources-only] [--audit]'
      print 'Ad-hoc output is for local validation. It is not a submission archive.'
      print 'Use ULTIMATE_LEMMIX_ARCHITECTURES="arm64" for a host-only check.'
      exit 0 ;;
    *) fail "Unknown argument: $argument" ;;
  esac
done

python3 - "$project_dir" "$build_dir" <<'PYROOT'
from pathlib import Path
import sys
root, output = map(lambda value: Path(value).resolve(), sys.argv[1:])
if root / '.build' not in output.parents:
    raise SystemExit('The store build directory must be beneath this checkout’s .build folder.')
PYROOT

resource_args=(--output "$contents_dir/Resources")
(( resources_only )) && resource_args+=(--allow-missing-integration)

audit_bundle() {
  python3 "$project_dir/Tools/AlternativeAssets/store_resources.py" "${resource_args[@]}" --audit
  (( resources_only )) && return 0
  python3 - "$app_dir" "$project_dir/Resources/UltimateLemmix/Info.plist" "$project_dir/Sources/LemmingsLocal/GameCursor.swift" <<'PYAUDIT'
from pathlib import Path
import base64, plistlib, re, sys
app, info, cursor = map(Path, sys.argv[1:])
if plistlib.loads((app / 'Contents/Info.plist').read_bytes()) != plistlib.loads(info.read_bytes()):
    raise SystemExit('The store bundle metadata differs from the approved store identity.')
expected = {'Contents/Info.plist', 'Contents/MacOS/UltimateLemmix',
            'Contents/Frameworks/libNxlvKit.dylib', 'Contents/_CodeSignature/CodeResources'}
for path in app.rglob('*'):
    if path.is_symlink():
        raise SystemExit('The store application contains a symbolic link.')
    if path.is_file():
        name = path.relative_to(app).as_posix()
        if not name.startswith('Contents/Resources/') and name not in expected:
            raise SystemExit('The store application contains an unexpected file: ' + name)
for name in expected:
    if not (app / name).is_file():
        raise SystemExit('The store application is incomplete: ' + name)
payloads = re.findall(r'originalPointerImage\("""(.*?)"""', cursor.read_text(), re.S)
if len(payloads) != 2:
    raise SystemExit('The original cursor source audit needs review after its source changed.')
executables = [(app / name).read_bytes() for name in expected if name.endswith(('UltimateLemmix', '.dylib'))]
for payload in payloads:
    compact = re.sub(r'\s+', '', payload)
    if any(compact[:80].encode() in data or base64.b64decode(compact) in data for data in executables):
        raise SystemExit('The store executable contains original cursor artwork.')
PYAUDIT
  dependencies="$(otool -L "$contents_dir/MacOS/UltimateLemmix" "$contents_dir/Frameworks/libNxlvKit.dylib")"
  [[ "$dependencies" != *Sparkle* ]] || fail 'The store executable must not link Sparkle.'
  codesign --verify --deep --strict "$app_dir"
  python3 - "$app_dir" <<'PYSIGNING'
from pathlib import Path
import re, subprocess, sys
app = Path(sys.argv[1])
def signature(path):
    """Read the signature flags and signing team for this architecture."""
    output = subprocess.run(['codesign', '-d', '--verbose=4', str(path)],
                            capture_output=True, text=True, check=True).stderr
    flags = int(re.search(r'flags=0x([0-9a-fA-F]+)', output).group(1), 16)
    team = re.search(r'^TeamIdentifier=(.*)$', output, re.M).group(1)
    return flags, team
flags, team = signature(app)
if flags & 0x10000:
    if flags & 0x2:
        raise SystemExit('Ad-hoc review builds must not enable hardened runtime without a signing team.')
    _, library_team = signature(app / 'Contents/Frameworks/libNxlvKit.dylib')
    if team == 'not set' or team != library_team:
        raise SystemExit('The hardened application and core library need the same signing team.')
PYSIGNING
  codesign --display --entitlements :- "$app_dir" 2>/dev/null |
    python3 -c 'import plistlib,sys; p=plistlib.loads(sys.stdin.buffer.read()); expected=plistlib.load(open(sys.argv[1],"rb")); assert all(p.get(k)==v for k,v in expected.items()); assert "com.apple.developer.game-center" not in p' \
      "$project_dir/Resources/UltimateLemmix/AppStore.entitlements"
  print "Verified signed store candidate: $app_dir"
}

if (( audit_only )); then
  audit_bundle
  exit 0
fi

mkdir -p "$contents_dir"
python3 "$project_dir/Tools/AlternativeAssets/store_resources.py" "${resource_args[@]}"
cp "$project_dir/Resources/UltimateLemmix/Info.plist" "$contents_dir/Info.plist"
if (( resources_only )); then
  print "Prepared local resources only: $app_dir"
  exit 0
fi

identity="${ULTIMATE_LEMMIX_SIGNING_IDENTITY:-}"
if (( adhoc )); then
  [[ -z "$identity" || "$identity" == - ]] || fail 'Do not combine --adhoc with an Apple signing identity.'
  identity=-
else
  [[ -n "$identity" && "$identity" != - ]] || fail 'Set ULTIMATE_LEMMIX_SIGNING_IDENTITY or use --adhoc for local validation.'
fi

developer_dir="${DEVELOPER_DIR:-}"
if [[ -z "$developer_dir" ]]; then
  if [[ -x /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc ]]; then
    developer_dir=/Applications/Xcode.app/Contents/Developer
  else
    developer_dir="$(xcode-select -p)"
  fi
fi
if [[ -x "$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc" ]]; then
  swiftc="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
  sdk="${ULTIMATE_LEMMIX_SDKROOT:-$developer_dir/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk}"
else
  swiftc="$developer_dir/usr/bin/swiftc"
  sdk="${ULTIMATE_LEMMIX_SDKROOT:-$developer_dir/SDKs/MacOSX.sdk}"
fi
[[ -x "$swiftc" && -d "$sdk" ]] || fail 'Choose one installed developer directory with a Swift compiler and matching macOS SDK.'
sdk="${sdk:A}"
for tool in python3 codesign otool lipo; do
  command -v "$tool" >/dev/null || fail "The required build tool is missing: $tool"
done

architectures=(arm64 x86_64)
[[ -n "${ULTIMATE_LEMMIX_ARCHITECTURES:-}" ]] && architectures=("${(@s: :)ULTIMATE_LEMMIX_ARCHITECTURES}")
for architecture in "${architectures[@]}"; do
  [[ "$architecture" == arm64 || "$architecture" == x86_64 ]] || fail 'Supported architectures are arm64 and x86_64.'
done
deployment_target=12.3
optimisation="${ULTIMATE_LEMMIX_SWIFT_OPTIMIZATION:--O}"
module_cache="${ULTIMATE_LEMMIX_MODULE_CACHE:-$build_dir/XcodeModuleCache}"
mkdir -p "$module_cache" "$contents_dir/MacOS" "$contents_dir/Frameworks"
library_inputs=()
executable_inputs=()
python3 -B - "$project_dir" "$build_dir/source-inputs.json" <<'PYINPUTS'
from pathlib import Path
import sys
sys.path.insert(0, str(Path(sys.argv[1]) / 'Tools/AlternativeAssets'))
from store_resources import record_build_inputs
record_build_inputs(Path(sys.argv[2]))
PYINPUTS

for architecture in "${architectures[@]}"; do
  architecture_dir="$build_dir/$architecture"
  module_dir="$architecture_dir/modules"
  mkdir -p "$module_dir"
  target="$architecture-apple-macosx$deployment_target"
  compatibility=()
  [[ "$architecture" == x86_64 ]] && compatibility=(-runtime-compatibility-version none)
  "$swiftc" -swift-version 6 "$optimisation" -sdk "$sdk" -target "$target" "${compatibility[@]}" \
    -module-cache-path "$module_cache" -parse-as-library -emit-module -emit-library \
    -module-name NxlvKit -emit-module-path "$module_dir/NxlvKit.swiftmodule" \
    -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib -Xlinker -w \
    -o "$architecture_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
  "$swiftc" -swift-version 6 "$optimisation" -sdk "$sdk" -target "$target" "${compatibility[@]}" \
    -DULTIMATE_LEMMIX_STORE -module-cache-path "$module_cache" \
    -I "$module_dir" -L "$architecture_dir" -lNxlvKit \
    -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks -Xlinker -w \
    -o "$architecture_dir/UltimateLemmix" "$project_dir"/Sources/LemmingsLocal/*.swift
  library_inputs+=("$architecture_dir/libNxlvKit.dylib")
  executable_inputs+=("$architecture_dir/UltimateLemmix")
done

if (( ${#architectures} == 1 )); then
  cp "${library_inputs[1]}" "$contents_dir/Frameworks/libNxlvKit.dylib"
  cp "${executable_inputs[1]}" "$contents_dir/MacOS/UltimateLemmix"
else
  lipo -create "${library_inputs[@]}" -output "$contents_dir/Frameworks/libNxlvKit.dylib"
  lipo -create "${executable_inputs[@]}" -output "$contents_dir/MacOS/UltimateLemmix"
fi

signing_args=(--force --sign "$identity")
app_signing_options=(--options 0x0)
if (( !adhoc )); then
  signing_args+=(--timestamp)
  app_signing_options=(--options runtime)
fi
codesign "${signing_args[@]}" "$contents_dir/Frameworks/libNxlvKit.dylib"
codesign "${signing_args[@]}" "${app_signing_options[@]}" \
  --entitlements "$project_dir/Resources/UltimateLemmix/AppStore.entitlements" "$app_dir"
audit_bundle
python3 -B - "$project_dir" "$build_dir/build-evidence.json" "$swiftc" "$sdk" "$identity" \
  "$contents_dir/Resources/store-resources-manifest.json" "${architectures[@]}" <<'PYEVIDENCE'
from pathlib import Path
import sys
root, output, compiler, sdk, identity, inventory, *architectures = sys.argv[1:]
sys.path.insert(0, str(Path(root) / 'Tools/AlternativeAssets'))
from store_resources import write_build_evidence
write_build_evidence(Path(output), compiler, Path(sdk), identity, architectures, Path(inventory))
PYEVIDENCE
(( adhoc )) && print 'Ad-hoc local validation build. This is not a Mac App Store submission archive.'
print "$app_dir"
