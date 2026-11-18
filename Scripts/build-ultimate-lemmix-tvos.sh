#!/bin/zsh
# Prepare the separate clean-content Apple TV review build.
set -euo pipefail
project_dir="${0:A:h:h}"
python3 "$project_dir/Tools/Publication/publication.py" guard ultimate-lemmix
python3 "$project_dir/Tools/AlternativeAssets/build_mobile.py" tvos "$@"
