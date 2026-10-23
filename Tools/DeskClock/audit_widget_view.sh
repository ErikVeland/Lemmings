#!/bin/zsh
# Check the actual SwiftUI widget image in each desktop appearance, without opening windows.
set -euo pipefail
(( $# == 3 )) || { print -u2 "Usage: audit_widget_view.sh BUILD_DIR CLOCK_RENDERS OUTPUT_DIR"; exit 2; }
project_dir="${0:A:h:h:h}"
build_dir="${1:A}"
input_dir="${2:A}"
output_dir="${3:A}"
architecture="$(uname -m)"
mkdir -p "$output_dir"
swiftc -swift-version 6 -parse-as-library -target "$architecture-apple-macosx15" \
  -D LEMMINGS_WIDGET_AUDIT -module-cache-path "$build_dir/ModuleCache" \
  -I "$build_dir/$architecture/modules" -L "$build_dir/$architecture" \
  -lLemmingsGameArt -lLemmingsMobileCore -lLemmingsAppCore -lLemmingsTVCore -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir/$architecture" \
  -o "$output_dir/.WidgetViewAudit" \
  "$project_dir/Apps/DeskClockWidget/DeskClockWidget.swift" "$project_dir/Tools/DeskClock/WidgetViewAudit.swift"
python3 "$project_dir/Tools/UITestRunner/run.py" "$output_dir/.WidgetViewAudit" "$input_dir" "$output_dir"
