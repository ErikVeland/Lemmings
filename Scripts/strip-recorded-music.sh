#!/bin/zsh
# Remove recordings while retaining module music, including mixed folders.
set -euo pipefail
music_dir="${1:?Music directory}"
[[ -d "$music_dir" ]] || { echo "Missing Music directory: $music_dir" >&2; exit 1; }
find "$music_dir" -type f \( -iname '*.wav' -o -iname '*.aif' -o -iname '*.aiff' \
  -o -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.caf' -o -iname '*.flac' \) -delete
find "$music_dir" -mindepth 1 -type d -empty -delete
