#!/bin/zsh
# Stage the supplied original cursors for preservation exports only.
set -euo pipefail
project_dir="${0:A:h:h}"
python3 "$project_dir/Tools/OwnedResources/cursors.py" --fixtures \
  --output "$project_dir/.build/owned-resource-export-assets"
