#!/bin/zsh
# Build the complete Mac Store candidate with the licensed resource inventory.
set -euo pipefail
project_dir="${0:A:h:h}"
fail() { print -u2 "FAILED: $*"; exit 1; }
resources_only=0
audit_only=0
adhoc=0
automatic_export=0
compiler_mode=build
for argument in "$@"; do
  case "$argument" in
    --resources-only) resources_only=1 ;;
    --audit) audit_only=1 ;;
    --adhoc) adhoc=1 ;;
    --automatic-export) automatic_export=1 ;;
    --finish) compiler_mode=finish ;;
    --help|-h)
      print -r -- 'Usage: build-ultimate-lemmix-app-store.sh [--adhoc|--automatic-export] [--resources-only] [--audit] [--finish]'
      print -r -- 'Set ULTIMATE_LEMMIX_BUILD_DIR to a dedicated output folder, including an external volume.'
      print -r -- '--automatic-export uses Apple Development signing, ULTIMATE_LEMMIX_TEAM_ID and authenticated Xcode export.'
      print -r -- 'Store signing requires ULTIMATE_LEMMIX_SIGNING_IDENTITY, ULTIMATE_LEMMIX_INSTALLER_IDENTITY,'
      print -r -- 'ULTIMATE_LEMMIX_APP_PROFILE and ULTIMATE_LEMMIX_WIDGET_PROFILE.'
      print -r -- 'Ad-hoc output is for local validation. It cannot be submitted to the App Store.'
      print -r -- 'Use ULTIMATE_LEMMIX_ARCHITECTURES="arm64" only with --adhoc for a local check.'
      print -r -- '--finish requires verified existing compiler outputs for every requested architecture.'
      exit 0 ;;
    *) fail "Unknown argument: $argument" ;;
  esac
done
python3 "$project_dir/Tools/Publication/publication.py" guard ultimate-lemmix
python3 "$project_dir/Tools/Localisation/catalogue.py" --release
python3 "$project_dir/Tools/Publication/publication.py" check --metadata-only --edition ultimate-lemmix
version="$(python3 "$project_dir/Tools/Publication/publication.py" field ultimate-lemmix macos version)"
build="$(python3 "$project_dir/Tools/Publication/publication.py" field ultimate-lemmix macos build)"
build_dir="${ULTIMATE_LEMMIX_BUILD_DIR:-$project_dir/.build/ultimate-lemmix-store-$version-build$build}"
build_dir="${build_dir:A}"
export ULTIMATE_LEMMIX_BUILD_DIR="$build_dir"
app_dir="$build_dir/Ultimate Lemmix.app"
contents_dir="$app_dir/Contents"
helper="$project_dir/Tools/Publication/mac_store.py"
architectures=(arm64 x86_64)
[[ -n "${ULTIMATE_LEMMIX_ARCHITECTURES:-}" ]] && architectures=("${(@s: :)ULTIMATE_LEMMIX_ARCHITECTURES}")
helper_args=(--build-dir "$build_dir" --architectures "${architectures[@]}")
(( adhoc )) && helper_args+=(--adhoc)
(( automatic_export )) && helper_args+=(--automatic-export)
python3 "$helper" validate-output "${helper_args[@]}"
resource_args=(--output "$contents_dir/Resources")
(( resources_only )) && resource_args+=(--allow-missing-integration)
if (( audit_only )); then
  python3 "$project_dir/Tools/AlternativeAssets/store_resources.py" "${resource_args[@]}" --audit
  (( resources_only )) || python3 "$helper" audit "${helper_args[@]}"
  exit 0
fi
if (( !resources_only )); then
  zsh "$project_dir/Scripts/check-release-history.sh" --edition ultimate-lemmix
  python3 "$helper" prepare-signing "${helper_args[@]}"
fi
mkdir -p "$contents_dir"
python3 "$project_dir/Tools/AlternativeAssets/store_resources.py" "${resource_args[@]}"
cp "$project_dir/Resources/UltimateLemmix/Info.plist" "$contents_dir/Info.plist"
if (( resources_only )); then
  print "Prepared local resources only: $app_dir"
  exit 0
fi
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export PATH="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin:$PATH"
sdk="${ULTIMATE_LEMMIX_SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
export SDKROOT="$sdk"
export CLANG_MODULE_CACHE_PATH="$build_dir/ClangModuleCache"
export SWIFT_MODULE_CACHE_PATH="$build_dir/ModuleCache"
export TMPDIR="$build_dir/Temporary/"
mkdir -p "$TMPDIR" "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULE_CACHE_PATH" "$contents_dir/MacOS" "$contents_dir/Frameworks"
python3 "$helper" snapshot "${helper_args[@]}"
for architecture in "${architectures[@]}"; do
  zsh "$project_dir/Scripts/build-mac-sources.sh" --edition ultimate-lemmix \
    --build-dir "$build_dir" --target "$architecture-apple-macosx12.3" --sdk "$sdk" \
    --optimization="${ULTIMATE_LEMMIX_SWIFT_OPTIMIZATION:--O}" --mode "$compiler_mode" \
    > "$build_dir/$architecture-compile.log" 2>&1
done
shared_modules=(NxlvKit LemmingsMobileCore LemmingsGameArt LemmingsAudio LemmingsAppCore LemmingsTVCore)
for binary in UltimateLemmix "${shared_modules[@]/#/lib}"; do
  filename="$binary"
  destination="$contents_dir/MacOS/$filename"
  if [[ "$binary" != UltimateLemmix ]]; then
    filename="$binary.dylib"
    destination="$contents_dir/Frameworks/$filename"
  fi
  inputs=()
  for architecture in "${architectures[@]}"; do
    inputs+=("$build_dir/$architecture/$filename")
  done
  if (( ${#inputs} == 1 )); then
    cp "${inputs[1]}" "$destination"
  else
    lipo -create "${inputs[@]}" -output "$destination"
  fi
done
ULTIMATE_LEMMIX_STORE=1 zsh "$project_dir/Scripts/build-desk-clock-mac-widget.sh" \
  "$app_dir" "$build_dir" "${architectures[@]}" > "$build_dir/widget-compile.log" 2>&1
cp "$contents_dir/Resources/PrivacyInfo.xcprivacy" \
  "$contents_dir/PlugIns/DeskClockMacWidget.appex/Contents/Resources/PrivacyInfo.xcprivacy"
python3 "$helper" sign "${helper_args[@]}"
python3 "$project_dir/Tools/AlternativeAssets/store_resources.py" "${resource_args[@]}" --audit
python3 "$helper" archive "${helper_args[@]}"
print 'Test suites and test-running release audits were skipped under the release policy.'
print "$app_dir"
