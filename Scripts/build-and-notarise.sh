#!/bin/zsh
# Build, gate, sign, notarise and verify the three local macOS release targets.
#
# Sparkle replaces the whole app bundle, so every build that can replace an
# installed copy carries the full soundtrack. Only the public fresh-install
# download is slim; it offers the other versions as optional libraries.
#
# Authentication options:
#   NOTARY_PROFILE    xcrun notarytool keychain profile name
#   NOTARY_KEYCHAIN   optional keychain file containing that profile
#   APPLE_ID          Apple ID for secure notarytool password prompt
#   APPLE_TEAM_ID     Apple Developer team ID for Apple ID authentication
#   ASC_KEY_PATH      App Store Connect API private key path
#   ASC_KEY_ID        App Store Connect API key ID
#   ASC_ISSUER_ID     App Store Connect API issuer ID
#
# SIGNING_IDENTITY is optional and defaults to the first installed Developer ID
# Application identity. A password is never accepted as a script argument or
# environment variable.
#
# Optional environment variables:
#   RELEASE_BASE      commit or tag at the previous release boundary
#   RELEASE_NOTES_PATH path for the reviewed release notes draft
#   MONTEREY_WORKTREE macOS 12 worktree, default .claude/worktrees/macos12
#   DOWNLOADS_DIR     destination for the three final ZIP files
#   BUILD_ROOT        internal build output directory
#   UPDATES_DIR       Sparkle update archives and appcast working directory
#   RELEASE_TAG       public GitHub release tag, default vMAJOR.MINOR.0
#   DOWNLOAD_URL_PREFIX public HTTPS URL prefix for Sparkle update archives
#   APPLE_PROVISIONING_PROFILE  Game Center provisioning profile
#
# Credentials are never accepted on the command line or written to disk by
# this script. The Game Center target is signed for registered devices and
# cannot be notarised by Apple's notary service.
set -euo pipefail

project_dir="${0:A:h:h}"
build_root="${BUILD_ROOT:-$project_dir/.build/notarised}"
build_root="${build_root:A}"
downloads_dir="${DOWNLOADS_DIR:-$HOME/Downloads}"
downloads_dir="${downloads_dir:A}"
updates_dir="${UPDATES_DIR:-$project_dir/.build/updates}"
updates_dir="${updates_dir:A}"
monterey_worktree="${MONTEREY_WORKTREE:-$project_dir/.claude/worktrees/macos12}"
monterey_worktree="${monterey_worktree:A}"
dry_run=0

usage() {
  print "Usage: zsh Scripts/build-and-notarise.sh [--dry-run] [--notary-profile NAME] [--notary-keychain PATH]"
  print
  print "Runs the local release gates, then emits three ZIP files in Downloads:"
  print "  Developer ID standard, macOS 12 Monterey, and Game Center."
  print
  print "Environment:"
  print "  SIGNING_IDENTITY            optional Developer ID certificate name"
  print "  NOTARY_PROFILE              optional notarytool keychain profile"
  print "  NOTARY_KEYCHAIN             optional keychain file for the profile"
  print "  APPLE_ID                    optional Apple ID; notarytool prompts for password"
  print "  APPLE_TEAM_ID               team ID used with APPLE_ID"
  print "  ASC_KEY_PATH                App Store Connect API private key path"
  print "  ASC_KEY_ID                  App Store Connect API key ID"
  print "  ASC_ISSUER_ID               App Store Connect API issuer ID"
  print "  RELEASE_BASE                previous release commit or tag"
  print "  RELEASE_NOTES_PATH          current release notes file"
  print "  MONTEREY_WORKTREE           macOS 12 worktree path"
  print "  APPLE_PROVISIONING_PROFILE  Game Center profile path"
  print "  DOWNLOADS_DIR               ZIP destination, default ~/Downloads"
  print "  BUILD_ROOT                  internal build output directory"
  print "  UPDATES_DIR                 Sparkle update archive directory"
  print "  RELEASE_TAG                 public release tag, default vMAJOR.MINOR.0"
  print "  DOWNLOAD_URL_PREFIX         public HTTPS URL prefix for update archives"
  print "  Publication is a separate step after package and hardware checks."
}

