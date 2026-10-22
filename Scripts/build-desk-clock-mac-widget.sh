#!/bin/zsh
# Build the shared widget against the Mac app's existing modules and libraries.
set -euo pipefail
project_dir="${0:A:h:h}"
app_dir="$1"
build_dir="$2"
shift 2
architectures=("$@")
[[ ${#architectures} -gt 0 ]] || architectures=("$(uname -m)")
widget="$app_dir/Contents/PlugIns/DeskClockMacWidget.appex"
mkdir -p "$widget/Contents/MacOS" "$widget/Contents/Resources"
inputs=()
for architecture in "${architectures[@]}"; do
  compatibility=()
  [[ "$architecture" == x86_64 ]] && compatibility=(-runtime-compatibility-version none)
  swiftc "${compatibility[@]}" -swift-version 6 -parse-as-library -application-extension \
    -target "$architecture-apple-macosx12.3" \
    -module-cache-path "$build_dir/ModuleCache" \
    -I "$build_dir/$architecture/modules" -L "$build_dir/$architecture" \
    -lLemmingsGameArt -lLemmingsMobileCore -lLemmingsAppCore -lLemmingsTVCore -lNxlvKit \
    -framework SwiftUI -framework WidgetKit \
    -Xlinker -rpath -Xlinker @executable_path/../../../../Frameworks \
    -o "$build_dir/$architecture/DeskClockMacWidget" \
    "$project_dir/Apps/DeskClockWidget/DeskClockWidget.swift"
  inputs+=("$build_dir/$architecture/DeskClockMacWidget")
done
if (( ${#inputs} == 1 )); then
  cp "${inputs[1]}" "$widget/Contents/MacOS/DeskClockMacWidget"
else
  lipo -create "${inputs[@]}" -output "$widget/Contents/MacOS/DeskClockMacWidget"
fi
python3 - "$project_dir" "$widget" <<'PY'
from pathlib import Path
import plistlib, sys
root, widget = map(Path, sys.argv[1:])
info = plistlib.loads((root / 'Apps/DeskClockWidget/Mac/Info.plist').read_bytes())
app = plistlib.loads((widget.parents[1] / 'Info.plist').read_bytes())
info.update(CFBundleIdentifier=app['CFBundleIdentifier'] + '.DeskClockWidget',
            CFBundleExecutable='DeskClockMacWidget', CFBundleName='DeskClockMacWidget',
            CFBundleShortVersionString=app['CFBundleShortVersionString'],
            CFBundleVersion=app['CFBundleVersion'], LSMinimumSystemVersion='12.3')
(widget / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
PY
artwork="${MAC_ARTWORK_DIR:-$app_dir/Contents/Resources/MacArtwork/lemmings}"
python3 "$project_dir/Tools/DeskClock/prune_artwork.py" --source "$artwork" --destination "$widget/Contents/Resources/MacArtwork/lemmings"
cp "$project_dir/Apps/UltimateLemmingsIOS/PrivacyInfo.xcprivacy" "$widget/Contents/Resources/PrivacyInfo.xcprivacy"
codesign --force --sign - --entitlements "$project_dir/Apps/DeskClockWidget/Mac/DeskClockMacWidget.entitlements" "$widget"
print "PASS Desk Clock Mac extension: $widget"
