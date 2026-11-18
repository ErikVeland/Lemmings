#!/usr/bin/env python3
"""Build a personal Mac preview with original lettering and classified community packs."""
import argparse
import hashlib
import importlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import subprocess
import tempfile
import zipfile

import store_resources

ROOT = store_resources.ROOT
BASE = ROOT / '.build/ultimate-lemmix-app-store-build3-universal'
OUTPUT = ROOT / '.build/ultimate-lemmix-personal-preview-build4'
PROTECTED_OUTPUT = ROOT / '.build/ultimate-lemmix-personal-preview'
RESOURCE_MANIFEST = 'personal-preview-resources.json'
ARTWORK_LOCK = ROOT / 'Resources/AlternativeAssets/personal-preview-artwork.json'
IDENTIFIER = 'academy.glasscode.ultimatelemmix.personal-preview'
FOLDERS = {'lemmings_dos_1991-07-30', 'oh_no_more_lemmings_dos-1991-11-14_2232',
           'holiday_native_1994', 'xmas_dos_XmasLemmingsV1.9', 'xmas_dos_XmasLemmingsV1.9a1'}
ARTWORK_NAME = re.compile(r'(MAIN|GROUND[0-9]+O|VGAGR[0-9]+|VGASPEC[0-9]+)\.DAT', re.I)


def sha(data):
    """Identify exact source bytes without implying redistribution permission."""
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    """Write stable review records without timestamps."""
    return (json.dumps(value, indent=2, ensure_ascii=False) + '\n').encode()


def read_regular(path):
    """Reject linked source files and linked path components beneath the checkout."""
    path = Path(path)
    try:
        relative = path.relative_to(ROOT)
    except ValueError as error:
        raise ValueError('A personal-preview input is outside the checkout.') from error
    if '..' in relative.parts:
        raise ValueError('A personal-preview input escapes its checkout path.')
    for current in (path, *path.parents):
        if current == ROOT:
            break
        if current.is_symlink():
            raise ValueError('Personal-preview inputs must not contain symbolic links.')
    if not path.is_file():
        raise ValueError('A personal-preview input is missing: ' + str(path))
    return path.read_bytes()


def safe_resource(name):
    """Accept only one normal relative resource path."""
    path = PurePosixPath(name)
    if not name or path.is_absolute() or path.as_posix() != name or '\\' in name \
            or any(part in ('', '.', '..') for part in path.parts) \
            or any(ord(value) < 32 for value in name):
        raise ValueError('A personal-preview resource path is unsafe.')
    return name


def artwork_files():
    """Read only pinned original artwork banks, with no campaign or executable files."""
    lock = json.loads(read_regular(ARTWORK_LOCK))
    if lock.get('personalPreviewOnly') is not True or lock.get('redistributionCleared') is not False \
            or lock.get('officialCampaignsIncluded') is not False:
        raise ValueError('The personal artwork scope changed.')
    result = {}
    for row in lock['files']:
        name = safe_resource(row['path'])
        parts = PurePosixPath(name).parts
        if len(parts) != 3 or parts[0] != 'Ports' or parts[1] not in FOLDERS \
                or not ARTWORK_NAME.fullmatch(parts[2]) or name in result:
            raise ValueError('The artwork lock contains a non-artwork resource.')
        data = read_regular(ROOT / row['source'])
        if len(data) != row['bytes'] or sha(data) != row['sha256']:
            raise ValueError('An original artwork source changed: ' + row['source'])
        result[name] = data
    if 'Ports/lemmings_dos_1991-07-30/MAIN.DAT' not in result:
        raise ValueError('The Classic destruction-mask source is missing.')
    result['Provenance/personal-preview-artwork.json'] = encoded(lock)
    return result


def asset_files():
    """Reconstruct personal additions from the separately verified source inventories."""
    font = importlib.import_module('prepare_original_font')
    community = importlib.import_module('prepare_community_levels')
    fonts = font.expected_files()
    font.verify(font.OUTPUT, fonts)
    levels = community.collect()
    community.verify()
    files = {'Fonts/OriginalLemmings/' + safe_resource(name): data for name, data in fonts.items()}
    files.update({'LevelPacks/' + safe_resource(name): data for name, data in levels.items()})
    files.update(artwork_files())
    return files


