#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/lemmings-hint-tests.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
swiftc -swift-version 6 -parse-as-library -emit-module -emit-library -module-name NxlvKit \
  "$project_dir/Sources/NxlvKit/InterfaceLocalisation.swift" \
  "$project_dir/Sources/NxlvKit/SkillVocabulary.swift" \
  -emit-module-path "$build_dir/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib -o "$build_dir/libNxlvKit.dylib"

swiftc -swift-version 6 -I "$build_dir" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  "$project_dir/Sources/LemmingsAppCore/Hints/LevelHints.swift" \
  "$project_dir/Sources/LemmingsAppCore/AppStorage.swift" \
  "$project_dir/Tests/LevelHintCatalogueTests/main.swift" \
  -o "$build_dir/hint-tests"
"$build_dir/hint-tests" "$project_dir"
