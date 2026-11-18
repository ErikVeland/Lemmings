#!/bin/zsh
# Prepare the unchanged Lix interface font and its separate licence notice.
set -euo pipefail
project_dir="${0:A:h:h}"
python3 "$project_dir/Tools/AlternativeAssets/prepare_lix_font.py" "$@"
