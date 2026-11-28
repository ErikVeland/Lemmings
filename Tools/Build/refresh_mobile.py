#!/usr/bin/env python3
"""Refresh mobile review resources while preserving verified compiled binaries."""
import argparse
import datetime
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Tools/AlternativeAssets'))
import build_mobile
import mobile_resources
from store_resources import encoded, safe_name, sha


def file_record(path):
    """Record one input without accepting symbolic links."""
    if path.is_symlink() or not path.is_file():
        raise ValueError('A refresh input is missing or linked: ' + str(path))
    data = path.read_bytes()
    return {'path': path.relative_to(ROOT).as_posix(), 'bytes': len(data), 'sha256': sha(data)}


def compiled_inputs(application):
    """Enumerate every package and Swift input recorded by the original build."""
    files = [ROOT / 'Package.swift', ROOT / 'Package.resolved']
    for folder in ('NxlvKit', 'LemmingsMobileCore', 'LemmingsMobileUI'):
        files.extend((ROOT / 'Sources' / folder).glob('*.swift'))
    files.extend(application.rglob('*.swift'))
    return sorted((file_record(path) for path in files), key=lambda row: row['path'])


def verify_compiled_sources(evidence, application):
    """Reject changed, missing or newly added compiled inputs before binary reuse."""
    expected = sorted((row for row in evidence['sourceFiles']
                       if row['path'].endswith('.swift')
                       or row['path'] in ('Package.swift', 'Package.resolved')),
                      key=lambda row: row['path'])
    current = compiled_inputs(application)
    if current != expected:
        raise ValueError('Compiled Swift or package inputs changed. A fresh mobile compilation is required.')
    return current


def verify_binary(binary, expected):
    """Bind a reused executable to its recorded compilation evidence."""
    if binary.is_symlink() or not binary.is_file() or sha(binary.read_bytes()) != expected:
        raise ValueError('The original compiled mobile binary changed.')


def normalise_project(data, current, previous):
    """Remove only the build number and four new data-folder references."""
    pattern = rb'(CURRENT_PROJECT_VERSION\s*=\s*)' + re.escape(current.encode()) + rb'(\s*;)'
    data = re.sub(pattern, lambda match: match[1] + previous.encode() + match[2], data)
    for index, folder in enumerate(('Progression', 'Hints', 'Trolley', 'GameCenter'), 0x38):
        file_id, build_id = (f'{prefix}{index:023X}'.encode() for prefix in ('A', 'B'))
        build_line = build_id + b' = {isa = PBXBuildFile; fileRef = ' + file_id + b'; };'
        file_line = (file_id + b' = {isa = PBXFileReference; lastKnownFileType = folder; name = "'
                     + folder.encode() + b'"; path = "../../.build/ultimate-lemmix-mobile-resources/'
                     + folder.encode() + b'"; sourceTree = SOURCE_ROOT; };')
        for line in (build_line, file_line):
            data = re.sub(rb'^[ \t]*' + re.escape(line) + rb'\r?\n', b'', data, flags=re.MULTILINE)
        lines = data.splitlines(keepends=True)
        for line_index, line in enumerate(lines):
            if b'isa = PBXResourcesBuildPhase;' in line:
                lines[line_index] = line.replace(build_id + b',', b'')
            elif b'isa = PBXGroup;' in line and b'name = "Approved Content";' in line:
                lines[line_index] = line.replace(file_id + b',', b'')
        data = b''.join(lines)
    return data


def updated_info(previous, source, icons):
    """Keep binary SDK metadata and replace source metadata and compiled icon keys."""
    variables = {'EXECUTABLE_NAME': previous.get('CFBundleExecutable'),
                 'PRODUCT_BUNDLE_IDENTIFIER': previous.get('CFBundleIdentifier'),
                 'PRODUCT_NAME': previous.get('CFBundleName')}

    def expand(value):
        if isinstance(value, str):
            for key, replacement in variables.items():
                if replacement is not None:
                    value = value.replace('$(' + key + ')', replacement)
            if '$(' in value:
                raise ValueError('The refreshed Info.plist contains an unresolved build variable.')
        elif isinstance(value, list):
            return [expand(item) for item in value]
        elif isinstance(value, dict):
            return {key: expand(item) for key, item in value.items()}
        return value

    retained = {key: value for key, value in previous.items()
                if not key.startswith('CFBundleIcon') and key != 'TVTopShelfImage'}
    return {**retained, **expand(source), **icons}


