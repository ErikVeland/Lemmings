#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/portable-tests"
mkdir -p "$build_dir/modules"

swiftc -swift-version 6 -parse-as-library \
  -emit-module -emit-library \
  -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" \
  "$project_dir"/Sources/NxlvKit/*.swift

swiftc -swift-version 6 \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/PortableTests" \
  "$project_dir/Tests/PortableTests/main.swift"

"$build_dir/PortableTests" "$project_dir"

modern_build="$project_dir/.build/modern-engine-tests"
mkdir -p "$modern_build/modules"
swiftc -swift-version 6 -parse-as-library -emit-module -emit-library -module-name NxlvKit -emit-module-path "$modern_build/modules/NxlvKit.swiftmodule" -o "$modern_build/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
swiftc -swift-version 6 -I "$modern_build/modules" -L "$modern_build" -lNxlvKit -Xlinker -rpath -Xlinker "$modern_build" -o "$modern_build/ModernEngineTests" "$project_dir/Tests/ModernEngineTests/main.swift"
"$modern_build/ModernEngineTests"
swiftc -swift-version 6 -I "$modern_build/modules" -L "$modern_build" -lNxlvKit -Xlinker -rpath -Xlinker "$modern_build" -o "$modern_build/ProgressTests" "$project_dir/Tests/ModernEngineTests/ProgressTests.swift"
"$modern_build/ProgressTests"
