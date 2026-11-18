"""Stage the clean candidate under the existing local review save identity."""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'Tools/AlternativeAssets'))
import personal_preview as preview
import store_resources

BASE = ROOT / '.build/ultimate-lemmix-app-store-build4-universal'
SOURCE = BASE / 'Ultimate Lemmix.app'
OLD = ROOT / '.build/ultimate-lemmix-hud-build3-manual-review/Ultimate Lemmix.app'
OUTPUT = ROOT / '.build/ultimate-lemmix-build4-manual-review'
TARGET = OUTPUT / SOURCE.name
IDENTIFIER = 'academy.glasscode.ultimatelemmix.personal-review.build3'


def inventory(app):
    """Hash bundle files without changing the earlier review installation."""
    if any(path.is_symlink() for path in app.rglob('*')):
        raise ValueError('A review application contains a link.')
    return [{'path': path.relative_to(app).as_posix(), 'bytes': path.stat().st_size,
             'sha256': preview.sha(path.read_bytes())}
            for path in sorted(app.rglob('*')) if path.is_file()]


old_inventory = inventory(OLD)
assert plistlib.loads((OLD / 'Contents/Info.plist').read_bytes())['CFBundleIdentifier'] == IDENTIFIER
evidence = json.loads((BASE / 'build-evidence.json').read_bytes())
assert evidence['sourceSnapshotVerified'] is True and evidence['build'] == '4'
preview.verify_artifacts(evidence['compilerOutputs'])
archive = BASE / evidence['reviewArchive']['path']
assert preview.sha(archive.read_bytes()) == evidence['reviewArchive']['sha256']
files = store_resources.collect()
store_resources.verify_tree(SOURCE / 'Contents/Resources', files)
if OUTPUT.exists():
    raise ValueError('The build4 manual review directory already exists; do not replace it.')
OUTPUT.mkdir()
preview.run(['ditto', SOURCE, TARGET])
info = plistlib.loads((TARGET / 'Contents/Info.plist').read_bytes())
assert not info.get('UltimateLemmixPersonalPreview', False)
info['CFBundleIdentifier'] = IDENTIFIER
(TARGET / 'Contents/Info.plist').write_bytes(plistlib.dumps(info, sort_keys=False))
preview.run(['codesign', '--force', '--sign', '-', '--options', '0x0', '--entitlements',
             ROOT / 'Resources/UltimateLemmix/AppStore.entitlements', '--identifier', IDENTIFIER, TARGET])
preview.run(['codesign', '--verify', '--deep', '--strict', TARGET])
store_resources.verify_tree(TARGET / 'Contents/Resources', files)
signature = preview.signature(TARGET)
signing = subprocess.run(['codesign', '-d', '--verbose=4', TARGET], capture_output=True,
                         text=True, check=True).stderr
assert re.search(r'^Identifier=(.*)$', signing, re.M).group(1) == IDENTIFIER
source_info = plistlib.loads((SOURCE / 'Contents/Info.plist').read_bytes())
assert {**source_info, 'CFBundleIdentifier': IDENTIFIER} == info
changed = []
source_rows = {row['path']: row for row in inventory(SOURCE)}
target_rows = {row['path']: row for row in inventory(TARGET)}
assert set(source_rows) == set(target_rows)
for name in source_rows:
    if source_rows[name] != target_rows[name]:
        assert name in ('Contents/Info.plist', 'Contents/MacOS/UltimateLemmix',
                        'Contents/_CodeSignature/CodeResources')
        changed.append(name)
assert old_inventory == inventory(OLD)
record = {'schemaVersion': 1, 'profile': 'clean-alternative-assets-manual-review', 'build': '4',
    'bundleIdentifier': IDENTIFIER, 'existingReviewSaveIdentityPreserved': True,
    'newProfileCreated': False, 'sourceArchiveSHA256': evidence['reviewArchive']['sha256'],
    'resourcesExactCleanCandidate': True, 'originalPersonalAssetsIncluded': False,
    'changedBundlePaths': changed, 'signature': signature, 'oldBuild3BundleUnchanged': True,
    'oldBuild3BundleInventory': old_inventory, 'targetInventory': list(target_rows.values()),
    'redistributionCleared': False, 'projectIconRightsReviewRequired': True,
    'launched': False}
(OUTPUT / 'manual-review-evidence.json').write_bytes(preview.encoded(record))
print('PASS clean build4 manual-review copy; existing review identity retained; no launch.', flush=True)