fail() {
  print -u2 "FAILED: $*"
  exit 1
}

while (( $# )); do
  case "$1" in
    --dry-run) dry_run=1 ;;
    --notary-profile)
      (( $# >= 2 )) || { print -u2 "--notary-profile requires a name."; exit 2; }
      notary_profile_argument="$2"
      shift
      ;;
    --notary-keychain)
      (( $# >= 2 )) || { print -u2 "--notary-keychain requires a path."; exit 2; }
      notary_keychain_argument="$2"
      shift
      ;;
    --help|-h) usage; exit 0 ;;
    *) print -u2 "Unknown option: $1"; usage >&2; exit 2 ;;
  esac
  shift
done

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Resources/Info.plist")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$project_dir/Resources/Info.plist")"
stamp="$(date +%Y%m%d-%H%M%S)"
run_dir="$build_root/$version-$build_number-$stamp"

signing_identity="${SIGNING_IDENTITY:-${BETA_SIGNING_IDENTITY:-}}"
notary_profile="${notary_profile_argument:-${NOTARY_PROFILE:-${BETA_NOTARY_PROFILE:-}}}"
notary_keychain="${notary_keychain_argument:-${NOTARY_KEYCHAIN:-}}"
apple_id="${APPLE_ID:-}"
apple_team_id="${APPLE_TEAM_ID:-}"
asc_key_path="${ASC_KEY_PATH:-}"
asc_key_id="${ASC_KEY_ID:-}"
asc_issuer_id="${ASC_ISSUER_ID:-}"
if [[ -z "$signing_identity" ]]; then
  signing_identity="$(security find-identity -v -p codesigning 2>/dev/null |
    awk -F'"' '/Developer ID Application:/ { print $2; exit }')"
fi
[[ -n "$signing_identity" ]] || fail "No Developer ID Application identity was found. Set SIGNING_IDENTITY."
[[ "${PUBLISH_GITHUB_RELEASE:-0}" == 0 ]] ||
  fail "Package first. Publish only after review with Scripts/publish-github-release.sh."
if [[ -n "$notary_keychain" ]]; then
  notary_keychain="${notary_keychain:A}"
  [[ -r "$notary_keychain" ]] || fail "The notary keychain is not readable: $notary_keychain"
fi
if [[ -n "$notary_profile" ]]; then
  notary_auth_mode="keychain profile"
  notary_auth_description="keychain profile '$notary_profile'"
  notary_auth_args=(--keychain-profile "$notary_profile")
  if [[ -n "$notary_keychain" ]]; then
    notary_auth_args+=(--keychain "$notary_keychain")
  fi
elif [[ -n "$asc_key_path" || -n "$asc_key_id" || -n "$asc_issuer_id" ]]; then
  [[ -n "$asc_key_path" && -n "$asc_key_id" && -n "$asc_issuer_id" ]] ||
    fail "ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID must be supplied together."
  asc_key_path="${asc_key_path:A}"
  [[ -r "$asc_key_path" ]] || fail "The App Store Connect private key is not readable: $asc_key_path"
  notary_auth_mode="App Store Connect API key"
  notary_auth_description="App Store Connect API key '$asc_key_id'"
  notary_auth_args=(--key "$asc_key_path" --key-id "$asc_key_id" --issuer "$asc_issuer_id")
elif [[ -n "$apple_id" || -n "$apple_team_id" ]]; then
  [[ -n "$apple_id" && -n "$apple_team_id" ]] ||
    fail "APPLE_ID and APPLE_TEAM_ID must be supplied together."
  notary_auth_mode="Apple ID"
  notary_auth_description="Apple ID $apple_id"
  notary_auth_args=(--apple-id "$apple_id" --team-id "$apple_team_id")
else
  fail "No notarisation credentials configured. Set NOTARY_PROFILE, APPLE_ID plus APPLE_TEAM_ID, or ASC_KEY_PATH plus ASC_KEY_ID plus ASC_ISSUER_ID."
