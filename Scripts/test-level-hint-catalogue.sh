#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/lemmings-hint-tests.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
swiftc -swift-version 6 \
  "$project_dir/Sources/LemmingsLocal/LevelHints.swift" \
  "$project_dir/Tests/LevelHintCatalogueTests/main.swift" \
  -o "$build_dir/hint-tests"
"$build_dir/hint-tests" "$project_dir"
