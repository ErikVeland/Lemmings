#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/Music/mixed" "$test_dir/Music/recordings"
touch "$test_dir/Music/mixed/tune.mod" "$test_dir/Music/mixed/tune.M4A" \
  "$test_dir/Music/recordings/tune.wav" "$test_dir/Music/recordings/tune.FLAC"
zsh "$project_dir/Scripts/strip-recorded-music.sh" "$test_dir/Music"
[[ -f "$test_dir/Music/mixed/tune.mod" ]]
[[ ! -f "$test_dir/Music/mixed/tune.M4A" && ! -d "$test_dir/Music/recordings" ]]
[[ "$(find "$test_dir/Music" -type f | wc -l | tr -d ' ')" == 1 ]]
echo 'PASS slim packaging removes encoded recordings and preserves modules in mixed folders'