def verify_configuration(evidence, application, current_version, previous_version):
    """Allow only a build-number change in build settings and source Info.plist."""
    prefix = application.relative_to(ROOT).as_posix() + '/'
    for row in evidence['sourceFiles']:
        name = row['path']
        if not name.startswith(prefix):
            continue
        path = ROOT / safe_name(name)
        if path.suffix not in ('.pbxproj', '.xcscheme') and path.name != 'Contents.json' and path != application / 'Info.plist':
            continue
        if path.is_symlink() or not path.is_file():
            raise ValueError('An original mobile project input is missing or linked.')
        data = path.read_bytes()
        if path.suffix == '.pbxproj':
            data = normalise_project(data, current_version, previous_version)
        elif path == application / 'Info.plist':
            data = re.sub(rb'(<key>CFBundleVersion</key>\s*<string>)[^<]*(</string>)',
                          lambda match: match[1] + previous_version.encode() + match[2], data)
        if sha(data) != row['sha256']:
            raise ValueError('Mobile compiler settings, asset identifiers or source metadata changed: ' + name)


def origin_product(source, row, platform):
    """Verify the original binary and Info.plist against the pinned review archive."""
    app = source / safe_name(row['appPath'])
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if info['CFBundleIdentifier'] != 'academy.glasscode.ultimatelemmix.' + platform:
        raise ValueError('The original binary belongs to another application.')
    binary = app / safe_name(info['CFBundleExecutable'])
    verify_binary(binary, row['binary']['executableSHA256'])
    archive = source / safe_name(row['reviewArchive']['path'])
    if archive.is_symlink() or sha(archive.read_bytes()) != row['reviewArchive']['sha256']:
        raise ValueError('The original review archive changed.')
    prefix = ('Payload/' if row['kind'] == 'device' else '') + app.name + '/'
    with zipfile.ZipFile(archive) as recorded:
        if recorded.read(prefix + 'Info.plist') != (app / 'Info.plist').read_bytes():
            raise ValueError('The original application metadata differs from its pinned review archive.')
        if sha(recorded.read(prefix + info['CFBundleExecutable'])) != row['binary']['executableSHA256']:
            raise ValueError('The original archive binary differs from its compilation evidence.')
    return app, info


def refresh_inputs(application):
    """Bind the normal mobile source closure and this separate refresh tool."""
    return build_mobile.source_inputs(application), file_record(Path(__file__).resolve())


def compile_icons(application, app, platform, kind, source_info, environment, stage):
    """Compile fresh icons with the same Xcode and SDK family as the original binary."""
    sdk = ('iphoneos' if platform == 'ios' else 'appletvos') if kind == 'device' else (
        'iphonesimulator' if platform == 'ios' else 'appletvsimulator')
    developer = Path(environment['DEVELOPER_DIR'])
    partial = stage / (kind + '-icon-info.plist')
    log = stage / (kind + '-icons.log')
    command = [developer / 'usr/bin/actool', application / 'Assets.xcassets', '--compile', app,
               '--output-format', 'human-readable-text', '--notices', '--warnings',
               '--output-partial-info-plist', partial, '--app-icon', 'AppIcon', '--compress-pngs',
               '--enable-on-demand-resources', 'YES', '--development-region', 'en',
               '--minimum-deployment-target', source_info['MinimumOSVersion'], '--platform', sdk,
               '--bundle-identifier', 'academy.glasscode.ultimatelemmix.' + platform]
    for device in (('iphone', 'ipad') if platform == 'ios' else ('tv',)):
        command += ['--target-device', device]
    with log.open('w') as output:
        result = subprocess.run(list(map(str, command)), env=environment, stdout=output, stderr=output)
    if result.returncode:
        raise ValueError('The fresh asset catalogue failed. Read ' + str(log))
    if not (app / 'Assets.car').is_file():
        raise ValueError('The fresh asset catalogue produced no Assets.car.')
    return plistlib.loads(partial.read_bytes()), {'log': log.name, 'partialInfo': partial.name,
        'assetsSHA256': sha((app / 'Assets.car').read_bytes()), 'swiftSymbolsGenerated': False,
        'compiled': True, 'command': list(map(str, command))}


