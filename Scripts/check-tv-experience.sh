#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/tv-experience"
mkdir -p "$build_dir/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$build_dir/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$build_dir/ModuleCache"
cd "$project_dir"
swift build --build-system native --target LemmingsTVCore --disable-sandbox --disable-automatic-resolution --cache-path "$build_dir/cache" --config-path "$build_dir/config" --security-path "$build_dir/security" -j 4
swift build --build-system native --target LemmingsGameArt --disable-sandbox --disable-automatic-resolution --cache-path "$build_dir/cache" --config-path "$build_dir/config" --security-path "$build_dir/security" -j 4
products="$(swift build --build-system native --show-bin-path --disable-sandbox --disable-automatic-resolution --cache-path "$build_dir/cache" --config-path "$build_dir/config" --security-path "$build_dir/security")"
mkdir -p "$build_dir/frozen/Modules"
cp -R "$products/Modules/." "$build_dir/frozen/Modules/"
for module in NxlvKit LemmingsAppCore LemmingsMobileCore LemmingsTVCore LemmingsGameArt; do
    mkdir -p "$build_dir/frozen/$module.build"
    cp "$products/$module.build/"*.swift.o "$build_dir/frozen/$module.build/"
done
swiftc -swift-version 6 -parse-as-library -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/frozen/Modules" \
    "$project_dir/Tests/TVExperienceTests/main.swift" "$build_dir"/frozen/{NxlvKit,LemmingsAppCore,LemmingsMobileCore,LemmingsTVCore}.build/*.swift.o -o "$build_dir/tests"
LEMMINGS_TEST_WINDOWS=offscreen LEMMINGS_TEST_AUDIO=muted python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests" "$project_dir"
if [[ -f "$project_dir/Tools/TVExperienceAudit/main.swift" ]]; then
    audit_contents="$build_dir/TVArtworkAudit.app/Contents"
    mkdir -p "$audit_contents/MacOS" "$audit_contents/Resources/MacArtwork"
    cat > "$audit_contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>academy.glasscode.lemmings.tv.artwork-audit</string><key>CFBundleExecutable</key><string>audit</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
PLIST
    ln -sfn "$project_dir/.build/mac-artwork/export/lemmings" "$audit_contents/Resources/MacArtwork/lemmings"
    swiftc -swift-version 6 -parse-as-library -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/frozen/Modules" \
        "$project_dir"/Tools/TVExperienceAudit/*.swift "$build_dir"/frozen/{NxlvKit,LemmingsAppCore,LemmingsMobileCore,LemmingsTVCore,LemmingsGameArt}.build/*.swift.o -o "$audit_contents/MacOS/audit"
    LEMMINGS_TEST_WINDOWS=offscreen LEMMINGS_TEST_AUDIO=muted python3 "$project_dir/Tools/UITestRunner/run.py" "$audit_contents/MacOS/audit" "$project_dir"
fi
if [[ "${TV_EXPORT_ASSETS:-0}" = 1 ]]; then
    swiftc -swift-version 6 -parse-as-library -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/frozen/Modules" \
        "$project_dir/Tools/TVAssets/main.swift" "$build_dir"/frozen/{NxlvKit,LemmingsAppCore,LemmingsMobileCore,LemmingsTVCore,LemmingsGameArt}.build/*.swift.o -o "$audit_contents/MacOS/audit"
    LEMMINGS_TEST_WINDOWS=offscreen LEMMINGS_TEST_AUDIO=muted python3 "$project_dir/Tools/UITestRunner/run.py" "$audit_contents/MacOS/audit" "$project_dir"
fi
