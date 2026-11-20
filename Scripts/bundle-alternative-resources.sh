#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
if (( $# != 1 )); then
  echo "Usage: bundle-alternative-resources.sh /path/App.app/Contents/Resources" >&2
  exit 2
fi
if [[ ! -f "$project_dir/.build/alternative-assets/lix/manifest.json" ]]; then
  zsh "$project_dir/Scripts/prepare-alternative-assets.sh"
fi
python3 "$project_dir/Tools/AlternativeAssets/bundle_runtime.py" "$1"
