#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
if (( $# != 0 )); then
  if (( $# == 1 )) && [[ "$1" == --verify ]]; then
    exec zsh "$project_dir/Scripts/check-alternative-assets.sh"
  fi
  echo "Usage: prepare-alternative-assets.sh [--verify]" >&2
  exit 2
fi
zsh "$project_dir/Scripts/prepare-lix-alternative.sh"
zsh "$project_dir/Scripts/prepare-alternative-music.sh"
python3 "$project_dir/Tools/AlternativeAssets/package.py"
