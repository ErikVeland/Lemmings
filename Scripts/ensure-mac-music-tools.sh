#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cache="$project_dir/.build/mac-reference"
resource_revision=2f1ec79429f0129691791d76c443f411291eb10b
phosg_revision=5c2a7213dafb698e3eac41828a86204d848bc7ba
# Xcode runs this host tool from iOS and tvOS build phases. Do not inherit
# their SDK or deployment target when compiling the local file renderers.
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
export MACOSX_DEPLOYMENT_TARGET="$(sw_vers -productVersion)"
unset IPHONEOS_DEPLOYMENT_TARGET TVOS_DEPLOYMENT_TARGET WATCHOS_DEPLOYMENT_TARGET XROS_DEPLOYMENT_TARGET
host_cmake_args=(
  -DCMAKE_SYSTEM_NAME=Darwin
  -DCMAKE_OSX_SYSROOT="$SDKROOT"
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET"
  -DCMAKE_OSX_ARCHITECTURES="$(uname -m)"
  -DCMAKE_C_COMPILER="$(xcrun --sdk macosx --find clang)"
  -DCMAKE_CXX_COMPILER="$(xcrun --sdk macosx --find clang++)"
)
tool_version="$resource_revision $phosg_revision wav-interleaved-v1 host-macos-v1 $(uname -m)"
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
# Discard CMake configuration left by a build with a different SDK or compiler.
cmake --fresh -S "$cache/phosg" -B "$cache/phosg-build" "${host_cmake_args[@]}" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$cache/install" >&2
cmake --build "$cache/phosg-build" -j 4 >&2
cmake --install "$cache/phosg-build" >&2
cmake --fresh -S "$cache/resource_dasm" -B "$cache/resource-build" -DDISABLE_SDL=1 \
  "${host_cmake_args[@]}" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$cache/install" >&2
cmake --build "$cache/resource-build" --target resource_dasm smssynth -j 4 >&2
print "$tool_version" > "$cache/versions"
print "$cache/resource-build"
