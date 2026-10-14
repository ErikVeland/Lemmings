#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
require_fan_routes=0
if [[ "${@[-1]-}" == "--require-fan-routes" ]]; then
  require_fan_routes=1
  set -- "${@[1,-2]}"
fi
if (( $# < 2 || $# > 3 )); then
  print -u2 'Usage: run-classic-validation.sh APP_RESOURCES OUTPUT_DIR [FIXTURE_ROOT] [--require-fan-routes]'
  exit 2
fi
resources="${1:A}"
output="${2:A}"
fixtures="${3:-$project_dir}"
build_dir="$output/build"
mkdir -p "$build_dir/modules"
python3 "$project_dir/Tools/ClassicValidation/manifest.py" "$project_dir" "$resources" "$fixtures" "$output"
# Compile the current core. Never certify against an unspecified cached library.
swiftc -O -swift-version 6 -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" -o "$build_dir/Audit" \
  "$project_dir/Tools/ClassicValidation/main.swift" \
  "$project_dir/Sources/LemmingsLocal/GameAssetCache.swift" \
  "$project_dir/Sources/LemmingsAppCore/Collections/ClassicSourceRevision.swift" \
  "$project_dir/Sources/LemmingsLocal/FanLevelLibrary.swift"
audit_status=0
"$build_dir/Audit" "$resources" "$output" "$fixtures" || audit_status=$?
coverage_status=0
if (( require_fan_routes )); then
  python3 "$project_dir/Tools/ClassicValidation/report.py" --require-fan-routes "$resources" "$output" || coverage_status=$?
else
  python3 "$project_dir/Tools/ClassicValidation/report.py" "$resources" "$output" || coverage_status=$?
fi
drift_status=0
python3 "$project_dir/Tools/ClassicValidation/manifest.py" "$project_dir" "$resources" "$fixtures" "$output" --check || drift_status=$?
(( audit_status == 0 && coverage_status == 0 && drift_status == 0 ))
