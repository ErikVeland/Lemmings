"""Build frozen Mac frontends and reuse the archive-verified unchanged core."""
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'Tools/AlternativeAssets'))
import personal_preview as preview
import store_resources

BASE = ROOT / '.build/ultimate-lemmix-app-store-build3-universal'
OUTPUT = ROOT / '.build/ultimate-lemmix-app-store-build4-universal'
APP = OUTPUT / 'Ultimate Lemmix.app'
PERSONAL = ROOT / '.build/ultimate-lemmix-personal-preview-build4'
ARCHITECTURES = ['arm64', 'x86_64']
DEVELOPER = Path('/Applications/Xcode.app/Contents/Developer')
COMPILER = DEVELOPER / 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'
SDK = DEVELOPER / 'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'


def sign(app, identifier=None):
    """Apply the authorised local signature without hardened runtime."""
    preview.run(['codesign', '--force', '--sign', '-', '--options', '0x0',
                 app / 'Contents/Frameworks/libNxlvKit.dylib'])
    command = ['codesign', '--force', '--sign', '-', '--options', '0x0', '--entitlements',
               ROOT / 'Resources/UltimateLemmix/AppStore.entitlements']
    if identifier:
        command += ['--identifier', identifier]
    preview.run([*command, app])


def compile_frontend(architecture):
    """Compile one frontend against verified modules with a fresh private cache."""
    directory = OUTPUT / architecture
    directory.mkdir(exist_ok=True)
    cache = directory / 'ModuleCache'
    cache.mkdir(exist_ok=True)
    module = directory / 'modules/NxlvKit.swiftmodule'
    module.parent.mkdir(exist_ok=True)
    shutil.copy2(BASE / architecture / 'modules/NxlvKit.swiftmodule', module)
    library = directory / 'libNxlvKit.dylib'
    preview.run(['lipo', '-thin', architecture, core['libraryPath'], '-output', library])
    executable = directory / 'UltimateLemmix'
    flags = [COMPILER, '-swift-version', '6', '-O', '-sdk', SDK,
             '-target', architecture + '-apple-macosx12.3']
    if architecture == 'x86_64':
        flags += ['-runtime-compatibility-version', 'none']
    command = [*flags, '-DULTIMATE_LEMMIX_STORE', '-module-cache-path', cache,
               '-I', module.parent, '-L', Path(core['libraryPath']).parent, '-lNxlvKit',
               '-framework', 'AppKit', '-framework', 'AVFoundation', '-framework', 'Metal',
               '-framework', 'QuartzCore', '-Xlinker', '-rpath', '-Xlinker',
               '@executable_path/../Frameworks', '-Xlinker', '-w', '-o', executable,
               *sorted(ROOT.glob('Sources/LemmingsLocal/*.swift'))]
    (OUTPUT / (architecture + '-command.json')).write_bytes(preview.encoded(list(map(str, command))))
    print('Compiling frozen build4 frontend: ' + architecture, flush=True)
    with (OUTPUT / (architecture + '-frontend.log')).open('w') as log:
        preview.run(command, log)
    if preview.source_snapshot() != before or store_resources.build_inputs() != build_inputs:
        raise ValueError('Frozen source inputs changed during compilation.')
    print('PASS frontend compilation: ' + architecture, flush=True)
    return [dict(preview.artifact(executable, architecture), compiledAgain=True),
            dict(preview.artifact(library, architecture), compiledAgain=False,
                 origin='archive-verified-build3-core-slice'),
            dict(preview.artifact(module, architecture), compiledAgain=False,
                 origin='verified-build3-core-module')]


before = preview.source_snapshot()
build_inputs = store_resources.build_inputs()
core = preview.verify_core(BASE, ARCHITECTURES)
old_evidence = json.loads(preview.read_regular(BASE / 'build-evidence.json'))
preview.verify_artifacts(old_evidence['compilerOutputs'])
clean_files = store_resources.collect()
private_files = preview.resource_files()
store_resources.verify_tree(APP / 'Contents/Resources', clean_files)
preview.verify_resources(PERSONAL / 'Ultimate Lemmix.app/Contents/Resources', private_files)
assert plistlib.loads((APP / 'Contents/Info.plist').read_bytes()) == plistlib.loads(
    (ROOT / 'Resources/UltimateLemmix/Info.plist').read_bytes())
assert plistlib.loads((PERSONAL / 'Ultimate Lemmix.app/Contents/Info.plist').read_bytes()) == preview.app_info(private_files)
store_resources.record_build_inputs(OUTPUT / 'source-inputs.json')
(OUTPUT / 'packaging-inputs.json').write_bytes(preview.encoded({'files': before,
    'buildHelperSHA256': preview.sha(Path(__file__).read_bytes())}))
with ThreadPoolExecutor(max_workers=2) as pool:
    compiler_outputs = [row for result in pool.map(compile_frontend, ARCHITECTURES) for row in result]
for name in ('MacOS', 'Frameworks'):
    (APP / 'Contents' / name).mkdir(exist_ok=True)
preview.run(['lipo', '-create', *[OUTPUT / arch / 'UltimateLemmix' for arch in ARCHITECTURES],
             '-output', APP / 'Contents/MacOS/UltimateLemmix'])
shutil.copy2(core['libraryPath'], APP / 'Contents/Frameworks/libNxlvKit.dylib')
sign(APP)
environment = dict(os.environ, ULTIMATE_LEMMIX_BUILD_DIR=str(OUTPUT))
with (OUTPUT / 'strict-app-audit.log').open('w') as log:
    subprocess.run(['zsh', ROOT / 'Scripts/build-ultimate-lemmix-app-store.sh', '--audit'],
                   env=environment, stdout=log, stderr=log, check=True)
