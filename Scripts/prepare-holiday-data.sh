#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
resources_dir="$1"
installer="$project_dir/Sources/Ports/mac_extracted/Holiday_Lem93_94/Holiday Lemmings 1994 Installer"
extract_dir="$project_dir/.build/holiday-assets"
# The supplied installer is a StuffIt archive. Extract at build time only.
# At runtime the app reads ordinary resource files with its native parser.
if ! command -v unar >/dev/null; then
  echo "Install unar to extract the supplied Holiday Lemmings installer." >&2
  exit 1
fi
mkdir -p "$extract_dir"
unar -q -f -o "$extract_dir" "$installer"
levels="$extract_dir/Holiday Lemmings 1994 Installer/Levels/..namedfork/rsrc"
if [[ ! -s "$levels" ]]; then
  echo "Holiday installer did not produce its Levels resource fork." >&2
  exit 1
fi
for year in 1993 1994; do
  target_dir="$resources_dir/Ports/holiday_native_$year"
  mkdir -p "$target_dir"
  cp "$levels" "$target_dir/HOLIDAY$year.RSRC"
  # The classic snow style has the same terrain and object IDs as these levels.
  for name in MAIN.DAT GROUND2O.DAT VGAGR2.DAT; do
    cp "$project_dir/Sources/Ports/xmas_dos_XmasLemmingsV1.9a1/$name" "$target_dir/$name"
  done
done
