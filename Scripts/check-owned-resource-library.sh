#!/bin/zsh
# Check resource imports without UI, audio or changes to installed applications.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/owned-resource-library-tests"
base="${ULTIMATE_LEMMIX_CORE_BUILD_DIR:-$project_dir/.build/ultimate-lemmix-app-store-build3-universal}"
architecture="$(uname -m)"
compiler=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk
mkdir -p "$build_dir/ModuleCache"
sources=("$project_dir/Tests/OwnedResourceLibraryTests/main.swift")
flags=()
if [[ -f "$project_dir/Sources/LemmingsLocal/OwnedResourceLibrary.swift" ]]; then
  sources+=("$project_dir/Sources/LemmingsLocal/OwnedResourceLibrary.swift")
  sources+=("$project_dir/Sources/LemmingsLocal/NativeCursorRecovery.swift")
  flags=(-DOWNED_RESOURCE_LIBRARY_AVAILABLE)
fi
"$compiler" -swift-version 6 -sdk "$sdk" -target "$architecture-apple-macosx12.3" \
  -module-cache-path "$build_dir/ModuleCache" -I "$base/$architecture/modules" \
  -L "$base/Ultimate Lemmix.app/Contents/Frameworks" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$base/Ultimate Lemmix.app/Contents/Frameworks" \
  "${flags[@]}" -o "$build_dir/check" "${sources[@]}"
LEMMINGS_TEST_AUDIO=muted LEMMINGS_TEST_WINDOWS=offscreen "$build_dir/check"
