#!/usr/bin/env python3
"""Build independent unsigned iOS and tvOS Ultimate Lemmix review artefacts."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import zipfile

import mobile_resources
from store_resources import ROOT, encoded, sha


def output_directory(path):
    """Keep each mobile build inside an unlinked checkout build folder."""
    path = path if path.is_absolute() else ROOT / path
    try:
        relative = path.relative_to(ROOT / '.build')
    except ValueError as error:
        raise ValueError('The mobile output must be beneath this checkout build folder.') from error
    if not relative.parts or '..' in relative.parts:
        raise ValueError('The mobile output must use its own build folder.')
    if (relative.parts[0].lower().startswith(('ultimate-lemmix-personal-preview', 'ultimate-lemmix-app-store'))
            or 'manual-review' in relative.parts[0].lower()):
        raise ValueError('A mobile build must not write a personal-preview or clean Mac build folder.')
    for current in (path, *path.parents):
        if current == ROOT:
            break
        if current.is_symlink():
            raise ValueError('The mobile output must not contain linked ancestors.')
    return path


def default_output(platform, source):
    """Choose a numbered output without replacing historical default builds."""
    info = plistlib.loads((source / 'Info.plist').read_bytes())
    number = str(info['CFBundleVersion'])
    if not number or any(character not in '0123456789.' for character in number):
        raise ValueError('The mobile build number must contain digits and full stops only.')
    return ROOT / '.build' / f'ultimate-lemmix-{platform}-build{number}'


def archive_name(platform, app, suffix):
    """Use the built application version instead of a fixed archive build number."""
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    version = info['CFBundleShortVersionString']
    number = info['CFBundleVersion']
    if any(not str(value) or any(character not in '0123456789.' for character in str(value))
           for value in (version, number)):
        raise ValueError('The mobile version must contain digits and full stops only.')
    return f'Ultimate-Lemmix-{platform}-{version}-build{number}-{suffix}'


def run(arguments, environment, log=None):
    """Run one explicit build operation and retain its complete diagnostics."""
    result = subprocess.run(list(map(str, arguments)), env=environment, stdout=log, stderr=log)
    if result.returncode:
        raise ValueError('The build command failed with exit status ' + str(result.returncode))


def source_inputs(app):
    """Identify every package, application, metadata and icon input before compilation."""
    files = [ROOT / 'Package.swift', ROOT / 'Package.resolved']
    for folder in ('NxlvKit', 'LemmingsMobileCore', 'LemmingsMobileUI'):
        files.extend((ROOT / 'Sources' / folder).glob('*.swift'))
    files.extend((ROOT / 'Tools/AlternativeAssets').glob('*.py'))
    files.extend((ROOT / 'Resources/AlternativeAssets').glob('*.json'))
    files.extend(path for path in (ROOT / 'Resources/UltimateLemmix').iterdir() if path.is_file())
    files.extend(ROOT / 'Scripts' / name for name in (
        'build-ultimate-lemmix-ios.sh', 'build-ultimate-lemmix-tvos.sh',
        'check-ultimate-lemmix-mobile-resources.sh'))
    files.extend(path for path in app.rglob('*') if path.is_file() and not path.is_symlink()
                 and 'xcuserdata' not in path.parts and (path.name == 'Package.resolved'
                 or path.suffix in ('.swift', '.plist', '.xcprivacy', '.pbxproj', '.xcscheme', '.json', '.png'))
                 and path.name != 'IDEWorkspaceChecks.plist')
    return [{'path': path.relative_to(ROOT).as_posix(), 'bytes': path.stat().st_size,
             'sha256': sha(path.read_bytes())} for path in sorted(files)]


def review_archive(app, destination, payload):
    """Package an unsigned local review copy and verify every archived file hash."""
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(app.rglob('*')):
            if path.is_symlink():
                raise ValueError('The review app contains a link.')
            if path.is_file():
                archive.write(path, (Path('Payload') / app.name / path.relative_to(app)).as_posix()
                              if payload else (Path(app.name) / path.relative_to(app)).as_posix())
    with zipfile.ZipFile(destination) as archive:
        if archive.testzip():
            raise ValueError('The review archive failed its CRC check.')
        for path in app.rglob('*'):
            if path.is_file():
                name = (Path('Payload') / app.name / path.relative_to(app)).as_posix() if payload else (
                    Path(app.name) / path.relative_to(app)).as_posix()
                if archive.read(name) != path.read_bytes():
                    raise ValueError('An archived application file changed: ' + name)
    return {'path': destination.name, 'bytes': destination.stat().st_size,
            'sha256': sha(destination.read_bytes()), 'crcVerified': True, 'fileHashesVerified': True,
            'installableWithoutSigning': False if payload else None}


def audit_binary(app):
    """Keep the macOS updater and original resource paths outside both mobile binaries."""
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    executable = app / info['CFBundleExecutable']
    dependencies = subprocess.check_output(['otool', '-L', str(executable)], text=True)
    if 'Sparkle' in dependencies:
        raise ValueError('A mobile application linked the macOS updater.')
    architectures = subprocess.check_output(['lipo', '-archs', str(executable)], text=True).strip().split()
    return {'architectures': architectures, 'executableSHA256': sha(executable.read_bytes()),
            'sparkleIncluded': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=('ios', 'tvos'))
    parser.add_argument('--resources-only', action='store_true')
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--device-only', action='store_true')
    group.add_argument('--simulator-only', action='store_true')
    parser.add_argument('--audit', action='store_true')
    parser.add_argument('--output-dir', type=Path,
                        help='Use a separate checkout build folder and preserve earlier review artefacts.')
    args = parser.parse_args()
    environment = os.environ.copy()
    environment.setdefault('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer')
    environment['LEMMINGS_TEST_AUDIO'] = 'muted'
    environment['LEMMINGS_TEST_WINDOWS'] = 'offscreen'
    platform = args.platform
    target = 'UltimateLemmixIOS' if platform == 'ios' else 'UltimateLemmixTVOS'
    app_source = ROOT / 'Apps' / target
    build = output_directory(args.output_dir or default_output(platform, app_source))
    build.mkdir(parents=True, exist_ok=True)
    environment['CLANG_MODULE_CACHE_PATH'] = str(build / 'ModuleCache')
    environment['SWIFTPM_MODULECACHE_OVERRIDE'] = str(build / 'SwiftModuleCache')
    environment['SWIFT_MODULECACHE_PATH'] = str(build / 'SwiftModuleCache')
    environment['XDG_CACHE_HOME'] = str(build / 'Caches')
    environment['CFFIXED_USER_HOME'] = str(build / 'ToolHome')
    (build / 'ToolHome').mkdir(exist_ok=True)
    resource_files = mobile_resources.resources()
    if not args.audit and (args.resources_only or not mobile_resources.OUTPUT.exists()):
        mobile_resources.prepare(resource_files)
    mobile_resources.verify(mobile_resources.OUTPUT, resource_files)
    mobile_resources.icons(resource_files, write=not args.audit)
    if args.resources_only:
        print('PASS mobile resources and platform icon catalogues. No application was compiled.')
        return
    packages = build / 'SourcePackages'
    if not args.audit and not packages.exists():
        cached = ROOT / '.build/ios-packages'
        if cached.is_dir() and not cached.is_symlink():
            shutil.copytree(cached, packages, symlinks=True)
    record = build / 'build-evidence.json'
    before = source_inputs(app_source)
    if args.audit:
        evidence = json.loads(record.read_text())
        if evidence['sourceFiles'] != before:
            raise ValueError('The mobile source differs from the completed build evidence.')
        for row in evidence['products']:
            app = build / row['appPath']
            if row['resources'] != mobile_resources.audit_app(app, platform, resource_files):
                raise ValueError('The mobile bundle resource audit changed.')
            if row['binary'] != audit_binary(app):
                raise ValueError('The mobile application binary changed.')
            archive = build / row['reviewArchive']['path']
            if sha(archive.read_bytes()) != row['reviewArchive']['sha256']:
                raise ValueError('The mobile review archive changed.')
        print('PASS mobile sources, platform identities, exact resources and review archives: ' + platform)
        return
    (build / 'source-inputs.json').write_bytes(encoded({'schemaVersion': 1, 'files': before}))
    developer = Path(environment['DEVELOPER_DIR'])
    xcodebuild = developer / 'usr/bin/xcodebuild'
    if not xcodebuild.is_file():
        raise ValueError('A full Xcode installation is required for the mobile build.')
    shared = ['-project', app_source / (target + '.xcodeproj'), '-scheme', target,
              '-configuration', 'Release', '-derivedDataPath', build / 'derived-data',
              '-clonedSourcePackagesDirPath', packages, '-skipPackageUpdates',
              '-packageCachePath', build / 'PackageCache',
              '-disableAutomaticPackageResolution', '-jobs', '2',
              'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO',
              'COMPILER_INDEX_STORE_ENABLE=NO']
    products = []
    for kind in ('device', 'simulator'):
        if (kind == 'device' and args.simulator_only) or (kind == 'simulator' and args.device_only):
            continue
        sdk = ('iphoneos' if platform == 'ios' else 'appletvos') if kind == 'device' else (
            'iphonesimulator' if platform == 'ios' else 'appletvsimulator')
        destination = 'generic/platform=' + ('iOS' if platform == 'ios' else 'tvOS') + (
            ' Simulator' if kind == 'simulator' else '')
        if kind == 'device':
            archive_path = build / (target + '.xcarchive')
            command = [xcodebuild, *shared, '-sdk', sdk, '-destination', destination,
                       '-archivePath', archive_path, 'ARCHS=arm64', 'archive']
            app = archive_path / 'Products/Applications/UltimateLemmix.app'
        else:
            command = [xcodebuild, *shared, '-sdk', sdk, '-destination', destination,
                       'ARCHS=arm64', 'ONLY_ACTIVE_ARCH=YES', 'build']
            app = build / 'derived-data/Build/Products' / ('Release-' + sdk) / 'UltimateLemmix.app'
        log_path = build / (kind + '-build.log')
        print('Building unsigned ' + platform + ' ' + kind + ' review artefact.', flush=True)
        with log_path.open('w') as log:
            run(command, environment, log)
        if source_inputs(app_source) != before:
            raise ValueError('Mobile build inputs changed during compilation. Rebuild after the source freeze.')
        checked = mobile_resources.audit_app(app, platform, resource_files)
        binary = audit_binary(app)
        suffix = 'unsigned.ipa' if kind == 'device' else 'simulator.zip'
        packaged = build / archive_name(platform, app, suffix)
        archive = review_archive(app, packaged, payload=kind == 'device')
        products.append({'kind': kind, 'sdk': sdk, 'appPath': app.relative_to(build).as_posix(),
                         'resources': checked, 'binary': binary, 'reviewArchive': archive,
                         'buildLog': log_path.name})
        (build / (kind + '-evidence.json')).write_bytes(encoded(products[-1]))
        print('PASS unsigned ' + kind + ' bundle and review archive: ' + str(packaged), flush=True)
    version = subprocess.check_output([str(xcodebuild), '-version'], env=environment, text=True).strip()
    head = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    dirty = bool(subprocess.check_output(['git', '-C', str(ROOT), 'status', '--porcelain']))
    evidence = {'schemaVersion': 1, 'app': 'Ultimate Lemmix', 'platform': platform,
                'distribution': 'unsigned local review', 'submissionReady': False,
                'uploaded': False, 'xcode': version, 'gitHead': head, 'gitDirty': dirty,
                'sourceSnapshotVerified': True, 'sourceFiles': before, 'products': products}
    record.write_bytes(encoded(evidence))
    print('PASS independent Ultimate Lemmix ' + platform + ' build evidence: ' + str(record))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as error:
        raise SystemExit('FAILED: ' + str(error)) from error
