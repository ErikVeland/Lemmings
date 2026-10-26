#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
python3 "$project_dir/Tools/ReleaseReadiness/version_history.py"
