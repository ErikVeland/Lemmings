#!/bin/zsh
# Build, sign, notarise and verify a local Developer ID distribution archive.
#
# Required environment variables:
#   SIGNING_IDENTITY  Developer ID Application certificate name
#   NOTARY_PROFILE    xcrun notarytool keychain profile name
#
# The signing identity is discovered when it is omitted. Credentials are never
# accepted on the command line or written to disk by this script.
set -euo pipefail

project_dir="${0:A:h:h}"
build_root="${BUILD_ROOT:-$project_dir/.build/notarised}"
build_root="${build_root:A}"
dry_run=0

usage() {
  print "Usage: zsh Scripts/build-and-notarise.sh [--dry-run]"
  print
  print "Builds a universal macOS app, signs it with Developer ID, submits it"
  print "to Apple, staples the ticket, and verifies the downloaded ZIP."
  print
  print "Environment:"
  print "  SIGNING_IDENTITY  optional Developer ID Application certificate name"
  print "  NOTARY_PROFILE    required xcrun notarytool keychain profile"
  print "  BUILD_ROOT        optional output directory"
}

while (( $# )); do
  case "$1" in
    --dry-run) dry_run=1 ;;
    --help|-h) usage; exit 0 ;;
    *) print -u2 "Unknown option: $1"; usage >&2; exit 2 ;;
  esac
  shift
done

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Resources/Info.plist")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$project_dir/Resources/Info.plist")"
stamp="$(date +%Y%m%d-%H%M%S)"
run_dir="$build_root/$version-$build_number-$stamp"
app_dir="$run_dir/Ultimate Lemmings.app"
submission_zip="$run_dir/UltimateLemmings-$version-build$build_number-submission.zip"
final_zip="$run_dir/UltimateLemmings-$version-build$build_number-notarised.zip"

signing_identity="${SIGNING_IDENTITY:-${BETA_SIGNING_IDENTITY:-}}"
notary_profile="${NOTARY_PROFILE:-${BETA_NOTARY_PROFILE:-}}"
if [[ -z "$signing_identity" ]]; then
  signing_identity="$(security find-identity -v -p codesigning 2>/dev/null |
    awk -F'"' '/Developer ID Application:/ { print $2; exit }')"
fi

if [[ -z "$signing_identity" ]]; then
  print -u2 "No Developer ID Application identity was found. Set SIGNING_IDENTITY."
  exit 1
fi
if [[ -z "$notary_profile" ]]; then
  print -u2 "No notarytool keychain profile was supplied. Set NOTARY_PROFILE."
  exit 1
fi

print "Project:  $project_dir"
print "Version:  $version ($build_number)"
print "Identity: $signing_identity"
print "Profile:  $notary_profile"
print "Output:   $run_dir"

if (( dry_run )); then
  print "Dry run: no build, signing or upload performed."
  exit 0
fi

mkdir -p "$run_dir"

print "==> Building universal app"
ENABLE_APPLE_CAPABILITIES=0 LEMMINGS_BUILD_DIR="$run_dir" \
  zsh "$project_dir/Scripts/build-local-app.sh" >/dev/null

print "==> Signing with Developer ID"
codesign --force --deep --options runtime --timestamp \
  --sign "$signing_identity" "$app_dir"

print "==> Verifying the app signature"
codesign --verify --deep --strict --verbose=1 "$app_dir"

print "==> Creating submission archive"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$submission_zip"

print "==> Submitting to Apple notarisation"
xcrun notarytool submit "$submission_zip" \
  --keychain-profile "$notary_profile" --wait

print "==> Stapling and validating the ticket"
xcrun stapler staple "$app_dir"
xcrun stapler validate "$app_dir"

print "==> Creating final notarised archive"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$final_zip"

print "==> Verifying the extracted archive with Gatekeeper"
verify_dir="$(mktemp -d "${TMPDIR:-/tmp}/lemmings-notarise.XXXXXX")"
trap 'rm -rf -- "$verify_dir"' EXIT
ditto -x -k "$final_zip" "$verify_dir"
verify_app="$verify_dir/$(basename "$app_dir")"
xattr -w com.apple.quarantine "0083;00000000;Safari;" "$verify_app"
gatekeeper_output="$(spctl -a -vv --type execute "$verify_app" 2>&1)" || {
  print -u2 -- "$gatekeeper_output"
  exit 1
}
print -- "$gatekeeper_output"

print
print "Notarised archive: $final_zip"
print "SHA-256: $(shasum -a 256 "$final_zip" | awk '{ print $1 }')"
