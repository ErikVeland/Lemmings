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
widget_flags=()
widget_entitlements="$project_dir/Apps/DeskClockWidget/Mac/DeskClockMacWidget.entitlements"
if [[ "${ULTIMATE_LEMMIX_STORE:-0}" == 1 ]]; then
  widget_flags=(-DULTIMATE_LEMMIX_STORE)
  widget_entitlements="$project_dir/Resources/UltimateLemmix/DeskClockMacWidget.entitlements"
fi
for architecture in "${architectures[@]}"; do
  compatibility=()
  [[ "$architecture" == x86_64 ]] && compatibility=(-runtime-compatibility-version none)
  # Initialise the extension host before macOS calls the Swift widget entry point.
  swiftc "${compatibility[@]}" "${widget_flags[@]}" -swift-version 6 -parse-as-library -application-extension \
    -target "$architecture-apple-macosx12.3" \
    -module-cache-path "$build_dir/ModuleCache" \
    -I "$build_dir/$architecture/modules" -L "$build_dir/$architecture" \
    -lLemmingsGameArt -lLemmingsMobileCore -lLemmingsAppCore -lLemmingsTVCore -lNxlvKit \
    -framework SwiftUI -framework WidgetKit \
    -Xlinker -e -Xlinker _NSExtensionMain \
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
info['DeskClockURLScheme'] = 'ultimatelemmix' if app.get('UltimateLemmixStore') else 'ultimatelemmings'
info['UltimateLemmixStore'] = bool(app.get('UltimateLemmixStore'))
if info['UltimateLemmixStore']:
    info.pop('NSCalendarsUsageDescription', None)
    info.pop('NSCalendarsFullAccessUsageDescription', None)
(widget / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
PY
if [[ "${ULTIMATE_LEMMIX_STORE:-0}" == 1 ]]; then
  mkdir -p "$widget/Contents/Resources/Fonts" "$widget/Contents/Resources/AlternativeAssets" "$widget/Contents/Resources/Licences"
  rsync -a "$app_dir/Contents/Resources/Fonts/LixInterface" "$widget/Contents/Resources/Fonts/"
  if [[ -d "$app_dir/Contents/Resources/Fonts/OriginalLemmings" ]]; then
    rsync -a "$app_dir/Contents/Resources/Fonts/OriginalLemmings" "$widget/Contents/Resources/Fonts/"
  fi
  rsync -a "$app_dir/Contents/Resources/Fonts/Lix" "$widget/Contents/Resources/Fonts/"
  rsync -a "$app_dir/Contents/Resources/AlternativeAssets/Lix" "$widget/Contents/Resources/AlternativeAssets/"
  cp "$app_dir/Contents/Resources/Licences/Lix-font-LICENSE.txt" "$widget/Contents/Resources/Licences/"
else
artwork="${MAC_ARTWORK_DIR:-$app_dir/Contents/Resources/MacArtwork/lemmings}"
python3 "$project_dir/Tools/DeskClock/prune_artwork.py" \
  --source "$artwork" --destination "$widget/Contents/Resources/MacArtwork/lemmings"
fi
cp "$project_dir/Apps/UltimateLemmingsIOS/PrivacyInfo.xcprivacy" "$widget/Contents/Resources/PrivacyInfo.xcprivacy"
codesign --force --sign - --entitlements "$widget_entitlements" "$widget"
print "PASS Desk Clock Mac extension: $widget"
