#!/bin/zsh
# Build a fast, current-architecture Game Center snapshot for local testing.
# This path does not notarise, run release gates or require a Monterey worktree.
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="${LEMMINGS_BUILD_DIR:-$project_dir/.build/game-center-snapshot}"
build_dir="${build_dir:A}"
app_dir="$build_dir/Ultimate Lemmings.app"
downloads_dir="${DOWNLOADS_DIR:-$HOME/Downloads}"
downloads_dir="${downloads_dir:A}"
stamp="$(date +%Y%m%d-%H%M%S)"
zip_path="$downloads_dir/UltimateLemmings-local-gamecenter-$stamp.zip"

print "==> Building local Game Center snapshot"
print "    Architecture: $(uname -m)"
print "    Output:       $app_dir"

mkdir -p "$downloads_dir"
LEMMINGS_ARCHITECTURES="$(uname -m)" \
  LEMMINGS_SWIFT_OPTIMIZATION="${LEMMINGS_SWIFT_OPTIMIZATION:--Onone}" \
  ENABLE_APPLE_CAPABILITIES=1 \
  LEMMINGS_BUILD_DIR="$build_dir" \
  zsh "$project_dir/Scripts/build-local-app.sh"

codesign --verify --deep --strict --verbose=1 "$app_dir"
codesign -d --entitlements :- "$app_dir" 2>/dev/null |
  rg -q 'com.apple.developer.game-center' ||
  { print -u2 "FAILED: Game Center entitlement is missing from $app_dir"; exit 1; }

ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$zip_path"
print
print "Snapshot app: $app_dir"
print "Snapshot ZIP: $zip_path"
print "This build is Apple Development signed for Macs in the provisioning profile."
print "It is not notarised."
