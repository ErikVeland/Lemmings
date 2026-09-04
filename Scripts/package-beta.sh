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
# Set BETA_SLIM=1 to leave out the studio soundtrack recordings. They are
# 406 MB of the bundle, about four fifths of the download, and the game's own
# ProTracker modules already play the same music. A slim build is the smaller
# and legally safer thing to hand round; a full build sounds better.
#
# Without them the script still produces a working zip, and prints the steps a
# tester must take by hand to open it.
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/local"
app_dir="$build_dir/Lemmings Local.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Resources/Info.plist")"
zip_path="$build_dir/LemmingsLocal-$version-beta.zip"

# Use the Developer ID in the keychain unless the caller names another one.
if [[ -z "${BETA_SIGNING_IDENTITY:-}" ]]; then
  found="$(security find-identity -v -p codesigning 2>/dev/null |
    grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')"
  if [[ -n "$found" ]]; then
    BETA_SIGNING_IDENTITY="$found"
    echo "==> Found signing identity: $BETA_SIGNING_IDENTITY"
  fi
fi

echo "==> Building"
zsh "$project_dir/Scripts/build-local-app.sh" >/dev/null

if [[ "${BETA_SLIM:-0}" == 1 ]]; then
  echo "==> Slim build. Removing the studio soundtrack recordings."
  # Only folders of plain audio files are removed. The ProTracker modules the
  # game itself shipped with stay, so every level still has its music.
  find "$app_dir/Contents/Resources/Music" -type d -depth 1 -print0 |
    while IFS= read -r -d '' folder; do
      if [[ -n "$(find "$folder" -maxdepth 1 -iname '*.wav' -print -quit)" ]]; then
        echo "    dropping ${folder:t}"
        rm -rf "$folder"
      fi
    done
fi

if [[ -n "${BETA_SIGNING_IDENTITY:-}" ]]; then
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

echo "==> Compressing"
rm -f "$zip_path"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$zip_path"

if [[ -n "${BETA_NOTARY_PROFILE:-}" ]]; then
  echo "==> Notarizing. This uploads the zip to Apple and can take several minutes."
  xcrun notarytool submit "$zip_path" --keychain-profile "$BETA_NOTARY_PROFILE" --wait
  # The ticket is stapled to the app, so the zip has to be rebuilt around it.
  xcrun stapler staple "$app_dir"
  rm -f "$zip_path"
  ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$zip_path"
  echo "==> Notarized and stapled."
fi

echo
echo "Zip:  $zip_path"
echo "Size: $(du -h "$zip_path" | cut -f1)"
echo

if [[ -z "${BETA_NOTARY_PROFILE:-}" ]]; then
  cat <<'NOTE'
This build is signed but not notarized, so macOS still stops it on first run.
To notarize, store your credentials once:

    xcrun notarytool store-credentials lemmings-beta \
      --apple-id YOUR_APPLE_ID --team-id 54WU29TRTY

Then run this script again with BETA_NOTARY_PROFILE=lemmings-beta.

Until then, a tester must clear the quarantine flag by hand:

    xattr -dr com.apple.quarantine "/Applications/Lemmings Local.app"
NOTE
fi
