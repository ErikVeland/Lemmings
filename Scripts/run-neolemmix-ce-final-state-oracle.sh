#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"

if (( $# < 6 || $# > 7 )); then
  print -u2 "Usage: $0 <wine> <bottle> <NeoLemmixCE.exe> <plan.tsv> <levels-root> <output.json> [snapshot-directory]"
  exit 2
fi

wine=$1
bottle=$2
ce_executable=$3
plan=$4
levels_root=$5
output_manifest=$6
snapshot_root=${7:-$(mktemp -d "${TMPDIR:-/tmp}/neolemmix-ce-final-state.XXXXXX")}
expected_ce_sha256=58d2fccd31e20d5513ee8d2d5eafb6d368f847d8d2cb4a152efeedcb6d4eaf36

for required in "$wine" "$ce_executable" "$plan"; do
  if [[ ! -e "$required" ]]; then
    print -u2 "Missing required input: $required"
    exit 2
  fi
done
if [[ ! -d "$levels_root" ]]; then
  print -u2 "Missing levels root: $levels_root"
  exit 2
fi
if ! command -v i686-w64-mingw32-gcc >/dev/null; then
  print -u2 "i686-w64-mingw32-gcc is required to build the reviewed CE memory controller."
  exit 2
fi

actual_ce_sha256=$(shasum -a 256 "$ce_executable" | awk '{print $1}')
if [[ "$actual_ce_sha256" != "$expected_ce_sha256" ]]; then
  print -u2 "Unsupported CE executable SHA-256: $actual_ce_sha256"
  exit 2
fi

build_dir=$(mktemp -d "${TMPDIR:-/tmp}/neolemmix-ce-final-state-build.XXXXXX")
controller="$build_dir/final-snapshot.exe"
i686-w64-mingw32-gcc -O2 -municode \
  -o "$controller" \
  "$project_dir/Tools/NeoLemmixCEFinalState/final-snapshot.c" \
  -luser32

mkdir -p "$snapshot_root" "${output_manifest:h}"
total=$(wc -l < "$plan" | tr -d ' ')
index=0
while IFS=$'\t' read -r replay_hash target_tick replay_path; do
  (( index += 1 ))
  if [[ ! "$replay_hash" =~ '^[0-9a-f]{64}$' || ! "$target_tick" =~ '^[0-9]+$' || ! -f "$replay_path" ]]; then
    print -u2 "Invalid oracle plan entry $index."
    exit 2
  fi
  actual_replay_hash=$(shasum -a 256 "$replay_path" | awk '{print $1}')
  if [[ "$actual_replay_hash" != "$replay_hash" ]]; then
    print -u2 "Replay SHA-256 changed at plan entry $index."
    exit 2
  fi
  snapshot="$snapshot_root/$replay_hash"
  mkdir -p "$snapshot"
  if [[ ! -f "$snapshot/game.bin" || ! -f "$snapshot/initial-terrain.bin" ||
        ! -f "$snapshot/renderer.bin" || ! -f "$snapshot/gadgets.bin" ]]; then
    windows_replay="Z:${replay_path//\//\\}"
    windows_snapshot="Z:${snapshot//\//\\}"
    nohup "$wine" --bottle "$bottle" "$ce_executable" "$windows_replay" \
      >"$snapshot/launch.log" 2>&1 &
    "$wine" --bottle "$bottle" "$controller" "$target_tick" "$windows_snapshot"
    print -r -- "$replay_hash" > "$snapshot/replay-sha256.txt"
    print -r -- "$replay_path" > "$snapshot/replay-path.txt"
  fi
  print "CE final-state capture: $index/$total tick $target_tick"
done < "$plan"

ruby "$project_dir/Tools/NeoLemmixCEFinalState/export.rb" \
  "$plan" "$snapshot_root" "$levels_root" "$output_manifest"
print "Wrote $total CE final states to $output_manifest."
print "Retained CE memory snapshots in $snapshot_root."
