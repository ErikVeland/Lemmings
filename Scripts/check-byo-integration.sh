#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
python3 "$project_dir/Tools/AlternativeAssets/byo_bundle.py" --verify
python3 -m unittest discover -s "$project_dir/Tests/BYOIntegrationBundleTests" -p 'test_*.py'