fi

git_root="$(git -C "$project_dir" rev-parse --show-toplevel 2>/dev/null)" ||
  fail "The project directory is not a Git worktree."
[[ "$git_root" == "$project_dir" ]] || fail "The script must run from the project worktree."
current_head="$(git -C "$project_dir" rev-parse HEAD)"
current_short="${current_head[1,7]}"
[[ -z "$(git -C "$project_dir" status --porcelain --untracked-files=all)" ]] ||
  fail "Release packaging requires a clean worktree. Commit the release source first."

release_base="${RELEASE_BASE:-}"
[[ -n "$release_base" || "$version" != 1.5 ]] || release_base="v1.2-build41"
[[ -n "$release_base" || "$version" != 1.6 ]] || release_base="v1.5.0"
[[ -n "$release_base" ]] || fail "Set RELEASE_BASE to the previous release commit or tag."
git -C "$project_dir" rev-parse --verify "$release_base^{commit}" >/dev/null 2>&1 ||
  fail "RELEASE_BASE does not resolve to a commit: $release_base"
git -C "$project_dir" merge-base --is-ancestor "$release_base" "$current_head" ||
  fail "RELEASE_BASE is not an ancestor of the release commit: $release_base"

# Gate 1: the candidate must contain source changes after the previous release.
source_changes="$(git -C "$project_dir" diff --name-only "$release_base" -- Sources)"
[[ -n "$source_changes" ]] || fail "No new source code exists after $release_base."

release_notes_draft="${RELEASE_NOTES_PATH:-$project_dir/Documentation/ReleaseNotes-$version-build$build_number.md}"
release_notes_draft="${release_notes_draft:A}"
[[ -f "$release_notes_draft" ]] ||
  fail "Review and commit release notes for build $build_number: $release_notes_draft"
git -C "$project_dir" ls-files --error-unmatch -- "$release_notes_draft" >/dev/null 2>&1 ||
  fail "The release notes draft must be tracked in this worktree: $release_notes_draft"
python3 "$project_dir/Tools/ReleaseReadiness/release_notes.py" \
  --draft "$release_notes_draft" --build "$build_number" --base "$release_base" \
  --commit "$current_head" --check || fail "The release notes draft is not current."

[[ -x "$project_dir/Scripts/build-local-app.sh" ]] || fail "Missing build-local-app.sh."
[[ -x "$monterey_worktree/Scripts/build-local-app.sh" ]] ||
  fail "Missing Monterey worktree at $monterey_worktree. Set MONTEREY_WORKTREE."
monterey_head="$(git -C "$monterey_worktree" rev-parse HEAD 2>/dev/null)" ||
  fail "Monterey path is not a Git worktree: $monterey_worktree"
[[ "$monterey_head" == "$current_head" ]] ||
  fail "The Monterey worktree must use the exact release commit $current_short."
[[ -z "$(git -C "$monterey_worktree" status --porcelain --untracked-files=all)" ]] ||
  fail "The Monterey worktree has uncommitted changes."

check_release_snapshot() {
  [[ "$(git -C "$project_dir" rev-parse HEAD)" == "$current_head" ]] ||
    fail "The release commit changed during packaging. Discard these archives."
  # The generator changes only the tracked appcast after the clean-source check.
  [[ -z "$(git -C "$project_dir" status --porcelain --untracked-files=all -- . ':(exclude)appcast.xml')" ]] ||
    fail "The release source changed during packaging. Discard these archives."
  [[ "$(git -C "$monterey_worktree" rev-parse HEAD)" == "$current_head" ]] ||
    fail "The Monterey commit changed during packaging. Discard these archives."
  [[ -z "$(git -C "$monterey_worktree" status --porcelain --untracked-files=all)" ]] ||
    fail "The Monterey source changed during packaging. Discard these archives."
}

