#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h:h}"
build_dir="$project_dir/.build/asset-parity-storage"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export LEMMINGS_TEST_AUDIO=muted
mkdir -p "$build_dir/ModuleCache"
# No repository script compiles this isolated Foundation-only storage contract.
xcrun --sdk macosx swiftc -swift-version 6 -parse-as-library \
  -module-cache-path "$build_dir/ModuleCache" \
  "$project_dir/Sources/LemmingsAppCore/AppStorage.swift" \
  "$project_dir/Sources/LemmingsAppCore/Resources/GameResources.swift" \
  "$project_dir/Tests/UltimateLemmixAssetParity/StorageChecks.swift" \
  -o "$build_dir/storage-checks"
export LEMMINGS_TEST_APPLICATION_SUPPORT="$build_dir/RetainedStorage"
export LEMMIX_PARITY_STORAGE_FIXTURE="$build_dir/StorageFixture.bundle"
LEMMIX_PARITY_STORAGE_PHASE=write "$build_dir/storage-checks"
LEMMIX_PARITY_STORAGE_PHASE=reopen "$build_dir/storage-checks"
