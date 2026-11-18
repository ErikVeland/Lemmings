#!/bin/zsh
# Build the separate personal Mac preview without changing the clean store artefacts.
set -euo pipefail
project_dir="${0:A:h:h}"
python3 "$project_dir/Tools/AlternativeAssets/personal_preview.py" "$@"
