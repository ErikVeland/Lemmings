#!/bin/zsh
# Builds the app and wraps it in a zip file for private beta testers.
#
# Gatekeeper blocks a downloaded app that is not signed with a Developer ID
# and notarized by Apple. The ad-hoc signature the local build applies is
# enough to run on this machine and not enough to run on anybody else's.
# Set the two variables below to produce a zip that opens without warnings:
#
#   BETA_SIGNING_IDENTITY  "Developer ID Application: Name (TEAMID)"
#   BETA_NOTARY_PROFILE    a profile stored by `xcrun notarytool store-credentials`
#
# Set BETA_SLIM=1 to leave out the studio recordings. Module music remains.
#
# Set BETA_GAME_CENTER=1 to build the worldwide-rankings variant instead. That
# build is signed with an Apple Development identity and the profile named by
# APPLE_PROVISIONING_PROFILE, so it runs only on the Macs that profile lists.
# The notary service accepts Developer ID signatures only, so this build cannot
# be notarized and Gatekeeper stops it on first run. It is a separate archive,
# named with a -gamecenter suffix, and it does not replace the Developer ID
# archive.
#
# Without them the script still produces a working zip, and prints the steps a
# tester must take by hand to open it.
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="${LEMMINGS_BUILD_DIR:-$project_dir/.build/local}"
build_dir="${build_dir:A}"
app_dir="$build_dir/Ultimate Lemmings.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Resources/Info.plist")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$project_dir/Resources/Info.plist")"
# Game Center needs an Apple Development signature and a provisioning profile
# that lists each tester's Mac. That build cannot be notarized, so it ships as a
# separate archive under its own name. See BETA_GAME_CENTER below.
# Version 1.0 and later require Classic closure, even through the beta packager.
release_scope="$(python3 "$project_dir/Tools/ReleaseReadiness/package_scope.py" "$project_dir")"
game_center="${BETA_GAME_CENTER:-0}"
variant=""
[[ "$game_center" == 1 ]] && variant="-gamecenter"
zip_path="$build_dir/UltimateLemmings-$version-beta$build_number$variant.zip"
notes_path="$project_dir/Documentation/ReleaseNotes-beta$build_number.md"
[[ -f "$notes_path" ]] || { echo "Missing release notes: $notes_path" >&2; exit 1; }
# A distributable beta must not silently hide stale proofs or hint decks.
python3 "$project_dir/Tools/TrolleyVerification/catalogue.py" check
python3 - "$project_dir" <<'CHECK_HINTS'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1]) / 'Resources'
proofs = json.loads((root / 'Trolley/verified-maxima.json').read_text())
hints = json.loads((root / 'Hints/classic.json').read_text())
if hints['engineFingerprint'] != proofs['engineSourceFingerprint']:
    raise SystemExit('Hint data is stale. Regenerate it with Scripts/generate-level-hints.sh before packaging.')
CHECK_HINTS

write_release_archive() {
  ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$zip_path"
  python3 - "$zip_path" "$notes_path" <<'PYNOTES'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], 'a', compression=zipfile.ZIP_DEFLATED) as archive:
    archive.write(sys.argv[2], 'Release Notes.md')
PYNOTES
  cp "$notes_path" "$build_dir/ReleaseNotes-beta$build_number.md"
}

# Use the Developer ID in the keychain unless the caller names another one.
if [[ "$game_center" != 1 && -z "${BETA_SIGNING_IDENTITY:-}" ]]; then
  found="$(security find-identity -v -p codesigning 2>/dev/null |
    grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')"
  if [[ -n "$found" ]]; then
    BETA_SIGNING_IDENTITY="$found"
    echo "==> Found signing identity: $BETA_SIGNING_IDENTITY"
  fi
fi

echo "==> Building"
if [[ "$game_center" == 1 ]]; then
  # build-local-app.sh signs this one itself, through sign-capabilities.py: an
  # Apple Development identity, the matching profile, and the Game Center and
  # spatial-audio entitlements. Re-signing it here would strip all of that.
  ENABLE_APPLE_CAPABILITIES=1 LEMMINGS_BUILD_DIR="$build_dir" \
    zsh "$project_dir/Scripts/build-local-app.sh" >/dev/null
else
  # Developer ID distribution does not support App Store Game Center services.
  # Build without the development provisioning profile before applying this signature.
  ENABLE_APPLE_CAPABILITIES=0 LEMMINGS_BUILD_DIR="$build_dir" zsh "$project_dir/Scripts/build-local-app.sh" >/dev/null
fi

if [[ "${BETA_SLIM:-0}" == 1 ]]; then
  echo "==> Slim build. Removing the studio soundtrack recordings."
  zsh "$project_dir/Scripts/strip-recorded-music.sh" "$app_dir/Contents/Resources/Music"
fi

if [[ "$game_center" == 1 ]]; then
  if [[ "${BETA_SLIM:-0}" == 1 ]]; then
    # Removing files invalidates the capability signature, so apply it again.
    echo "==> Re-applying the capability signature after the slim strip"
    profile_args=()
    [[ -n "${APPLE_PROVISIONING_PROFILE:-}" ]] && profile_args=(--profile "$APPLE_PROVISIONING_PROFILE")
    python3 "$project_dir/Scripts/sign-capabilities.py" "$app_dir" "${profile_args[@]}"
  fi
  echo "==> Checking the Game Center entitlement"
  if ! codesign -d --entitlements :- "$app_dir" 2>/dev/null |
      grep -q 'com.apple.developer.game-center'; then
    echo "FAILED: this build has no Game Center entitlement. Do not send it." >&2
    exit 1
  fi
  enabled="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["enabled"])' \
    "$app_dir/Contents/Resources/GameCenter/leaderboards.json")"
  if [[ "$enabled" != True ]]; then
    echo "FAILED: the bundled leaderboard catalogue is disabled. Do not send it." >&2
    exit 1
  fi
  echo "    entitlement present, catalogue enabled"
