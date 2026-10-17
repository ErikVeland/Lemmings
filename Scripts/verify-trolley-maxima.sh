#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
build_dir="$project_dir/.build/trolley-verification"
jobs="${TROLLEY_AUDIT_JOBS:-8}"
resources_dir="${TROLLEY_RESOURCES:-$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources}"
results_dir="${TROLLEY_OUTPUT:-$build_dir/results}"
if [[ "$jobs" != <1-32> ]]; then
  echo "TROLLEY_AUDIT_JOBS must be between 1 and 32." >&2
  exit 1
fi
if [[ ! -d "$resources_dir/Ports" ]]; then
  echo "TROLLEY_RESOURCES must point to a resource bundle with Ports." >&2
  exit 1
fi
export TROLLEY_RESOURCES="$resources_dir"
export TROLLEY_OUTPUT="$results_dir"
mkdir -p "$build_dir/modules" "$results_dir"
engine_before=$(python3 Tools/TrolleyVerification/catalogue.py fingerprint)
swiftc -swift-version 6 -O -target "$(uname -m)-apple-macos12.3" -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -swift-version 6 -O -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/audit" Tools/Lemmings3Completion/Replay.swift Tools/TrolleyVerification/main.swift
if [[ "$engine_before" != "$(python3 Tools/TrolleyVerification/catalogue.py fingerprint)" ]]; then
  echo "Engine sources changed during compilation. Run the audit again." >&2
  exit 1
fi
if [[ "$engine_before" != "$("$build_dir/audit" fingerprint)" ]]; then
  echo "Verifier and packager fingerprints differ. No replays were run." >&2
  exit 1
fi
search_args=()
if [[ "${TROLLEY_AUDIT_SEARCH:-1}" == 1 ]]; then search_args=(--search); fi
workers=()
for (( shard=0; shard<jobs; shard++ )); do
  "$build_dir/audit" classic "${search_args[@]}" "--shard=$shard/$jobs" > "$build_dir/classic-$shard.log" 2>&1 &
  workers+=($!)
done
for family in ports l2 l3; do
  "$build_dir/audit" "$family" > "$build_dir/$family.log" 2>&1 &
  workers+=($!)
done
failed=0
for worker in "${workers[@]}"; do
  wait "$worker" || failed=1
done
if (( failed )); then
  echo "An audit failed. Inspect $build_dir/*.log." >&2
  exit 1
fi
if [[ "$engine_before" != "$(python3 Tools/TrolleyVerification/catalogue.py fingerprint)" ]]; then
  echo "Engine sources changed during verification. No proofs were packaged." >&2
  exit 1
fi
python3 Tools/TrolleyVerification/catalogue.py merge --results "$results_dir" --shards "$jobs"