print "Project:       $project_dir"
print "Version:       $version ($build_number)"
print "Release base:  $release_base"
print "Identity:      $signing_identity"
print "Notary auth:   $notary_auth_description"
print "Monterey:      $monterey_worktree"
print "Downloads:     $downloads_dir"
print "Updates:       $updates_dir"
print
print "Gate 1: source changes present"
print -r -- "$source_changes"
print "Gate 2-3: release notes current"
print "             $release_notes_draft"
print "Gate 4: three target archives configured"
# Stale proofs or hints do not stop a build. The app then hides rescue
# targets and level hints without a message.
python3 "$project_dir/Tools/TrolleyVerification/catalogue.py" check ||
  fail "Rescue proofs do not match the engine. Run Scripts/verify-trolley-maxima.sh."
python3 - "$project_dir" <<'CHECK_HINTS' ||
import json, pathlib, sys
root = pathlib.Path(sys.argv[1]) / 'Resources'
proofs = json.loads((root / 'Trolley/verified-maxima.json').read_text())
hints = json.loads((root / 'Hints/classic.json').read_text())
sys.exit(hints['engineFingerprint'] != proofs['engineSourceFingerprint'])
CHECK_HINTS
  fail "Level hints do not match the engine. Run Scripts/generate-level-hints.sh."
print "Gate 5: rescue proofs and level hints match the engine"
print "Gate 6: app integration tests run on the standard build"
print "Gate 7: each signed target launches as a new user"

if (( dry_run )); then
  print "Dry run: no build, signing, notarisation or upload performed."
  exit 0
fi

if [[ "$notary_auth_mode" != "Apple ID" ]]; then
  print "==> Checking $notary_auth_mode credentials"
  notary_auth_output=""
  if ! notary_auth_output="$(xcrun notarytool history \
    "${notary_auth_args[@]}" --output-format json --no-progress 2>&1)"; then
    print -u2 -r -- "$notary_auth_output"
    fail "notarytool could not use $notary_auth_description. Check the credential, keychain and account access."
  fi
else
  print "==> Apple ID credentials will be requested securely by notarytool"
fi

mkdir -p "$run_dir" "$downloads_dir"
release_notes="$run_dir/ReleaseNotes-$version-build$build_number.md"
python3 "$project_dir/Tools/ReleaseReadiness/release_notes.py" \
  --draft "$release_notes_draft" --build "$build_number" --base "$release_base" \
  --commit "$current_head" --output "$release_notes"

build_app() {
  local source_dir="$1" output_dir="$2" capabilities="$3"
  export MUSIC_BUNDLE="${4:-full}"
  # Both worktrees share one encoder cache, keyed by source content.
  export MUSIC_AAC_CACHE="${MUSIC_AAC_CACHE:-$project_dir/.build/music-aac}"
  if [[ "$capabilities" == 1 ]]; then
    if [[ -n "${APPLE_PROVISIONING_PROFILE:-}" ]]; then
      (cd "$source_dir" && ENABLE_APPLE_CAPABILITIES=1 \
        APPLE_PROVISIONING_PROFILE="$APPLE_PROVISIONING_PROFILE" \
        LEMMINGS_BUILD_DIR="$output_dir" zsh Scripts/build-local-app.sh >/dev/null)
    else
      (cd "$source_dir" && ENABLE_APPLE_CAPABILITIES=1 \
        LEMMINGS_BUILD_DIR="$output_dir" zsh Scripts/build-local-app.sh >/dev/null)
    fi
  else
    (cd "$source_dir" && ENABLE_APPLE_CAPABILITIES=0 \
      LEMMINGS_BUILD_DIR="$output_dir" zsh Scripts/build-local-app.sh >/dev/null)
  fi
}

sign_developer_id() {
  local app="$1"
  codesign --force --deep --options runtime --timestamp --sign "$signing_identity" "$app"
  codesign --verify --deep --strict --verbose=1 "$app"
}

package_app() {
  local app="$1" archive="$2"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
  python3 - "$archive" "$release_notes" <<'PYNOTES'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1], 'a', compression=zipfile.ZIP_DEFLATED) as archive:
    archive.write(sys.argv[2], 'Release Notes.md')