def resource_files():
    """Keep the approved clean resources and add explicitly personal-only content."""
    clean = store_resources.collect()
    files = dict(clean)
    files[store_resources.MANIFEST] = encoded(store_resources.resource_manifest(clean))
    additions = asset_files()
    if set(files) & set(additions):
        raise ValueError('A personal asset would replace a clean resource.')
    files.update(additions)
    files['PERSONAL-PREVIEW-NOTICE.txt'] = (
        'ULTIMATE LEMMIX — PERSONAL LOCAL MAC PREVIEW ONLY\n\n'
        'This preview includes original game lettering and artwork dependencies,\n'
        'plus classified community level packs from the supplied local corpus.\n'
        'It is not a clean-content App Store build. Original rights remain with\n'
        'their owners. The font and community corpus are not declared cleared\n'
        'for redistribution. Whole official campaign packs are excluded.\n'
        'The copied Ports files contain artwork and masks only, with no game\n'
        'executables, campaign files or original score copied from those ports.\n'
        'Community ZIP bytes remain unchanged, including author extras and\n'
        'records hidden by the runtime official-copy exclusions.\n'
        'Source hashes identify bytes, not rights.\n'
    ).encode()
    return files


def manifest(files):
    """Record the exact private-preview content and its distribution boundary."""
    return {'schemaVersion': 1, 'kind': 'ultimate-lemmix-personal-preview',
            'personalPreviewOnly': True, 'redistributionCleared': False,
            'originalArtworkIncluded': True, 'officialCampaignArchivesIncluded': False,
            'runtimeExcludedRecordsRetainedInMixedArchives': True,
            'files': [{'path': name, 'bytes': len(data), 'sha256': sha(data)}
                      for name, data in sorted(files.items())]}


def community_extras(files):
    """List media and executable-named archive extras without extracting or executing them."""
    media = {'.png', '.jpg', '.jpeg', '.bmp', '.gif', '.webp', '.ogg', '.mp3', '.m4a',
             '.wav', '.mod', '.mid', '.midi', '.it', '.xm', '.s3m'}
    executable = {'.exe', '.com', '.dll', '.so', '.dylib', '.bat', '.cmd', '.ps1', '.js', '.sh', '.py'}
    rows = []
    for name, data in sorted(files.items()):
        if not name.startswith('LevelPacks/') or not name.endswith('.zip'):
            continue
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            for item in archive.infolist():
                suffix = PurePosixPath(item.filename).suffix.lower()
                if suffix in media | executable or any(part.lower().endswith('.app')
                        for part in PurePosixPath(item.filename).parts):
                    rows.append({'archive': name, 'file': item.filename, 'bytes': item.file_size,
                                 'kind': 'media' if suffix in media else 'executable-named',
                                 'extracted': False, 'executed': False})
    return rows


def verify_resources(directory, files):
    """Reject extra files, changed bytes and forged output inventories."""
    if directory.is_symlink():
        raise ValueError('The personal resource directory must not be a link.')
    actual = set()
    for path in directory.rglob('*'):
        if path.is_symlink() or not (path.is_file() or path.is_dir()):
            raise ValueError('The personal resource directory contains a link or unsupported entry.')
        if path.is_file():
            actual.add(path.relative_to(directory).as_posix())
    if actual != set(files) | {RESOURCE_MANIFEST}:
        raise ValueError('The personal resource directory contains extra or missing files.')
    if json.loads((directory / RESOURCE_MANIFEST).read_text()) != manifest(files):
        raise ValueError('The personal resource inventory changed.')
    for name, data in files.items():
        if read_regular(directory / name) != data:
            raise ValueError('A personal resource differs from its verified source: ' + name)
    return {'files': len(files), 'bytes': sum(map(len, files.values())),
            'manifestSHA256': sha((directory / RESOURCE_MANIFEST).read_bytes())}


def validate_output(output):
    """Restrict mutations to the dedicated preview folder and reject linked ancestors."""
    if (output == PROTECTED_OUTPUT or output.parent != ROOT / '.build'
            or (output != OUTPUT and not re.fullmatch(
                r'ultimate-lemmix-personal-preview-build[1-9][0-9]*', output.name))):
        raise ValueError('Use a separate numbered personal-preview build folder. The open build2 folder is protected.')
    for path in (output, *output.parents):
        if path == ROOT:
            break
        if path.is_symlink():
            raise ValueError('The personal preview output must not contain links.')
    return output


