#!/bin/zsh
# Re-encode the bundled Apple Lossless music as AAC for distribution.
#
# The source library stays lossless. Only the copy inside the app changes,
# so file names and catalogue paths stay the same. GitHub release assets
# must stay below 2 GiB, and the lossless soundtrack alone is about 3.8 GB.
set -euo pipefail

music_dir="${1:?Usage: compact-bundled-music.sh BUNDLED_MUSIC_DIR}"
project_dir="${0:A:h:h}"
cache_dir="${MUSIC_AAC_CACHE:-$project_dir/.build/music-aac}"
bitrate="${MUSIC_AAC_BITRATE:-192000}"
jobs="${MUSIC_AAC_JOBS:-$(sysctl -n hw.ncpu)}"
mkdir -p "$cache_dir"

encode_one() {
  local file="$1" cache_dir="$2" bitrate="$3"
  afinfo "$file" 2>/dev/null | grep -q 'Data format:.*alac' || return 0
  # Key the cache by content, so an edited source never reuses a stale encode.
  local key="$(shasum -a 256 "$file" | cut -c1-40)-$bitrate"
  local cached="$cache_dir/$key.m4a"
  if [[ ! -s "$cached" ]]; then
    afconvert -f m4af -d aac -b "$bitrate" -s 2 -q 127 "$file" "$cached.tmp"
    mv "$cached.tmp" "$cached"
  fi
  cp "$cached" "$file.aac" && mv "$file.aac" "$file"
}

before="$(du -sk "$music_dir" | cut -f1)"
find "$music_dir" -type f -name '*.m4a' -print0 |
  xargs -0 -n 1 -P "$jobs" zsh -c "$(typeset -f encode_one); encode_one \"\$1\" '$cache_dir' '$bitrate'" _
remaining="$(find "$music_dir" -type f -name '*.m4a' -exec afinfo {} \; 2>/dev/null | grep -c 'Data format:.*alac' || true)"
[[ "$remaining" == 0 ]] || { echo "FAILED: $remaining bundled tracks are still lossless." >&2; exit 1; }
after="$(du -sk "$music_dir" | cut -f1)"
echo "Compacted bundled music: $((before / 1024)) MB -> $((after / 1024)) MB (AAC $((bitrate / 1000)) kbps)"
