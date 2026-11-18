#!/bin/zsh
# Compile both Mac editions through the same source and cache contract.
set -euo pipefail
project_dir="${0:A:h:h}"
exec python3 "$project_dir/Tools/Publication/mac_sources.py" "$@"
