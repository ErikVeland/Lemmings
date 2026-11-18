#!/bin/zsh
# Build a current-architecture manual candidate from the full application modules.
set -euo pipefail
project_dir="${0:A:h:h}"
python3 "$project_dir/Tools/Publication/publication.py" guard ultimate-lemmix
python3 "$project_dir/Tools/Publication/publication.py" check --metadata-only --edition ultimate-lemmix
publication_version="$(python3 "$project_dir/Tools/Publication/publication.py" field ultimate-lemmix macos version)"
publication_build="$(python3 "$project_dir/Tools/Publication/publication.py" field ultimate-lemmix macos build)"
build_dir="${ULTIMATE_LEMMIX_BUILD_DIR:-$project_dir/.build/ultimate-lemmix-$publication_version-build$publication_build}"
architecture="$(uname -m)"
target="$architecture-apple-macosx12.3"
developer_dir=/Applications/Xcode.app/Contents/Developer
export PATH="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH"
sdk="$developer_dir/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
export SDKROOT="$sdk"
module_dir="$build_dir/$architecture/modules"
export CLANG_MODULE_CACHE_PATH="$build_dir/ClangModuleCache"
export SWIFT_MODULE_CACHE_PATH="$build_dir/ModuleCache"
mkdir -p "$module_dir" "$build_dir/ModuleCache" "$build_dir/ClangModuleCache"
app="$build_dir/Ultimate Lemmix.app"
reuse_core=0
core_only=0
resources_only=0
frontend_only=0
finish_only=0
for argument in "$@"; do
  case "$argument" in
    --reuse-core) reuse_core=1 ;;
    --core-only) core_only=1 ;;
    --resources-only) resources_only=1 ;;
    --frontend-only) frontend_only=1 ;;
    --finish) finish_only=1 ;;
    *) print -u2 "Unknown build option: $argument"; exit 1 ;;
  esac
done
compiler_arguments=(--edition ultimate-lemmix --build-dir "$build_dir" --target "$target" --sdk "$sdk")
core_arguments=(--mode core-only)
(( reuse_core || frontend_only || finish_only )) && core_arguments+=(--reuse-core)
if (( !resources_only )); then
  zsh "$project_dir/Scripts/build-mac-sources.sh" "${compiler_arguments[@]}" "${core_arguments[@]}" \
    > "$build_dir/core-compile.log" 2>&1
fi
(( core_only )) && exit 0
mkdir -p "$app/Contents/Resources" "$app/Contents/MacOS" "$app/Contents/Frameworks"
cp "$project_dir/Resources/UltimateLemmix/Info.plist" "$app/Contents/Info.plist"
if [[ ! -f "$build_dir/resources-ready" ]]; then
python3 -B "$project_dir/Tools/AlternativeAssets/prepare_lemmix_base.py" \
  --output "$app/Contents/Resources" \
  --alternative-resources "${ULTIMATE_LEMMIX_ALTERNATIVE_RESOURCES:?Set the verified alternative media resource directory.}"
zsh "$project_dir/Scripts/prepare-lix-interface.sh" \
  --font "$app/Contents/Resources/Fonts/Lix/djvusans.ttf" \
  --licence "$app/Contents/Resources/Licences/Lix-font-LICENSE.txt" \
  --output "$app/Contents/Resources/Fonts/LixInterface"
zsh "$project_dir/Scripts/build-app-icon.sh" "$app/Contents/Resources/AppIcon.icns"
cp "$project_dir/Apps/UltimateLemmingsIOS/PrivacyInfo.xcprivacy" "$app/Contents/Resources/PrivacyInfo.xcprivacy"
touch "$build_dir/resources-ready"
fi
font_source="${ULTIMATE_LEMMIX_ORIGINAL_FONT_SOURCE:-$project_dir}"
if [[ ! -f "$font_source/.build/mac-artwork/export/lemmings/manifest.json" && -z "${ULTIMATE_LEMMIX_ORIGINAL_FONT_SOURCE:-}" ]]; then
  common_git_dir="$(git -C "$project_dir" rev-parse --path-format=absolute --git-common-dir)"
  font_source="${common_git_dir:h}"
fi
python3 -B "$project_dir/Tools/AlternativeAssets/prepare_original_font.py" --source-root "$font_source"
ditto "$project_dir/.build/personal-preview-assets/Fonts/OriginalLemmings" \
  "$app/Contents/Resources/Fonts/OriginalLemmings"
/usr/libexec/PlistBuddy -c 'Add :UltimateLemmixPersonalPreview bool true' "$app/Contents/Info.plist"
if [[ -n "${ULTIMATE_LEMMIX_LOCAL_GAME_RESOURCES:-}" ]]; then
  for family in Ports NeoLemmix LevelPacks MacArtwork AmigaArtwork; do
    [[ -d "$ULTIMATE_LEMMIX_LOCAL_GAME_RESOURCES/$family" ]] || { print -u2 "Missing local game resources: $family"; exit 1; }
    ditto "$ULTIMATE_LEMMIX_LOCAL_GAME_RESOURCES/$family" "$app/Contents/Resources/$family"
  done