def prepare_resources(output, files):
    """Stage exact content and refuse to replace unrelated resources."""
    validate_output(output)
    resources = output / 'Ultimate Lemmix.app/Contents/Resources'
    for path in (resources, *resources.parents):
        if path == ROOT:
            break
        if path.is_symlink():
            raise ValueError('The personal resource output must not contain linked ancestors.')
    if resources.exists() and any(resources.iterdir()):
        inventory = resources / RESOURCE_MANIFEST
        if not inventory.is_file():
            raise ValueError('Refusing to replace unrelated personal-preview resources.')
        previous_manifest = json.loads(read_regular(inventory))
        previous_files = {safe_resource(row['path']): read_regular(resources / safe_resource(row['path']))
                          for row in previous_manifest['files']}
        verify_resources(resources, previous_files)
    resources.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.personal-resources-', dir=resources.parent) as temporary:
        staging = Path(temporary) / 'Resources'
        staging.mkdir()
        for name, data in files.items():
            target = staging / safe_resource(name)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        (staging / RESOURCE_MANIFEST).write_bytes(encoded(manifest(files)))
        verify_resources(staging, files)
        previous = Path(temporary) / 'previous'
        if resources.exists():
            resources.rename(previous)
        try:
            staging.rename(resources)
        except OSError:
            if previous.exists():
                previous.rename(resources)
            raise
    return verify_resources(resources, files)


def community_count(files):
    """Use the adjusted runtime catalogue count rather than the unfiltered corpus."""
    counts = json.loads(files['LevelPacks/level-counts.json'])
    return sum(counts.values())


def app_info(files):
    """Give the personal preview a separate identity and storage container."""
    info = plistlib.loads(read_regular(ROOT / 'Resources/UltimateLemmix/Info.plist'))
    info.update({'CFBundleIdentifier': IDENTIFIER,
                 'CFBundleDisplayName': 'Ultimate Lemmix', 'CFBundleName': 'Ultimate Lemmix',
                 'UltimateLemmixPersonalPreview': True,
                 'UltimateLemmixCommunityLevelCount': community_count(files)})
    return info


def archive_name(info):
    """Use the approved version metadata for the separate personal archive."""
    version, number = info['CFBundleShortVersionString'], info['CFBundleVersion']
    if any(not re.fullmatch(r'[0-9]+(?:\.[0-9]+)*', str(value)) for value in (version, number)):
        raise ValueError('The personal version must contain digits and full stops only.')
    return f'Ultimate-Lemmix-{version}-build{number}-personal-macOS.zip'


def source_snapshot():
    """Identify actual frontend, core, packaging and personal resource policy inputs."""
    paths = [*ROOT.glob('Sources/LemmingsLocal/*.swift'), *ROOT.glob('Sources/NxlvKit/*.swift'),
             *ROOT.glob('Tools/AlternativeAssets/*.py'),
             ROOT / 'Scripts/build-ultimate-lemmix-personal-preview.sh',
             ARTWORK_LOCK, ROOT / 'Resources/AlternativeAssets/community-levels-policy.json',
             ROOT / 'Resources/AlternativeAssets/lix-font-source.json',
             ROOT / 'Resources/AlternativeAssets/lix-font-LICENSE.txt',
             ROOT / 'Resources/UltimateLemmix/Info.plist',
             ROOT / 'Resources/UltimateLemmix/AppStore.entitlements']
    return [{'path': path.relative_to(ROOT).as_posix(), 'bytes': len(data), 'sha256': sha(data)}
            for path in sorted(set(paths)) for data in [read_regular(path)]]


