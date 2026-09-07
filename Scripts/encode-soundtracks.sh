#!/bin/zsh
# Copies the soundtrack recordings into a build as Apple Lossless.
#
# The recordings are 44.1 kHz 16 bit stereo WAV, which is about 400 MB. Apple
# Lossless keeps every sample and takes roughly 70% of that, which is worth
# having in a download people wait for. The source files are left alone.
#
# The player reads `.m4a` already, so nothing else changes: `SoundtrackPlayer`
# lists it among the extensions the system decoder handles.
set -euo pipefail

source_root="${1:?source Music directory}"
target_root="${2:?target Music directory}"

count=0
find "$source_root" -type f -name '*.wav' -print0 | while IFS= read -r -d '' wav; do
  relative="${wav#$source_root/}"
  target="$target_root/${relative%.wav}.m4a"
  mkdir -p "${target:h}"
  # Skip anything already encoded, so repeat builds stay quick.
  if [[ -f "$target" && "$target" -nt "$wav" ]]; then continue; fi
  afconvert -f m4af -d alac "$wav" "$target"
  count=$((count + 1))
done

echo "Encoded soundtracks to Apple Lossless in $target_root"
