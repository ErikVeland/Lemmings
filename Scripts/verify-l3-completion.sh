#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
library_dir="${L3_TEST_LIBRARY_DIR:-$project_dir/.build/local/$(uname -m)}"
build_dir="$project_dir/.build/l3-completion"
mkdir -p "$build_dir"
cd "$project_dir"
swiftc -O -swift-version 6 -I "$library_dir/modules" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" -o "$build_dir/Verify" \
  Tools/Lemmings3Completion/Replay.swift Tools/Lemmings3Completion/main.swift
python3 Tools/CampaignCompletion/report.py --check
"$build_dir/Verify" verify "$@"
python3 Tests/Lemmings3CompletionTests/test_gate.py "$build_dir/Verify"