def verify_core(base, architectures):
    """Reuse only the unchanged core that is bound to the prior verified review archive."""
    record = json.loads(read_regular(base / 'build-evidence.json'))
    sources = [row for row in record['sourceFiles'] if row['path'].startswith('Sources/NxlvKit/')]
    current_names = {path.relative_to(ROOT).as_posix() for path in ROOT.glob('Sources/NxlvKit/*.swift')}
    if {row['path'] for row in sources} != current_names:
        raise ValueError('The cached core source inventory differs from current sources.')
    for row in sources:
        data = read_regular(ROOT / row['path'])
        if len(data) != row['bytes'] or sha(data) != row['sha256']:
            raise ValueError('The cached core needs rebuilding after a source change: ' + row['path'])
    archive = base / record['reviewArchive']['path']
    archive_data = read_regular(archive)
    if sha(archive_data) != record['reviewArchive']['sha256']:
        raise ValueError('The original core review archive changed.')
    library = base / 'Ultimate Lemmix.app/Contents/Frameworks/libNxlvKit.dylib'
    library_data = read_regular(library)
    with zipfile.ZipFile(archive) as zipped:
        if zipped.read('Ultimate Lemmix.app/Contents/Frameworks/libNxlvKit.dylib') != library_data:
            raise ValueError('The cached core differs from its verified archive.')
    available = subprocess.check_output(['lipo', '-archs', str(library)], text=True).split()
    if not set(architectures).issubset(available):
        raise ValueError('The cached core is missing a requested architecture.')
    modules = []
    for architecture in architectures:
        path = base / architecture / 'modules/NxlvKit.swiftmodule'
        data = read_regular(path)
        modules.append({'architecture': architecture, 'path': path.relative_to(ROOT).as_posix(),
                        'bytes': len(data), 'sha256': sha(data)})
    return {'sourceFiles': sources, 'librarySHA256': sha(library_data),
            'archiveSHA256': sha(archive_data), 'modules': modules, 'libraryPath': str(library)}


def artifact(path, architecture):
    """Record one architecture-specific compiler output for later audit."""
    data = read_regular(path)
    return {'architecture': architecture, 'path': path.relative_to(ROOT).as_posix(),
            'bytes': len(data), 'sha256': sha(data)}


def verify_artifacts(rows):
    """Reject changed compiler outputs recorded by the completed build."""
    for row in rows:
        data = read_regular(ROOT / safe_resource(row['path']))
        if len(data) != row['bytes'] or sha(data) != row['sha256']:
            raise ValueError('A recorded compiler output changed: ' + row['path'])


def run(arguments, log=None):
    """Run one local build or audit operation without shell interpolation."""
    result = subprocess.run(list(map(str, arguments)), stdout=log, stderr=log)
    if result.returncode:
        raise ValueError('A personal-preview build command failed with exit status ' + str(result.returncode))


def signature(path):
    """Read the actual signing flags and entitlements from the finished app."""
    result = subprocess.run(['codesign', '-d', '--verbose=4', str(path)], capture_output=True,
                            text=True, check=True)
    flags = int(re.search(r'flags=0x([0-9a-fA-F]+)', result.stderr).group(1), 16)
    entitlements = plistlib.loads(subprocess.run(
        ['codesign', '-d', '--entitlements', ':-', str(path)], capture_output=True, check=True).stdout)
    if flags & 0x10000 or not flags & 0x2:
        raise ValueError('The personal preview must be ad hoc without hardened runtime.')
    expected = plistlib.loads(read_regular(ROOT / 'Resources/UltimateLemmix/AppStore.entitlements'))
    if entitlements != expected:
        raise ValueError('The personal preview sandbox entitlements changed.')
    return {'flags': flags, 'hardenedRuntime': False, 'entitlements': entitlements}


def dependency_paths(output):
    """Read dependency rows without treating universal-binary headings as links."""
    paths = [line.strip().split(' (compatibility version ', 1)[0]
             for line in output.splitlines() if line[:1].isspace()]
    if not paths or any(not (path == '@rpath/libNxlvKit.dylib'
            or path.startswith(('/usr/lib/', '/System/Library/'))) for path in paths):
        raise ValueError('A personal-preview binary has an external development dependency.')
    return paths


def verify_app(app, files, architectures):
    """Check profile identity, exact resources, architecture, signatures and dependencies."""
    if plistlib.loads(read_regular(app / 'Contents/Info.plist')) != app_info(files):
        raise ValueError('The personal preview has the wrong identity or content count.')
    resources = verify_resources(app / 'Contents/Resources', files)
    expected = {'Contents/Info.plist', 'Contents/MacOS/UltimateLemmix',
                'Contents/Frameworks/libNxlvKit.dylib', 'Contents/_CodeSignature/CodeResources'}
    for path in app.rglob('*'):
        if path.is_symlink():
            raise ValueError('The personal application contains a symbolic link.')
        if path.is_file():
            name = path.relative_to(app).as_posix()
            if not name.startswith('Contents/Resources/') and name not in expected:
                raise ValueError('The personal application contains an unexpected file: ' + name)
    binaries = {}
    for relative in ('Contents/MacOS/UltimateLemmix', 'Contents/Frameworks/libNxlvKit.dylib'):
        binary = app / relative
        available = subprocess.check_output(['lipo', '-archs', str(binary)], text=True).split()
        if set(available) != set(architectures):
            raise ValueError('A personal-preview binary has the wrong architectures.')
        dependencies = subprocess.check_output(['otool', '-L', str(binary)], text=True)
        dependency_paths(dependencies)
        binaries[relative] = {'architectures': available, 'sha256': sha(read_regular(binary))}
    run(['codesign', '--verify', '--deep', '--strict', app])
    return {'resources': resources, 'binaries': binaries, 'signature': signature(app)}


