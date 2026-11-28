#!/bin/zsh
# Prepare the explicitly licensed CC0 Lix soundtrack without playing audio.
set -euo pipefail

project_dir="${0:A:h:h}"
exec python3 "$project_dir/Tools/AlternativeAssets/prepare_music.py" "$@"
