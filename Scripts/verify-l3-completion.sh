#!/bin/zsh
set -euo pipefail
if ! { (( $# == 0 )) ||
       { (( $# == 1 )) && { [[ "$1" == "--require-all" || "$1" == "discover" ]] || [[ "$1" =~ '^[0-9]+$' ]]; }; } ||
       { (( $# == 2 )) && [[ "$1" == "discover" && "$2" =~ '^[0-9]+$' ]]; }; }; then
  print -u2 'Usage: verify-l3-completion.sh [--require-all | discover [LEVEL] | LEVEL]'
  exit 2
fi
project_dir="${0:A:h:h}"
library_dir="${L3_TEST_LIBRARY_DIR:-$project_dir/.build/local/$(uname -m)}"
build_dir="$project_dir/.build/l3-completion"
mkdir -p "$build_dir"
cd "$project_dir"
swiftc -O -swift-version 6 -I "$library_dir/modules" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" -o "$build_dir/Verify" \
  Tools/Lemmings3Completion/Replay.swift Tools/Lemmings3Completion/main.swift
python3 Tools/CampaignCompletion/report.py --check
failed=0
"$build_dir/Verify" verify "$@" || failed=1
python3 Tests/Lemmings3CompletionTests/test_gate.py "$build_dir/Verify" || failed=1
if (( $# == 0 )) || { (( $# == 1 )) && [[ "$1" == "--require-all" ]]; }; then
  zsh Scripts/verify-l3-campaign.sh "$@" || failed=1
fi
exit "$failed"
