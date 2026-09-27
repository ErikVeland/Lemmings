#!/bin/zsh
set -euo pipefail
quest_arguments=()
if [[ "${1:-}" == --include-conversions && $# == 1 ]]; then
  quest_arguments=(--include-conversions)
elif (( $# )); then
  print -u2 "Usage: $0 [--include-conversions]"
  exit 2
fi
project_dir="${0:A:h:h}"
cd "$project_dir"
build_dir="$project_dir/.build/official-classic"
library_dir="${CAMPAIGN_TEST_LIBRARY_DIR:-$build_dir}"
resources="${CAMPAIGN_TEST_RESOURCES:-$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources}"
ports="$resources/Ports"
report="${OFFICIAL_QUEST_REPORT:-$build_dir/quest.json}"
mkdir -p "$build_dir/modules"
if [[ -z "${CAMPAIGN_TEST_LIBRARY_DIR:-}" ]]; then
  swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library -emit-module -emit-library \
    -module-name NxlvKit -emit-module-path "$library_dir/modules/NxlvKit.swiftmodule" \
    -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
    -o "$library_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
fi
python3 Tools/ClassicCompletion/report.py --check
python3 Tools/CampaignCompletion/report.py --check
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$library_dir/modules" -L "$library_dir" -lNxlvKit -Xlinker -rpath -Xlinker "$library_dir" \
  Tools/ClassicCompletion/main.swift -o "$build_dir/Verify"
"$build_dir/Verify" verify "$ports/lemmings_dos_1991-07-30"
games=(ohNoMoreLemmings holidayLemmings1993 holidayLemmings1994 xmasLemmings1991 xmasLemmings1992)
folders=(oh_no_more_lemmings_dos-1991-11-14_2232 holiday_native_1993 holiday_native_1994 xmas_dos_XmasLemmingsV1.9 xmas_dos_XmasLemmingsV1.9a1)
for (( index=1; index<=${#games}; index++ )); do
  CLASSIC_COMPLETION_FAMILY=1 \
  CLASSIC_COMPLETION_FIXTURES="$project_dir/Tests/ClassicFamilyCompletionTests/Fixtures/${games[index]}" \
    "$build_dir/Verify" verify "$ports/${folders[index]}"
done
if (( ${#quest_arguments} )); then
  CLASSIC_COMPLETION_FIXTURES="$project_dir/Tests/ClassicFamilyCompletionTests/Fixtures/ohYesMoreLemmings" \
    "$build_dir/Verify" verify "conversion:$ports"
  python3 Tests/ClassicFamilyCompletionTests/test_conversions.py "$build_dir/Verify" "$ports"
fi
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$library_dir/modules" -L "$library_dir" -lNxlvKit -Xlinker -rpath -Xlinker "$library_dir" \
  Sources/LemmingsLocal/GameSession.swift Sources/LemmingsLocal/RunRecovery.swift \
  Sources/LemmingsLocal/FailureMood.swift Tools/OfficialClassicQuest/main.swift -o "$build_dir/Quest"
"$build_dir/Quest" "$ports" "$report" "${quest_arguments[@]}"
python3 Tests/ClassicFamilyCompletionTests/test_official_quest.py "$build_dir/Quest" "$ports" "${quest_arguments[@]}"
