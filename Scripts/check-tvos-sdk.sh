#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/tv-sdk"
mkdir -p "$build_dir/ModuleCache"
rm -rf "$build_dir/Modules"
mkdir -p "$build_dir/Modules"
rm -rf "$build_dir/Sources"
mkdir -p "$build_dir/Sources"
for module in NxlvKit LemmingsAppCore LemmingsMobileCore LemmingsAudio LemmingsTVCore LemmingsGameArt LemmingsMobileUI LemmingsTVUI; do
    cp -R "$project_dir/Sources/$module" "$build_dir/Sources/$module"
done
sdk="$(xcrun --sdk appletvsimulator --show-sdk-path)"
for module in NxlvKit LemmingsAppCore LemmingsMobileCore LemmingsAudio LemmingsTVCore LemmingsGameArt LemmingsMobileUI LemmingsTVUI; do
    mkdir -p "$build_dir/Modules/$module.swiftmodule"
    local_sources=("${(@f)$(rg --files "$build_dir/Sources/$module" -g '*.swift')}")
    swiftc -swift-version 6 -parse-as-library -target arm64-apple-tvos16.0-simulator -sdk "$sdk" \
        -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/Modules" \
        -module-name "$module" -emit-module -emit-module-path "$build_dir/Modules/$module.swiftmodule/arm64-apple-tvos-simulator.swiftmodule" \
        "${local_sources[@]}"
    print "PASS $module TV SDK module"
done
swiftc -swift-version 6 -parse-as-library -target arm64-apple-tvos16.0-simulator -sdk "$sdk" \
    -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/Modules" -typecheck "$project_dir/Apps/UltimateLemmingsTV/AppDelegate.swift"
print "PASS Apple TV application entry point"
