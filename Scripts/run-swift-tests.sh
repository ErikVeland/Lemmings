#!/bin/zsh
# Use public manifest interfaces when Command Line Tools retain stale private ones.
set -euo pipefail
project_dir="${0:A:h:h}"
toolchain_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
if [[ -x "$toolchain_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift" ]]; then
  swift_root="$toolchain_dir/Toolchains/XcodeDefault.xctoolchain/usr"
else
  swift_root="$toolchain_dir/usr"
fi
swift_command="$swift_root/bin/swift"
manifest_api="$swift_root/lib/swift/pm/ManifestAPI"
if [[ "$toolchain_dir" == /Library/Developer/CommandLineTools* && -d "$manifest_api" ]]; then
  local_libs="$project_dir/.build/swiftpm-libs"
  mkdir -p "$local_libs"
  ditto "$manifest_api" "$local_libs/ManifestAPI"
  rm -f "$local_libs"/ManifestAPI/PackageDescription.swiftmodule/*.private.swiftinterface(N)
  export SWIFTPM_CUSTOM_LIBS_DIR="$local_libs"
  export DYLD_FRAMEWORK_PATH="$toolchain_dir/Library/Developer/Frameworks${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
fi
cd "$project_dir"
"$swift_command" test --disable-xctest -Xlinker -rpath \
  -Xlinker "$toolchain_dir/Library/Developer/Frameworks" \
  -Xlinker -rpath -Xlinker "$toolchain_dir/Library/Developer/usr/lib" \
  -Xswiftc -plugin-path -Xswiftc "$swift_root/lib/swift/host/plugins/testing" "$@"
