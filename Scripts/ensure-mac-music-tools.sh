#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cache="$project_dir/.build/mac-reference"
resource_revision=2f1ec79429f0129691791d76c443f411291eb10b
phosg_revision=5c2a7213dafb698e3eac41828a86204d848bc7ba
tool_version="$resource_revision $phosg_revision wav-interleaved-v1"
if [[ -x "$cache/resource-build/resource_dasm" && -x "$cache/resource-build/smssynth" &&
      -f "$cache/versions" && "$(cat "$cache/versions")" == "$tool_version" ]]; then
  print "$cache/resource-build"
  exit 0
fi
mkdir -p "$cache"
for name in resource_dasm phosg; do
  if [[ ! -d "$cache/$name/.git" ]]; then
    git clone --quiet "https://github.com/fuzziqersoftware/$name.git" "$cache/$name" >&2
  fi
  revision="$resource_revision"
  [[ "$name" == phosg ]] && revision="$phosg_revision"
  git -C "$cache/$name" checkout --quiet --detach "$revision" >&2
done
# The pinned writer counts interleaved stereo samples twice in its RIFF sizes.
# Correct only those two sizes; synthesis and instrument decoding stay intact.
python3 - "$cache/resource_dasm/src/Audio/WAVFile.cc" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
before = 'samples.size() * num_channels * bits_per_sample'
after = 'samples.size() * bits_per_sample'
if text.count(before) == 2:
    p.write_text(text.replace(before, after))
elif text.count(before) != 0 or text.count(after) != 2:
    sys.exit('Unexpected reference WAVE writer; refusing to patch it.')
PY
# These are file renderers. SDL audio output is deliberately excluded.
cmake -S "$cache/phosg" -B "$cache/phosg-build" -DCMAKE_OSX_ARCHITECTURES="$(uname -m)" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$cache/install" >&2
cmake --build "$cache/phosg-build" -j 4 >&2
cmake --install "$cache/phosg-build" >&2
cmake -S "$cache/resource_dasm" -B "$cache/resource-build" -DDISABLE_SDL=1 \
  -DCMAKE_OSX_ARCHITECTURES="$(uname -m)" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$cache/install" >&2
cmake --build "$cache/resource-build" --target resource_dasm smssynth -j 4 >&2
print "$tool_version" > "$cache/versions"
print "$cache/resource-build"
