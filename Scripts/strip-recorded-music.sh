#!/bin/zsh
# Rebuild a generated Music folder with the main soundtrack set.
set -euo pipefail
project_dir="${0:A:h:h}"
music_dir="${1:?Music directory}"
[[ -d "$music_dir" ]] || { echo "Missing Music directory: $music_dir" >&2; exit 1; }
game=all
if [[ -f "$music_dir/bundle.json" ]]; then
  game="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["game"])' "$music_dir/bundle.json")"
fi
python3 "$project_dir/Tools/MusicCatalogue/library.py" bundle --output "$music_dir" --scope main --game "$game"
