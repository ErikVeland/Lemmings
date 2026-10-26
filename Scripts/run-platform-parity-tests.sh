#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
swift build --disable-sandbox --disable-automatic-resolution --build-tests -j 4
bin_dir="$(swift build --disable-sandbox --disable-automatic-resolution --show-bin-path)"
# The SwiftPM helper normally has no game resources. Give this isolated host the
# packaged engine identity so ghost archives retain their production validation.
python3 - <<'PYTHON'
from pathlib import Path
import plistlib, shutil, subprocess
root = Path('.build/platform-parity/ParityTests.app/Contents')
(root / 'MacOS').mkdir(parents=True, exist_ok=True)
(root / 'Resources/Trolley').mkdir(parents=True, exist_ok=True)
swift = Path(subprocess.check_output(['xcrun', '--find', 'swift'], text=True).strip())
shutil.copy2(swift.parent.parent / 'libexec/swift/pm/swiftpm-testing-helper', root / 'MacOS/ParityTests')
shutil.copy2('Resources/Trolley/engine-fingerprint.txt', root / 'Resources/Trolley/engine-fingerprint.txt')
(root / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleExecutable': 'ParityTests',
    'CFBundleIdentifier': 'academy.glasscode.lemmings.integration-tests.platform-parity',
    'CFBundlePackageType': 'APPL', 'CFBundleName': 'ParityTests',
}))
PYTHON
native_developer="$(xcode-select -p)"
for target in LemmingsMobileCoreTests LemmingsMobileUITests; do
  python3 Tools/UITestRunner/run.py env \
    DYLD_FRAMEWORK_PATH="$native_developer/Platforms/MacOSX.platform/Developer/Library/Frameworks" \
    DYLD_LIBRARY_PATH="$native_developer/Platforms/MacOSX.platform/Developer/usr/lib" \
    "$project_dir/.build/platform-parity/ParityTests.app/Contents/MacOS/ParityTests" \
    --test-bundle-path "$bin_dir/$target.xctest/Contents/MacOS/$target" --testing-library swift-testing --filter \
    'PlatformParityClosureTests|MobilePresentationParity|MobileTouchSelectionTests|MobilePrecisionSelectionTests|MobileExtraSkillTests|MobileRewindTests'
done