PYNOTES
}

notarise_app() {
  local app="$1" submission="$2" final="$3"
  package_app "$app" "$submission"
  xcrun notarytool submit "$submission" "${notary_auth_args[@]}" --wait
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  package_app "$app" "$final"
}

# A full build must never offer a library for download. A slim build must.
check_music_scope() {
  python3 - "$1/Contents/Resources" "$2" <<'CHECK_MUSIC'
import json, sys
from pathlib import Path
resources, scope = Path(sys.argv[1]), sys.argv[2]
bundle = json.loads((resources / 'Music/bundle.json').read_text())
if bundle['scope'] != scope:
    raise SystemExit(f"FAILED: expected a {scope} soundtrack, found {bundle['scope']}.")
packs = json.loads((resources / 'Music/libraries.json').read_text())['packs']
missing = [p['id'] for p in packs if not all((resources / f['path']).is_file()
           for f in p['files'] if not f['path'].endswith('.json'))]
if scope == 'full' and missing:
    raise SystemExit('FAILED: the full build would download ' + ', '.join(missing))
if scope == 'main' and len(missing) != len(packs):
    raise SystemExit('FAILED: the slim build bundles an optional library.')
print(f"{scope} soundtrack: {bundle['trackCount']} versions, {len(packs) - len(missing)} of {len(packs)} libraries included")
CHECK_MUSIC
}

check_asset_size() {
  local bytes
  bytes="$(stat -f %z "$1")"
  # GitHub rejects release assets of 2 GiB or more.
  (( bytes < 2147483648 )) ||
    fail "${1:t} is $bytes bytes. GitHub release assets must be below 2 GiB."
}

verify_gatekeeper() {
  local archive="$1" verify_dir verify_app verdict
  verify_dir="$(mktemp -d "${TMPDIR:-/tmp}/lemmings-notarise.XXXXXX")"
  ditto -x -k "$archive" "$verify_dir"
  verify_app="$verify_dir/$(basename "$archive" .zip)/Ultimate Lemmings.app"
  [[ -d "$verify_app" ]] || verify_app="$verify_dir/Ultimate Lemmings.app"
  xattr -w com.apple.quarantine "0083;00000000;Safari;" "$verify_app"
  if ! verdict="$(spctl -a -vv --type execute "$verify_app" 2>&1)"; then
    print -u2 -r -- "$verdict"
    rm -rf -- "$verify_dir"
    return 1
  fi
  print -r -- "$verdict"
  rm -rf -- "$verify_dir"
}

standard_dir="$run_dir/standard"
standard_app="$standard_dir/Ultimate Lemmings.app"
standard_zip="$downloads_dir/UltimateLemmings-$version-build$build_number-$stamp-standard.zip"
print "==> Building and notarising Developer ID standard target (full soundtrack)"
build_app "$project_dir" "$standard_dir" 0 full
check_music_scope "$standard_app" full || fail "The update build does not carry the full soundtrack."
print "==> Gate 6: running app integration tests"
LEMMINGS_TEST_APP="$standard_app" zsh "$project_dir/Scripts/run-app-integration-tests.sh" ||
  fail "The app integration tests failed. Do not release this build."
sign_developer_id "$standard_app"
notarise_app "$standard_app" "$run_dir/standard-submission.zip" "$standard_zip"
verify_gatekeeper "$standard_zip"
zsh "$project_dir/Scripts/run-launch-smoke-test.sh" "$standard_app" ||
  fail "The standard target did not launch cleanly."

# Sparkle updates contain only the notarised app. The public release process
# uploads this archive and the generated appcast to the configured release.
mkdir -p "$updates_dir"
update_zip="$updates_dir/UltimateLemmings-$version-build$build_number.zip"
ditto -c -k --sequesterRsrc --keepParent "$standard_app" "$update_zip"
check_asset_size "$update_zip"
# The update alert shows these notes. Sparkle reads HTML beside the archive.
python3 "$project_dir/Tools/ReleaseReadiness/update_notes.py" "$release_notes" \
  "$updates_dir/UltimateLemmings-$version-build$build_number.html"
