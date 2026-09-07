#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/bundle-tests"
library_dir="$project_dir/.build/local/Ultimate Lemmings.app/Contents/Frameworks"
module_dir="$project_dir/.build/local/$(uname -m)/modules"
mkdir -p "$build_dir"
swiftc -swift-version 6 -warnings-as-errors \
  -I "$module_dir" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" \
  -o "$build_dir/BundleTests" "$project_dir/Tests/BundledGameResourcesTests/main.swift"
# A different working directory catches accidental source-relative resolution.
app_paths=()
for candidate in "$@"; do app_paths+=("${candidate:A}"); done
cd /private/tmp
if (( $# )); then
  "$build_dir/BundleTests" "${app_paths[@]}"
else
  "$build_dir/BundleTests" "$project_dir/.build/native-l2/Lemmings 2 Native.app" "$project_dir/.build/local/Ultimate Lemmings.app"
fi
