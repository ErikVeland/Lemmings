#!/bin/zsh
# Check the local tools and ignored game data required by build-local-app.sh.
set -euo pipefail

project_dir="${0:A:h:h}"
architectures=(arm64 x86_64)
if [[ -n "${LEMMINGS_ARCHITECTURES:-}" ]]; then
  architectures=("${(@s: :)LEMMINGS_ARCHITECTURES}")
fi

fail() {
  print -u2 "FAILED: $*"
  exit 1
}

for command_name in swiftc python3 rsync sips iconutil codesign ditto; do
  command -v "$command_name" >/dev/null 2>&1 ||
    fail "Required command is missing: $command_name"
done
if (( ${#architectures} > 1 )); then
  command -v lipo >/dev/null 2>&1 || fail "Required command is missing: lipo"
fi
for command_name in unar magick; do
  command -v "$command_name" >/dev/null 2>&1 ||
    fail "Required asset-preparation command is missing: $command_name"
done
for required_path in \
  "$project_dir/Content/LevelPacks/packs.json" \
  "$project_dir/Sources/Ports/Lemm2" \
  "$project_dir/Sources/Ports/LEM3CD" \
  "$project_dir/Sources/Music"; do
  [[ -e "$required_path" ]] || fail "Required local game data is missing: $required_path"
done
