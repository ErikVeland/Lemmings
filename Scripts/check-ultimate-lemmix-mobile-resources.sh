#!/bin/zsh
# Verify the clean mobile media boundary without compiling or launching an app.
set -euo pipefail
project_dir="${0:A:h:h}"
python3 -m unittest discover -s "$project_dir/Tests/UltimateLemmixMobileBuildTests" -p 'test_*.py'
python3 "$project_dir/Tools/AlternativeAssets/mobile_resources.py"
