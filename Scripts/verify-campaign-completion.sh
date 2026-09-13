#!/bin/zsh
set -euo pipefail
mode=verify-known
classic_only=0
for argument in "$@"; do
  case "$argument" in
    --require-all) mode=verify ;;
    --classic-only) classic_only=1 ;;
    *) print -u2 "Unknown argument: $argument"; exit 2 ;;
  esac
done
project_dir="${0:A:h:h}"
library_dir="${CAMPAIGN_TEST_LIBRARY_DIR:-$project_dir/.build/local/$(uname -m)}"
build_dir="$project_dir/.build/campaign-completion"
resources="${CAMPAIGN_TEST_RESOURCES:-$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources}"
ports="$resources/Ports"
mkdir -p "$build_dir"
cd "$project_dir"
python3 Tools/CampaignCompletion/report.py --check
swiftc -O -swift-version 6 -I "$library_dir/modules" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" -o "$build_dir/Verify" Tools/ClassicCompletion/main.swift
games=(ohNoMoreLemmings holidayLemmings1993 holidayLemmings1994 xmasLemmings1991 xmasLemmings1992)
folders=(oh_no_more_lemmings_dos-1991-11-14_2232 holiday_native_1993 holiday_native_1994 xmas_dos_XmasLemmingsV1.9 xmas_dos_XmasLemmingsV1.9a1)
failed=0
for (( index=1; index<=${#games}; index++ )); do
  CLASSIC_COMPLETION_FAMILY=1 \
  CLASSIC_COMPLETION_FIXTURES="$project_dir/Tests/ClassicFamilyCompletionTests/Fixtures/${games[index]}" \
    "$build_dir/Verify" "$mode" "$ports/${folders[index]}" || failed=1
done
if (( ! classic_only )); then
  l3_arguments=()
  if [[ "$mode" == verify ]]; then l3_arguments=(--require-all); fi
  L3_TEST_LIBRARY_DIR="$library_dir" zsh Scripts/verify-l3-completion.sh "${l3_arguments[@]}" || failed=1
fi
exit "$failed"