store_resources.verify_tree(APP / 'Contents/Resources', clean_files)
clean_bins = {}
for name in ('Contents/MacOS/UltimateLemmix', 'Contents/Frameworks/libNxlvKit.dylib'):
    path = APP / name
    archs = subprocess.check_output(['lipo', '-archs', path], text=True).split()
    assert set(archs) == set(ARCHITECTURES)
    clean_bins[name] = {'architectures': archs, 'sha256': preview.sha(preview.read_regular(path)),
        'dependencies': preview.dependency_paths(subprocess.check_output(['otool', '-L', path], text=True))}
assert before == preview.source_snapshot()
assert core == preview.verify_core(BASE, ARCHITECTURES)
evidence_path = OUTPUT / 'build-evidence.json'
evidence = store_resources.write_build_evidence(evidence_path, COMPILER, SDK, '-', ARCHITECTURES,
    APP / 'Contents/Resources/store-resources-manifest.json')
info = plistlib.loads((APP / 'Contents/Info.plist').read_bytes())
clean_archive = preview.package(APP, OUTPUT / 'Ultimate-Lemmix-0.1-build4-macOS.zip')
clean_audit = {'profile': 'alternative-assets-local-review', 'build': '4',
    'resourceFiles': len(clean_files), 'binaries': clean_bins, 'signature': preview.signature(APP),
    'sourceSnapshotVerified': True, 'officialCampaignPayloadsIncluded': False,
    'originalGameFontIncluded': False, 'communityCorpusIncluded': False,
    'redistributionCleared': False, 'projectIconRightsReviewRequired': True,
    'featureDataAudit': json.loads(clean_files['Provenance/feature-data-audit.json'])}
evidence.update({'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
    'coreMode': 'archive-verified-build3-core-reuse', 'reusedCore': core,
    'compilerOutputs': compiler_outputs, 'packagingInputs': before,
    'buildHelperSHA256': preview.sha(Path(__file__).read_bytes()),
    'appAudit': clean_audit, 'reviewArchive': clean_archive})
evidence_path.write_bytes(preview.encoded(evidence))
(OUTPUT / 'final-audit.json').write_bytes(preview.encoded(dict(clean_audit, reviewArchive=clean_archive)))
print('PASS clean build4 exact source/code/resource/signature/archive audit.', flush=True)

# Resources and Info remain in place for the parallel native test harness.
personal_app = PERSONAL / APP.name
preview.verify_resources(personal_app / 'Contents/Resources', private_files)
copied_outputs = []
with zipfile.ZipFile(OUTPUT / clean_archive['path']) as archive:
    for name, row in clean_bins.items():
        data = archive.read(APP.name + '/' + name)
        assert preview.sha(data) == row['sha256']
        target = personal_app / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        target.chmod(0o755)
for architecture in ARCHITECTURES:
    for name in ('UltimateLemmix', 'modules/NxlvKit.swiftmodule'):
        target = PERSONAL / architecture / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(OUTPUT / architecture / name, target)
        copied_outputs.append(dict(preview.artifact(target, architecture), compiledAgain=False,
            origin='archive-verified-clean4-frontend' if name == 'UltimateLemmix' else 'verified-core-module'))
sign(personal_app, preview.IDENTIFIER)
checked = preview.verify_app(personal_app, private_files, ARCHITECTURES)
assert before == preview.source_snapshot()
personal_archive = preview.package(personal_app, PERSONAL / preview.archive_name(preview.app_info(private_files)))
personal_evidence = {'schemaVersion': 1, 'app': 'Ultimate Lemmix', 'version': '0.1', 'build': '4',
    'distribution': 'personal-local-preview-only', 'submissionReady': False, 'redistributionCleared': False,
    'architectures': ARCHITECTURES, 'communityLevels': preview.community_count(private_files),
    'sourceFiles': before, 'communityArchiveExtras': preview.community_extras(private_files),
    'coreMode': 'archive-verified-core-and-frontend-reuse', 'reusedCore': preview.verify_core(OUTPUT, ARCHITECTURES),
    'compilerOutputs': copied_outputs, 'frontendReuse': {'compiledAgain': False,
        'archiveSHA256': clean_archive['sha256'],
        'archivedExecutableSHA256': clean_bins['Contents/MacOS/UltimateLemmix']['sha256'],
        'sourceFiles': [row for row in before if row['path'].startswith('Sources/LemmingsLocal/')],
        'commandRecords': [str((OUTPUT / (arch + '-command.json')).relative_to(ROOT)) for arch in ARCHITECTURES],
        'personalBehaviourSelection': 'runtime Info.plist profile flag'},
    'appAudit': checked, 'reviewArchive': personal_archive, 'compiler': evidence['compiler'],
    'sdk': str(SDK), 'gitHead': evidence['gitHead'], 'gitDirty': True, 'sourceSnapshotVerified': True}
(PERSONAL / 'source-inputs.json').write_bytes(preview.encoded({'files': before}))
(PERSONAL / 'build-evidence.json').write_bytes(preview.encoded(personal_evidence))
(PERSONAL / 'final-audit.json').write_bytes(preview.encoded({'profile': 'personal-local-preview-only',
    'sourceSnapshotVerified': True, 'appAudit': checked, 'reviewArchive': personal_archive,
    'communityLevels': preview.community_count(private_files), 'redistributionCleared': False}))
print('PASS personal build4 reused verified frontend/core; exact private profile audit.', flush=True)