release_tag="${RELEASE_TAG:-v${version}.0}"
download_url_prefix="${DOWNLOAD_URL_PREFIX:-https://github.com/ErikVeland/Lemmings/releases/download/$release_tag/}"
[[ "$download_url_prefix" == https://* ]] || fail "DOWNLOAD_URL_PREFIX must use HTTPS."
DOWNLOAD_URL_PREFIX="$download_url_prefix" APPCAST_PATH="$project_dir/appcast.xml" \
  UPDATES_DIR="$updates_dir" zsh "$project_dir/Scripts/generate-appcast.sh" "$updates_dir"
zsh "$project_dir/Scripts/check-release-inputs.sh"

slim_dir="$run_dir/slim"
slim_app="$slim_dir/Ultimate Lemmings.app"
# generate_appcast signs every archive in the updates directory. Keep the
# slim download out of it, so the feed only offers the full soundtrack.
slim_zip="${updates_dir:h}/downloads/UltimateLemmings-$version-build$build_number-slim.zip"
mkdir -p "${slim_zip:h}"
print "==> Building and notarising the slim fresh-install download"
build_app "$project_dir" "$slim_dir" 0 main
check_music_scope "$slim_app" main || fail "The slim download bundles optional music."
sign_developer_id "$slim_app"
notarise_app "$slim_app" "$run_dir/slim-submission.zip" "$slim_zip"
check_asset_size "$slim_zip"
verify_gatekeeper "$slim_zip"
zsh "$project_dir/Scripts/run-launch-smoke-test.sh" "$slim_app" ||
  fail "The slim download did not launch cleanly."

monterey_dir="$run_dir/monterey"
monterey_app="$monterey_dir/Ultimate Lemmings.app"
monterey_zip="$downloads_dir/UltimateLemmings-$version-build$build_number-$stamp-monterey.zip"
print "==> Building and notarising macOS 12 Monterey target"
build_app "$monterey_worktree" "$monterey_dir" 0 full
check_music_scope "$monterey_app" full || fail "The Monterey build does not carry the full soundtrack."
sign_developer_id "$monterey_app"
notarise_app "$monterey_app" "$run_dir/monterey-submission.zip" "$monterey_zip"
verify_gatekeeper "$monterey_zip"
zsh "$project_dir/Scripts/run-launch-smoke-test.sh" "$monterey_app" ||
  fail "The Monterey target did not launch cleanly."

game_center_dir="$run_dir/gamecenter"
game_center_app="$game_center_dir/Ultimate Lemmings.app"
game_center_zip="$downloads_dir/UltimateLemmings-$version-build$build_number-$stamp-gamecenter.zip"
print "==> Building and signing Game Center target"
build_app "$project_dir" "$game_center_dir" 1 full
codesign --verify --deep --strict --verbose=1 "$game_center_app"
codesign -d --entitlements :- "$game_center_app" 2>/dev/null |
  grep -q 'com.apple.developer.game-center' ||
  fail "Game Center entitlement is missing from the Game Center target."
zsh "$project_dir/Scripts/run-launch-smoke-test.sh" "$game_center_app" ||
  fail "The Game Center target did not launch cleanly."
package_app "$game_center_app" "$game_center_zip"
check_release_snapshot
zsh "$project_dir/Scripts/check-release-inputs.sh" ||
  fail "The signed update feed changed during packaging. Discard these archives."

print
print "Three target archives created in $downloads_dir:"
print "  $standard_zip"
print "  $monterey_zip"
print "  $game_center_zip"
print "Signed update ZIP (full soundtrack): $update_zip"
print "Fresh-install download (slim): $slim_zip"
print "Signed appcast: $project_dir/appcast.xml"
print "Stamped release notes: $release_notes"
print "Frozen source commit: $current_head"
shasum -a 256 "$update_zip" "$slim_zip" "$project_dir/appcast.xml"
print "No public release was published. Review the packages before publication."
print "The Game Center archive is signed for registered devices and is not notarised."
