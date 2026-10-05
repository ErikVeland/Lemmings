#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
resources_dir="$project_dir/.build/classic-mac-artwork-audit/resources"
ports_dir="$resources_dir/Ports"
mkdir -p "$ports_dir"
for folder in lemmings_dos_1991-07-30 oh_no_more_lemmings_dos-1991-11-14_2232 \
  xmas_dos_XmasLemmingsV1.9 xmas_dos_XmasLemmingsV1.9a1; do
  target="$ports_dir/$folder"
  if [[ -L "$target" ]]; then rm "$target"; fi
  mkdir -p "$target"
  cp -R "$project_dir/Sources/Ports/$folder/." "$target/"
done
zsh "$project_dir/Scripts/prepare-holiday-data.sh" "$resources_dir"
cd "$project_dir"
python3 Tools/MacArtwork/prepare.py .build/mac-artwork/export
LEMMINGS_TEST_AUDIO=muted FAN_TEST_PORTS_DIR="$ports_dir" \
  zsh Scripts/run-fan-library-tests.sh --audit-artwork