fi
if [[ -n "${ULTIMATE_LEMMIX_LOCAL_CONTENT:-}" ]]; then
  for family in NeoLemmix LevelPacks; do
    [[ -d "$ULTIMATE_LEMMIX_LOCAL_CONTENT/$family" ]] || { print -u2 "Missing local level collection: $family"; exit 1; }
    ditto "$ULTIMATE_LEMMIX_LOCAL_CONTENT/$family" "$app/Contents/Resources/$family"
  done
fi
if [[ -n "${ULTIMATE_LEMMIX_LOCAL_NEO_STYLES:-}" ]]; then
  [[ -d "$ULTIMATE_LEMMIX_LOCAL_NEO_STYLES" ]] || { print -u2 'Missing local NeoLemmix styles folder.'; exit 1; }
  ditto "$ULTIMATE_LEMMIX_LOCAL_NEO_STYLES" "$app/Contents/Resources/NeoLemmix/styles"
fi
python3 -B "$project_dir/Tools/AlternativeAssets/prepare_open_starter.py" \
  --output "$app/Contents/Resources/Ports/ultimate_lemmix_starter"
python3 -B "$project_dir/Tools/AlternativeAssets/prepare_open_starter.py" \
  --output "$app/Contents/Resources/Ports/ultimate_lemmix_starter" --check
mkdir -p "$app/Contents/Resources/MenuArtwork"
cp "$project_dir/Resources/UltimateLemmix/MenuArtwork/ultimate-lemmix.png" "$app/Contents/Resources/MenuArtwork/"
(( resources_only )) && exit 0
compiler_mode=build
(( frontend_only )) && compiler_mode=frontend-only
(( finish_only )) && compiler_mode=finish
zsh "$project_dir/Scripts/build-mac-sources.sh" "${compiler_arguments[@]}" --reuse-core --mode "$compiler_mode" \
  > "$build_dir/source-compile.log" 2>&1
shared_modules=(LemmingsMobileCore LemmingsGameArt LemmingsAudio LemmingsAppCore LemmingsTVCore)
(( frontend_only )) && exit 0
cp "$build_dir/$architecture/UltimateLemmix" "$app/Contents/MacOS/UltimateLemmix"
for module in NxlvKit "${shared_modules[@]}"; do
  cp "$build_dir/$architecture/lib$module.dylib" "$app/Contents/Frameworks/"
  codesign --force --sign - --options 0x0 "$app/Contents/Frameworks/lib$module.dylib"
done
ULTIMATE_LEMMIX_STORE=1 zsh "$project_dir/Scripts/build-desk-clock-mac-widget.sh" "$app" "$build_dir" "$architecture" \
  > "$build_dir/widget-compile.log" 2>&1
codesign --force --sign - --options 0x0 --entitlements \
  "$project_dir/Resources/UltimateLemmix/AppStore.entitlements" "$app"
manual_app="${ULTIMATE_LEMMIX_DOWNLOAD_APP:-$HOME/Downloads/Ultimate Lemmix $publication_version build$publication_build.app}"
[[ ! -e "$manual_app" ]] || { print -u2 'Choose a new manual app path; an existing app will not be replaced.'; exit 1; }
ditto "$app" "$manual_app"
python3 - "$manual_app" <<'PY'
from pathlib import Path
import plistlib, sys
app = Path(sys.argv[1])
identifier = 'academy.glasscode.ultimatelemmix.personal-review.build3'
path = app / 'Contents/Info.plist'
info = plistlib.loads(path.read_bytes()); info['CFBundleIdentifier'] = identifier
path.write_bytes(plistlib.dumps(info))
widget = app / 'Contents/PlugIns/DeskClockMacWidget.appex/Contents/Info.plist'
info = plistlib.loads(widget.read_bytes()); info['CFBundleIdentifier'] = identifier + '.DeskClockWidget'
widget.write_bytes(plistlib.dumps(info))
PY
codesign --force --sign - --options 0x0 --entitlements \
  "$project_dir/Resources/UltimateLemmix/DeskClockMacWidget.entitlements" \
  "$manual_app/Contents/PlugIns/DeskClockMacWidget.appex"
codesign --force --sign - --options 0x0 --entitlements \
  "$project_dir/Resources/UltimateLemmix/AppStore.entitlements" "$manual_app"
codesign --verify --deep "$manual_app"
print 'Manual current-architecture build. Test suites, release audits, Intel and notarisation were skipped.'
print "$manual_app"