elif [[ -n "${BETA_SIGNING_IDENTITY:-}" ]]; then
  echo "==> Signing with Developer ID"
  # The runtime hardening and timestamp are both required before Apple will
  # notarize the result.
  codesign --force --deep --options runtime --timestamp \
    --sign "$BETA_SIGNING_IDENTITY" "$app_dir"
else
  # Removing files invalidates the signature the build applied, so seal it again.
  echo "==> No Developer ID found. Re-sealing with an ad-hoc signature."
  codesign --force --deep --sign - "$app_dir"
fi

echo "==> Checking the signature"
codesign --verify --deep --strict --verbose=1 "$app_dir"

if [[ "$release_scope" == classic-1.0 ]]; then
  echo "==> Requiring fresh Classic 1.0 closure for this candidate"
  python3 "$project_dir/Tools/ReleaseReadiness/audit.py" --scope classic-1.0 \
    --require-closure --app --app-bundle "$app_dir" \
    --out "$build_dir/classic-closure-$(date +%Y%m%d-%H%M%S)"
fi

echo "==> Compressing"
# Keep earlier builds out of the handoff folder without deleting them.
if [[ "$game_center" == 1 ]]; then
  earlier_zips=("$build_dir"/UltimateLemmings*-gamecenter.zip(N))
else
  earlier_zips=("$build_dir"/LemmingsLocal*.zip(N) "$build_dir"/UltimateLemmings*.zip(N))
  earlier_zips=(${earlier_zips:#*-gamecenter.zip})
fi
if (( ${#earlier_zips} )); then
  archive_dir="$build_dir/archive/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$archive_dir"
  mv "${earlier_zips[@]}" "$archive_dir/"
fi
write_release_archive

if [[ "$game_center" == 1 && -n "${BETA_NOTARY_PROFILE:-}" ]]; then
  echo "==> Skipping notarization. The notary service accepts Developer ID signatures only."
fi
if [[ "$game_center" != 1 && -n "${BETA_NOTARY_PROFILE:-}" ]]; then
  echo "==> Notarizing. This uploads the zip to Apple and can take several minutes."
  xcrun notarytool submit "$zip_path" --keychain-profile "$BETA_NOTARY_PROFILE" --wait
  # The ticket is stapled to the app, so the zip has to be rebuilt around it.
  xcrun stapler staple "$app_dir"
  rm -f "$zip_path"
  write_release_archive
  echo "==> Notarized and stapled."
fi

# Check the zip a tester would actually download, rather than the app on this
# machine. Unpack it somewhere fresh, mark it as downloaded, and ask Gatekeeper.
echo "==> Verifying the finished zip the way a tester receives it"
verify_dir="$(mktemp -d)"
ditto -x -k "$zip_path" "$verify_dir"
verify_app="$verify_dir/$(basename "$app_dir")"
xattr -w com.apple.quarantine "0083;00000000;Safari;" "$verify_app"
if verdict="$(spctl -a -vv "$verify_app" 2>&1)"; then
  echo "    $(echo "$verdict" | tr '\n' ' ')"
else
  echo "    $(echo "$verdict" | tr '\n' ' ')"
  if [[ "$game_center" != 1 && -n "${BETA_NOTARY_PROFILE:-}" ]]; then
    rm -rf "$verify_dir"
    echo "FAILED: this zip is not accepted by Gatekeeper. Do not send it." >&2
    exit 1
  fi
  if [[ "$game_center" == 1 ]]; then
    echo "    (expected: a Game Center build cannot be notarized)"
  else
    echo "    (expected: this build was not notarized)"
  fi
fi
rm -rf "$verify_dir"

echo
echo "Zip:  $zip_path"
echo "Size: $(du -h "$zip_path" | cut -f1)"
echo

if [[ "$game_center" == 1 ]]; then
  cat <<'NOTE'
This is the Game Center build. It is signed with an Apple Development identity
and carries a provisioning profile, so it runs only on the Macs listed in that
profile. It cannot be notarized.

Before a tester can open it:

1. Register the tester's Mac UDID in the Apple Developer portal.
2. Regenerate and download the "Lemmings macOS Development" profile.
3. Rebuild with APPLE_PROVISIONING_PROFILE set to the new file.

Each tester must clear the quarantine flag by hand:

    xattr -dr com.apple.quarantine "/Applications/Ultimate Lemmings.app"

Worldwide rankings use the Game Center sandbox. Those scores stay separate
from production scores.
NOTE
elif [[ -z "${BETA_NOTARY_PROFILE:-}" ]]; then
  cat <<'NOTE'
This build is signed but not notarized, so macOS still stops it on first run.
To notarize, store your credentials once:

    xcrun notarytool store-credentials lemmings-beta \
      --apple-id YOUR_APPLE_ID --team-id 54WU29TRTY

Then run this script again with BETA_NOTARY_PROFILE=lemmings-beta.

Until then, a tester must clear the quarantine flag by hand:

    xattr -dr com.apple.quarantine "/Applications/Ultimate Lemmings.app"
NOTE
fi
