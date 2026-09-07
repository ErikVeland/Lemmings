#!/bin/zsh
# Use public manifest interfaces when Command Line Tools retain stale private ones.
set -euo pipefail
project_dir="${0:A:h:h}"
toolchain_dir="$(xcode-select -p)"
manifest_api="$toolchain_dir/usr/lib/swift/pm/ManifestAPI"
if [[ -d "$manifest_api" ]]; then
  local_libs="$project_dir/.build/swiftpm-libs"
  mkdir -p "$local_libs"
  ditto "$manifest_api" "$local_libs/ManifestAPI"
  rm -f "$local_libs"/ManifestAPI/PackageDescription.swiftmodule/*.private.swiftinterface(N)
  export SWIFTPM_CUSTOM_LIBS_DIR="$local_libs"
  export DYLD_FRAMEWORK_PATH="$toolchain_dir/Library/Developer/Frameworks${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
fi
cd "$project_dir"
swift test --disable-xctest -Xlinker -rpath \
  -Xlinker "$toolchain_dir/Library/Developer/Frameworks" \
  -Xlinker -rpath -Xlinker "$toolchain_dir/Library/Developer/usr/lib" \
  -Xswiftc -plugin-path -Xswiftc "$toolchain_dir/usr/lib/swift/host/plugins/testing" "$@"
