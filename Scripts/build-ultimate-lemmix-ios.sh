#!/bin/zsh
# Prepare the separate clean-content iPhone and iPad review build.
set -euo pipefail
project_dir="${0:A:h:h}"
python3 "$project_dir/Tools/AlternativeAssets/build_mobile.py" ios "$@"
