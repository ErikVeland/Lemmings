#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
if (( $# != 1 )) || [[ "$1" != 2 && "$1" != 3 ]]; then
  echo "Usage: zsh Scripts/run-sequel-reference.sh 2|3" >&2
  exit 2
fi
default_emulator=dosbox-staging
if [[ -x '/Applications/DOSBox Staging.app/Contents/MacOS/dosbox' ]]; then
  default_emulator='/Applications/DOSBox Staging.app/Contents/MacOS/dosbox'
fi
emulator="${LEMMINGS_REFERENCE_DOSBOX:-$default_emulator}"
if ! command -v "$emulator" >/dev/null; then
  echo "Install DOSBox Staging, or set LEMMINGS_REFERENCE_DOSBOX to its executable." >&2
  exit 1
fi
if [[ "$1" == 2 ]]; then
  source_dir="$project_dir/Sources/Ports/Lemm2"
  executable=L2.EXE
else
  source_dir="$project_dir/Sources/Ports/LEM3CD"
  executable=L3CD.EXE
fi
if [[ ! -f "$source_dir/$executable" ]]; then
  echo "Missing local game data: $source_dir/$executable" >&2
  exit 1
fi
reference_root="$project_dir/.build/sequel-reference"
mkdir -p "$reference_root"
# Each run gets a fresh copy. Earlier runs and saves remain available.
run_dir=$(mktemp -d "$reference_root/l$1.XXXXXX")
cp -R "$source_dir" "$run_dir/game"
mkdir -p "$run_dir/captures"
echo "Reference run: $run_dir"
echo "This development tool does not award native campaign achievements."
cd "$run_dir"
exec "$emulator" --noprimaryconf --nolocalconf \
  --conf "$project_dir/Tools/SequelReference/dosbox-staging.conf" \
  --set "capture_dir=$run_dir/captures" \
  -c 'mount c game' -c 'c:' -c "$executable"
