#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
root="${L3_MOLE_TRACE_ROOT:-$project_dir/.build/l3-mole-verification/source-left-facing}"
trace_case="${L3_MOLE_TRACE_CASE:-steel-left-facing}"
build_dir="$project_dir/.build/l3-mole-production-trace"
library_dir="${L3_TEST_LIBRARY_DIR:-$build_dir}"
mkdir -p "$build_dir/modules" "$library_dir/modules"
cd "$project_dir"
swiftc -O -swift-version 6 -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$library_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$library_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -I "$library_dir/modules" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" \
  -o "$build_dir/MoleTrace" Tools/Lemmings3Completion/MoleTrace.swift
"$build_dir/MoleTrace" "$root" > "$build_dir/production-trace-$trace_case.json"
python3 Tools/Lemmings3Completion/compare_mole_trace.py \
  "$build_dir/production-trace-$trace_case.json" \
  Documentation/ReleaseReadiness/L3MoleVerification-2026-10-15/original-followup-traces.json \
  "$trace_case"
