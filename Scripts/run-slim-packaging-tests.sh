#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/Music/mixed" "$test_dir/Music/recordings"
touch "$test_dir/Music/mixed/tune.mod" "$test_dir/Music/mixed/tune.M4A" \
  "$test_dir/Music/recordings/tune.wav" "$test_dir/Music/recordings/tune.FLAC"
zsh "$project_dir/Scripts/strip-recorded-music.sh" "$test_dir/Music"
# Stripping rebuilds the generated folder as the main soundtrack set.
[[ ! -e "$test_dir/Music/mixed" && ! -e "$test_dir/Music/recordings" ]]
python3 - "$test_dir/Music" <<'CHECK'
import json, sys
from pathlib import Path
music = Path(sys.argv[1])
bundle = json.loads((music / 'bundle.json').read_text())
assert bundle['scope'] == 'main' and bundle['trackCount'] == 54, bundle
CHECK
echo 'PASS slim packaging rebuilds the main soundtrack set and drops other recordings'