def package(app, archive):
    """Produce a local review ZIP and compare every archived application file."""
    run(['ditto', '-c', '-k', '--keepParent', app, archive])
    with zipfile.ZipFile(archive) as zipped:
        if zipped.testzip():
            raise ValueError('The personal review archive failed its CRC check.')
        for path in app.rglob('*'):
            if path.is_file() and zipped.read(app.name + '/' + path.relative_to(app).as_posix()) != read_regular(path):
                raise ValueError('A personal review archive file changed.')
    return {'path': archive.name, 'bytes': archive.stat().st_size, 'sha256': sha(read_regular(archive)),
            'crcVerified': True, 'bundleFileHashesVerified': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--resources-only', action='store_true')
    parser.add_argument('--audit', action='store_true')
    parser.add_argument('--rebuild-core', action='store_true',
                        help='Compile an independent core instead of reusing an archive-verified clean build.')
    parser.add_argument('--base-build', type=Path, default=BASE)
    parser.add_argument('--output-dir', type=Path, default=OUTPUT,
                        help='Use a separate numbered personal-preview folder and preserve the open build2 app.')
    parser.add_argument('--architectures', nargs='+', choices=('arm64', 'x86_64'), default=['arm64', 'x86_64'])
    args = parser.parse_args()
    if len(set(args.architectures)) != len(args.architectures):
        raise ValueError('Each personal-preview architecture must occur once.')
    output = validate_output(args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir)
    base = args.base_build.resolve()
    if ROOT / '.build' not in base.parents or base == output:
        raise ValueError('The cached clean build must be a different checkout build folder.')
    files = resource_files()
    app = output / 'Ultimate Lemmix.app'
    record = output / 'build-evidence.json'
    if args.audit:
        evidence = json.loads(read_regular(record))
        if evidence['sourceFiles'] != source_snapshot():
            raise ValueError('Personal-preview source changed after compilation.')
        verify_artifacts(evidence['compilerOutputs'])
        verified = verify_app(app, files, evidence['architectures'])
        if evidence['appAudit'] != verified:
            raise ValueError('The personal-preview application audit changed.')
        archive = output / evidence['reviewArchive']['path']
        if sha(read_regular(archive)) != evidence['reviewArchive']['sha256']:
            raise ValueError('The personal-preview review archive changed.')
        print('PASS personal preview exact source, font, community, artwork and signed app audit.')
        return
    prepare_resources(output, files)
    info = app_info(files)
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info, sort_keys=False))
    if args.resources_only:
        print(f'PASS personal resources: {len(files)} files, {community_count(files)} community levels. No code compiled.')
        return
    core = None if args.rebuild_core else verify_core(base, args.architectures)
    developer = Path(os.environ.get('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer'))
    compiler = developer / 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'
    sdk = Path(os.environ.get('ULTIMATE_LEMMIX_SDKROOT',
               str(developer / 'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'))).resolve()
    if not compiler.is_file() or not sdk.is_dir():
        raise ValueError('The matching full Xcode compiler and SDK are required.')
    before = source_snapshot()
    (output / 'source-inputs.json').write_bytes(encoded({'files': before}))
    cache = output / 'ModuleCache'
    cache.mkdir(exist_ok=True)
    executables = []
    libraries = []
    compiler_outputs = []
    for architecture in args.architectures:
        directory = output / architecture
        directory.mkdir(exist_ok=True)
        executable = directory / 'UltimateLemmix'
        common = [compiler, '-swift-version', '6', '-O', '-sdk', sdk,
                  '-target', architecture + '-apple-macosx12.3']
        if architecture == 'x86_64':
            common += ['-runtime-compatibility-version', 'none']
        if args.rebuild_core:
            module = directory / 'modules'
            module.mkdir(exist_ok=True)
            library = directory / 'libNxlvKit.dylib'
            command = [*common, '-module-cache-path', cache, '-parse-as-library',
                       '-emit-module', '-emit-library', '-module-name', 'NxlvKit',
                       '-emit-module-path', module / 'NxlvKit.swiftmodule',
                       '-Xlinker', '-install_name', '-Xlinker', '@rpath/libNxlvKit.dylib',
                       '-Xlinker', '-w', '-o', library, *sorted(ROOT.glob('Sources/NxlvKit/*.swift'))]
            print('Compiling personal-preview core: ' + architecture, flush=True)
            with (output / (architecture + '-core.log')).open('w') as log:
                run(command, log)
            if source_snapshot() != before:
                raise ValueError('The core source changed during compilation.')
            libraries.append(library)
            compiler_outputs.extend([artifact(library, architecture),
                                     artifact(module / 'NxlvKit.swiftmodule', architecture)])
            library_directory = directory
        else:
            module = base / architecture / 'modules'
            library_directory = Path(core['libraryPath']).parent
        command = [*common, '-DULTIMATE_LEMMIX_STORE', '-module-cache-path', cache,
                    '-I', module, '-L', library_directory, '-lNxlvKit',
                    '-framework', 'AppKit', '-framework', 'AVFoundation', '-framework', 'Metal',
                    '-framework', 'QuartzCore', '-Xlinker', '-rpath', '-Xlinker',
                    '@executable_path/../Frameworks', '-Xlinker', '-w', '-o', executable]
        command += sorted(ROOT.glob('Sources/LemmingsLocal/*.swift'))
        print('Compiling personal-preview frontend: ' + architecture, flush=True)
        with (output / (architecture + '-frontend.log')).open('w') as log:
            run(command, log)
        if source_snapshot() != before:
            raise ValueError('The frontend source changed during compilation.')
        executables.append(executable)
        compiler_outputs.append(artifact(executable, architecture))
    macos = app / 'Contents/MacOS'
    frameworks = app / 'Contents/Frameworks'
    macos.mkdir(exist_ok=True)
    frameworks.mkdir(exist_ok=True)
    if len(executables) == 1:
        shutil.copy2(executables[0], macos / 'UltimateLemmix')
        if args.rebuild_core:
            shutil.copy2(libraries[0], frameworks / 'libNxlvKit.dylib')
        else:
            run(['lipo', '-thin', args.architectures[0], core['libraryPath'],
                 '-output', frameworks / 'libNxlvKit.dylib'])
    else:
        run(['lipo', '-create', *executables, '-output', macos / 'UltimateLemmix'])
        if args.rebuild_core:
            run(['lipo', '-create', *libraries, '-output', frameworks / 'libNxlvKit.dylib'])
        else:
            shutil.copy2(core['libraryPath'], frameworks / 'libNxlvKit.dylib')
    run(['codesign', '--force', '--sign', '-', '--options', '0x0', frameworks / 'libNxlvKit.dylib'])
    run(['codesign', '--force', '--sign', '-', '--options', '0x0', '--entitlements',
         ROOT / 'Resources/UltimateLemmix/AppStore.entitlements', app])
    checked = verify_app(app, files, args.architectures)
    if source_snapshot() != before:
        raise ValueError('The personal-preview source changed before its final audit.')
    archive = package(app, output / archive_name(info))
    evidence = {'schemaVersion': 1, 'app': 'Ultimate Lemmix',
                'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
                'distribution': 'personal-local-preview-only', 'submissionReady': False,
                'redistributionCleared': False, 'architectures': args.architectures,
                'communityLevels': community_count(files), 'sourceFiles': before,
                'communityArchiveExtras': community_extras(files),
                'coreMode': 'fresh' if args.rebuild_core else 'archive-verified-reuse',
                'compilerOutputs': compiler_outputs, 'reusedCore': core,
                'appAudit': checked, 'reviewArchive': archive,
                'compiler': subprocess.check_output([compiler, '--version'], text=True).strip(),
                'sdk': str(sdk), 'gitHead': subprocess.check_output(['git', '-C', ROOT, 'rev-parse', 'HEAD'],
                    text=True).strip(), 'gitDirty': True, 'sourceSnapshotVerified': True}
    record.write_bytes(encoded(evidence))
    print('PASS personal preview built and audited: ' + str(app))
    print('Original artwork and community rights remain unreviewed. No upload or launch occurred.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        raise SystemExit('FAILED: ' + str(error))
