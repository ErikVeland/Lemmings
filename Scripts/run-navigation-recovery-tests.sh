#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
export LEMMINGS_TEST_WINDOWS=offscreen
export LEMMINGS_TEST_AUDIO=muted
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/navigation-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
python3 Tools/UITestRunner/run.py swift test --disable-sandbox --jobs 2 --filter \
  'MobileCoreTests/(planningDoes|completedResults|allThreeGames)|MobileHotSeatTests/|MobilePrecisionSelectionTests/|TVControllerBindingsTests/|TVMobileMigrationTests/|FooterNavigationTests'
bin_dir="$(swift build --disable-sandbox --show-bin-path)"
python3 Tools/UITestRunner/run.py "$bin_dir/LemmingsMobileMenuAudit" \
  "${1:-$project_dir/.build/mac-artwork/export/lemmings}" "$project_dir" \
  "${2:-$project_dir/.build/navigation-recovery}" --navigation
