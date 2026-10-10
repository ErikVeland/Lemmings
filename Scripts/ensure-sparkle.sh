#!/bin/zsh
# Locate the pinned Sparkle distribution or fetch it into ignored build output.
set -euo pipefail

project_dir="${0:A:h:h}"
build_root="${LEMMINGS_BUILD_ROOT:-$project_dir/.build/dependencies}"
sparkle_version="2.7.3"
sparkle_url="https://github.com/sparkle-project/Sparkle/releases/download/$sparkle_version/Sparkle-for-Swift-Package-Manager.zip"
sparkle_sha256="2e0bf15ae74c13e7b16b76e34ba56fe3a44683e35473298225f4a2a2c274329a"

if [[ -n "${SPARKLE_FRAMEWORK_PATH:-}" ]]; then
  framework_path="${SPARKLE_FRAMEWORK_PATH:A}"
else
  distribution_root="$build_root/Sparkle-$sparkle_version"
  framework_path="$distribution_root/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
  if [[ ! -d "$framework_path" ]]; then
    archive="$build_root/Sparkle-$sparkle_version.zip"
    mkdir -p "$build_root"
    if [[ ! -f "$archive" ]]; then
      curl -L --fail --silent --show-error "$sparkle_url" -o "$archive"
    fi
    actual_sha256="$(shasum -a 256 "$archive" | awk '{print $1}')"
    [[ "$actual_sha256" == "$sparkle_sha256" ]] || {
      print -u2 "FAILED: Sparkle $sparkle_version checksum mismatch."
      exit 1
    }
    rm -rf "$distribution_root"
    mkdir -p "$distribution_root"
    ditto -x -k "$archive" "$distribution_root"
  fi
fi

[[ -d "$framework_path" ]] || {
  print -u2 "FAILED: Sparkle.framework was not found: $framework_path"
  exit 1
}
print -r -- "$framework_path"
