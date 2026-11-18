#!/bin/zsh
# Prepare reviewed community data for the personal Mac test only.
set -euo pipefail
project_dir="${0:A:h:h}"
python3 "$project_dir/Tools/AlternativeAssets/prepare_community_levels.py" "$@"