def generated_files(app, resources):
    """Pin generated metadata and icon files outside the approved resource manifest."""
    managed = set(resources) | {mobile_resources.MANIFEST}
    rows = []
    for path in sorted(app.rglob('*')):
        if path.is_symlink():
            raise ValueError('The refreshed application contains a linked generated file.')
        if path.is_file():
            name = path.relative_to(app).as_posix()
            if name not in managed:
                payload = path.read_bytes()
                rows.append({'path': name, 'bytes': len(payload), 'sha256': sha(payload)})
    return rows


def verify_finished(build, evidence, platform, files, application):
    """Audit refreshed resources, reused binaries, archives and the current source closure."""
    inputs, helper = refresh_inputs(application)
    if evidence['sourceFiles'] != inputs or evidence['refreshTool'] != helper:
        raise ValueError('Mobile refresh inputs changed after packaging.')
    for row in evidence['products']:
        app = build / safe_name(row['appPath'])
        if mobile_resources.audit_app(app, platform, files) != row['resources']:
            raise ValueError('The refreshed mobile resources changed.')
        if build_mobile.audit_binary(app) != row['binary']:
            raise ValueError('A refreshed mobile executable changed.')
        if generated_files(app, files) != row['generatedFiles']:
            raise ValueError('Refreshed mobile metadata or generated icon files changed.')
        if sha((app / 'Assets.car').read_bytes()) != row['assetCatalogue']['assetsSHA256']:
            raise ValueError('A freshly compiled mobile icon catalogue changed.')
        if sha((build / row['reviewArchive']['path']).read_bytes()) != row['reviewArchive']['sha256']:
            raise ValueError('A refreshed mobile archive changed.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=('ios', 'tvos'))
    parser.add_argument('--from-build', type=Path)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--audit', action='store_true')
    args = parser.parse_args()
    platform = args.platform
    target = 'UltimateLemmixIOS' if platform == 'ios' else 'UltimateLemmixTVOS'
    application = ROOT / 'Apps' / target
    source = build_mobile.output_directory(args.from_build or ROOT / f'.build/ultimate-lemmix-{platform}-build3')
    build = build_mobile.output_directory(args.output_dir or build_mobile.default_output(platform, application))
    if source == build or source in build.parents or build in source.parents:
        raise ValueError('A mobile refresh must use a separate output from its original compilation.')
    evidence_path = source / 'build-evidence.json'
    origin_bytes = evidence_path.read_bytes()
    original = json.loads(origin_bytes)
    if original.get('platform') != platform or not original.get('sourceSnapshotVerified'):
        raise ValueError('The original mobile compilation has no verified matching source evidence.')
    compiled = verify_compiled_sources(original, application)
    if {row['kind'] for row in original['products']} != {'device', 'simulator'}:
        raise ValueError('Both original device and simulator compilation products are required.')
    source_info = plistlib.loads((application / 'Info.plist').read_bytes())
    previous = [origin_product(source, row, platform) for row in original['products']]
    old_version = previous[0][1]['CFBundleVersion']
    if source_info['CFBundleVersion'] == old_version:
        raise ValueError('A resource refresh requires a separate application build number.')
    verify_configuration(original, application, source_info['CFBundleVersion'], old_version)
    environment = os.environ.copy()
    environment.setdefault('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer')
    environment['LEMMINGS_TEST_AUDIO'] = 'muted'
    environment['LEMMINGS_TEST_WINDOWS'] = 'offscreen'
    xcode = subprocess.check_output([str(Path(environment['DEVELOPER_DIR']) / 'usr/bin/xcodebuild'), '-version'],
                                    env=environment, text=True).strip()
    if xcode != original['xcode']:
        raise ValueError('Use the original Xcode version for this binary-bound resource refresh.')
    for row, (_, info) in zip(original['products'], previous):
        sdk_version = subprocess.check_output(['xcrun', '--sdk', row['sdk'], '--show-sdk-version'],
                                              env=environment, text=True).strip()
        if info['DTSDKName'] != row['sdk'] + sdk_version:
            raise ValueError('The current SDK differs from the original compiled binary SDK.')
    files = mobile_resources.resources()
    mobile_resources.icons(files, write=False)
    if args.audit:
        evidence = json.loads((build / 'build-evidence.json').read_bytes())
        if evidence['binaryOrigin']['evidenceSHA256'] != sha(origin_bytes):
            raise ValueError('The original compilation evidence changed.')
        verify_finished(build, evidence, platform, files, application)
        print('PASS refreshed ' + platform + ' resources, icons, source-bound binaries and review archives.')
        return
    if build.exists() and any(build.iterdir()):
        raise ValueError('The mobile refresh output already contains files. Preserve it and choose an empty output.')
    before, helper = refresh_inputs(application)
    products = []
    with tempfile.TemporaryDirectory(prefix='.mobile-refresh-', dir=build.parent) as temporary:
        stage = Path(temporary) / build.name
        stage.mkdir()
        for row, (old_app, old_info) in zip(original['products'], previous):
            kind = row['kind']
            relative_app = (Path(target + '.xcarchive/Products/Applications/UltimateLemmix.app')
                            if kind == 'device' else Path('simulator/UltimateLemmix.app'))
            app = stage / relative_app
            app.mkdir(parents=True)
            executable = old_info['CFBundleExecutable']
            shutil.copy2(old_app / executable, app / executable)
            for name, payload in files.items():
                destination = app / safe_name(name)
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(payload)
            (app / mobile_resources.MANIFEST).write_bytes(encoded(mobile_resources.inventory(files)))
            icon_info, icon_record = compile_icons(application, app, platform, kind, source_info, environment, stage)
            info = updated_info(old_info, source_info, icon_info)
            (app / 'Info.plist').write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_BINARY))
            (app / 'PkgInfo').write_bytes(b'APPL????')
            verify_binary(app / executable, row['binary']['executableSHA256'])
            resources = mobile_resources.audit_app(app, platform, files)
            binary = build_mobile.audit_binary(app)
            if binary != row['binary']:
                raise ValueError('The refreshed executable differs from its verified compilation origin.')
            if kind == 'device':
                archive_info = plistlib.loads((source / (target + '.xcarchive/Info.plist')).read_bytes())
                archive_info['CreationDate'] = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
                archive_info['ApplicationProperties']['CFBundleVersion'] = info['CFBundleVersion']
                archive_info['ApplicationProperties']['CFBundleShortVersionString'] = info['CFBundleShortVersionString']
                (stage / (target + '.xcarchive/Info.plist')).write_bytes(plistlib.dumps(archive_info))
            suffix = 'unsigned.ipa' if kind == 'device' else 'simulator.zip'
            destination = stage / build_mobile.archive_name(platform, app, suffix)
            archive = build_mobile.review_archive(app, destination, payload=kind == 'device')
            product = {'kind': kind, 'sdk': row['sdk'], 'appPath': relative_app.as_posix(),
                       'resources': resources, 'binary': binary, 'reviewArchive': archive,
                       'generatedFiles': generated_files(app, files),
                       'binaryReused': True, 'swiftRecompiled': False, 'assetCatalogue': icon_record,
                       'originAppPath': row['appPath']}
            products.append(product)
            (stage / (kind + '-evidence.json')).write_bytes(encoded(product))
            print('PASS ' + platform + ' ' + kind + ': verified binary reused, fresh icons and resources.', flush=True)
        evidence = {'schemaVersion': 1, 'app': 'Ultimate Lemmix', 'platform': platform,
                    'distribution': 'unsigned local review', 'submissionReady': False, 'uploaded': False,
                    'buildMethod': 'resource-and-icon-refresh-with-source-verified-binary-reuse',
                    'swiftRecompiled': False, 'assetCataloguesCompiled': True,
                    'runtimeTested': False, 'deviceTested': False, 'debugSymbolsIncluded': False,
                    'sourceSnapshotVerified': True, 'sourceFiles': before, 'refreshTool': helper,
                    'compiledSourceInputs': compiled, 'xcode': xcode, 'products': products,
                    'binaryOrigin': {'build': old_version, 'directory': source.relative_to(ROOT).as_posix(),
                                     'evidenceSHA256': sha(origin_bytes)}}
        if refresh_inputs(application) != (before, helper) or evidence_path.read_bytes() != origin_bytes:
            raise ValueError('Mobile refresh inputs changed during asset compilation.')
        if mobile_resources.resources() != files:
            raise ValueError('Approved mobile resources changed during packaging.')
        (stage / 'source-inputs.json').write_bytes(encoded({'schemaVersion': 1, 'files': before}))
        (stage / 'build-evidence.json').write_bytes(encoded(evidence))
        verify_finished(stage, evidence, platform, files, application)
        if build.exists():
            build.rmdir()
        stage.rename(build)
    print('PASS independent ' + platform + ' resource refresh. Swift binaries retain build' + old_version + ' compilation evidence.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        raise SystemExit('FAILED: ' + str(error)) from error
