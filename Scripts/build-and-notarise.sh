#!/bin/zsh
# Build, gate, sign, notarise and verify the three local macOS release targets.
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
#   RELEASE_NOTES_PATH path for the current release notes
#   MONTEREY_WORKTREE macOS 12 worktree, default .claude/worktrees/macos12
#   DOWNLOADS_DIR     destination for the three final ZIP files
#   BUILD_ROOT        internal build output directory
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

release_base="${RELEASE_BASE:-}"
if [[ -z "$release_base" ]]; then
  release_base="$(git -C "$project_dir" log --all --diff-filter=A --format='%H' \
    -- 'Documentation/ReleaseNotes-beta*.md' | sed -n '1p')"
fi
[[ -n "$release_base" ]] || fail "Set RELEASE_BASE to the previous release commit or tag."
git -C "$project_dir" rev-parse --verify "$release_base^{commit}" >/dev/null 2>&1 ||
  fail "RELEASE_BASE does not resolve to a commit: $release_base"

# Gate 1: the candidate must contain source changes after the previous release.
source_changes="$(git -C "$project_dir" diff --name-only "$release_base" -- Sources)"
[[ -n "$source_changes" ]] || fail "No new source code exists after $release_base."

release_notes="${RELEASE_NOTES_PATH:-$project_dir/Documentation/ReleaseNotes-1.1-build$build_number.md}"
release_notes="${release_notes:A}"

generate_release_notes() {
  local source_commits source_files
  source_commits="$(git -C "$project_dir" log --format='- %h %s' "$release_base"..HEAD -- Sources)"
  source_files="$(git -C "$project_dir" diff --name-status "$release_base" -- Sources)"
  {
    print "# Ultimate Lemmings 1.1 build $build_number"
    print
    print "Build: $build_number"
    print "Release commit: $current_head"
    print "Release base: $release_base"
    print
    print "## Changes since the previous release"
    if [[ -n "$source_commits" ]]; then
      print -r -- "$source_commits"
    else
      print -r -- "- Source changes are present in the working tree."
    fi
    print
    print "## Source files"
    print -r -- "$source_files"
    print
    print "## Package targets"
    print -r -- "- Developer ID standard: notarised."
    print -r -- "- macOS 12 Monterey: notarised."
    print -r -- "- Game Center: development-signed for registered devices; not notarised."
  } > "$release_notes"
  print "Created release notes: $release_notes"
}

# Gate 2-3: release notes must describe this candidate. Create them when the
# current build has no notes; reject an older notes file rather than silently
# packaging undocumented code.
if [[ ! -f "$release_notes" ]]; then
  generate_release_notes
fi
grep -q "^Build: $build_number$" "$release_notes" ||
  fail "Release notes do not identify build $build_number: $release_notes"
grep -q "^Release commit: $current_head$" "$release_notes" ||
  fail "Release notes are not current for $current_short. Update or remove: $release_notes"

[[ -x "$project_dir/Scripts/build-local-app.sh" ]] || fail "Missing build-local-app.sh."
[[ -x "$monterey_worktree/Scripts/build-local-app.sh" ]] ||
  fail "Missing Monterey worktree at $monterey_worktree. Set MONTEREY_WORKTREE."
monterey_head="$(git -C "$monterey_worktree" rev-parse HEAD 2>/dev/null)" ||
  fail "Monterey path is not a Git worktree: $monterey_worktree"
git -C "$monterey_worktree" merge-base --is-ancestor "$current_head" "$monterey_head" ||
  fail "The Monterey worktree does not contain current commit $current_short. Merge the release changes first."

print "Project:       $project_dir"
print "Version:       $version ($build_number)"
print "Release base:  $release_base"
print "Identity:      $signing_identity"
print "Notary auth:   $notary_auth_description"
print "Monterey:      $monterey_worktree"
print "Downloads:     $downloads_dir"
print
print "Gate 1: source changes present"
print -r -- "$source_changes"
print "Gate 2-3: release notes current"
print "             $release_notes"
print "Gate 4: three target archives configured"

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

build_app() {
  local source_dir="$1" output_dir="$2" capabilities="$3"
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
print "==> Building and notarising Developer ID standard target"
build_app "$project_dir" "$standard_dir" 0
sign_developer_id "$standard_app"
notarise_app "$standard_app" "$run_dir/standard-submission.zip" "$standard_zip"
verify_gatekeeper "$standard_zip"

monterey_dir="$run_dir/monterey"
monterey_app="$monterey_dir/Ultimate Lemmings.app"
monterey_zip="$downloads_dir/UltimateLemmings-$version-build$build_number-$stamp-monterey.zip"
print "==> Building and notarising macOS 12 Monterey target"
build_app "$monterey_worktree" "$monterey_dir" 0
sign_developer_id "$monterey_app"
notarise_app "$monterey_app" "$run_dir/monterey-submission.zip" "$monterey_zip"
verify_gatekeeper "$monterey_zip"

game_center_dir="$run_dir/gamecenter"
game_center_app="$game_center_dir/Ultimate Lemmings.app"
game_center_zip="$downloads_dir/UltimateLemmings-$version-build$build_number-$stamp-gamecenter.zip"
print "==> Building and signing Game Center target"
build_app "$project_dir" "$game_center_dir" 1
codesign --verify --deep --strict --verbose=1 "$game_center_app"
codesign -d --entitlements :- "$game_center_app" 2>/dev/null |
  grep -q 'com.apple.developer.game-center' ||
  fail "Game Center entitlement is missing from the Game Center target."
package_app "$game_center_app" "$game_center_zip"

print
print "Three target archives created in $downloads_dir:"
print "  $standard_zip"
print "  $monterey_zip"
print "  $game_center_zip"
print "The Game Center archive is signed for registered devices and is not notarised."
