#!/bin/zsh
set -euo pipefail
experiment_dir="${0:A:h}"
experiment_python="${TAMIL_PIXEL_PYTHON:-python3}"
if ! "$experiment_python" -c 'from PIL import Image' 2>/dev/null; then
  print -u2 'Use TAMIL_PIXEL_PYTHON to select a Python interpreter with Pillow.'
  exit 1
fi
swift -module-cache-path "$experiment_dir/.swift-module-cache" "$experiment_dir/rasterise.swift"
"$experiment_python" "$experiment_dir/verify.py"
"$experiment_python" "$experiment_dir/build.py"
