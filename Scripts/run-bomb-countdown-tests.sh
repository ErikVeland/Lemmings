#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/native-countdown"
mkdir -p "$build_dir/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$build_dir/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$build_dir/ModuleCache"
cd "$project_dir"
swift build --build-system native --target LemmingsGameArt --disable-sandbox --disable-automatic-resolution -j 4
products="$(swift build --build-system native --show-bin-path --disable-sandbox --disable-automatic-resolution)"
# Freeze modules and objects while other chats continue to build the game.
mkdir -p "$build_dir/frozen/Modules"
cp -R "$products/Modules/." "$build_dir/frozen/Modules/"
for module in NxlvKit LemmingsAppCore LemmingsMobileCore LemmingsGameArt; do
    mkdir -p "$build_dir/frozen/$module.build"
    cp "$products/$module.build/"*.swift.o "$build_dir/frozen/$module.build/"
done
swiftc -swift-version 6 -parse-as-library -module-cache-path "$build_dir/ModuleCache" \
    -I "$build_dir/frozen/Modules" -o "$build_dir/tests" \
    "$project_dir/Tests/BombCountdownTests/main.swift" \
    "$build_dir"/frozen/{NxlvKit,LemmingsAppCore,LemmingsMobileCore,LemmingsGameArt}.build/*.swift.o
LEMMINGS_TEST_WINDOWS=offscreen LEMMINGS_TEST_AUDIO=muted \
    python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests" "$project_dir"
