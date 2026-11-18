#!/usr/bin/env python3
"""Package only approved resources for the separate Ultimate Lemmix store build."""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import plistlib
import shutil
import stat
import struct
import subprocess
import tempfile
import unittest
import zipfile

import prepare_lix_font

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = 'store-resources-manifest.json'
DEFAULT_OUTPUT = ROOT / '.build/ultimate-lemmix-app-store-build4-universal/Ultimate Lemmix.app/Contents/Resources'
INTEGRATION = ROOT / '.build/byo-integration'


def encoded(value):
    """Serialise generated records without dates or machine-specific paths."""
    return (json.dumps(value, indent=2, ensure_ascii=False) + '\n').encode()


def sha(data):
    """Return the SHA-256 of resource bytes."""
    return hashlib.sha256(data).hexdigest()


def read_checked(path, row):
    """Reject linked, missing or changed prepared inputs."""
    if path.is_symlink() or not path.is_file():
        raise ValueError(f'The approved resource is missing or linked: {path}')
    data = path.read_bytes()
    if len(data) != row['bytes'] or sha(data) != row['sha256']:
        raise ValueError(f'The approved resource changed: {path}')
    return data


def safe_name(name):
    """Accept one normal relative archive or resource path."""
    path = PurePosixPath(name)
    if (path.is_absolute() or path.as_posix() != name or '..' in path.parts
            or '\\' in name or not name or any(ord(c) < 32 for c in name)):
        raise ValueError('A resource path is unsafe.')
    return name


def prepared(folder):
    """Read the exact prepared inventory rather than copying an input directory."""
    directory = ROOT / '.build/alternative-assets' / folder
    if directory.is_symlink():
        raise ValueError('Prepared resource folders must not be links.')
    manifest = json.loads((directory / 'manifest.json').read_text())
    rows = manifest['files']
    names = {safe_name(row['path']) for row in rows}
    if len(rows) != len(names):
        raise ValueError('The prepared resource inventory contains duplicates.')
    actual = set()
    for path in directory.rglob('*'):
        if path.is_symlink():
            raise ValueError('Prepared resources must not contain links.')
        if path.is_file():
            actual.add(path.relative_to(directory).as_posix())
    if actual != names | {'manifest.json'}:
        raise ValueError('The prepared resource inventory has extra or missing files.')
    files = {row['path']: read_checked(directory / row['path'], row) for row in rows}
    return manifest, files


def convert(arguments):
    """Use the existing image tool for deterministic pixel artwork conversion."""
    binary = shutil.which('magick')
    if not binary:
        raise ValueError('ImageMagick is required to prepare the clean application icon.')
    result = subprocess.run([binary, *map(str, arguments)], capture_output=True)
    if result.returncode:
        raise ValueError('Icon preparation failed: ' + result.stderr.decode(errors='replace')[-1000:])
    return result.stdout


def clean_icon(sheet, metadata):
    """Build a distinct pixel icon from one approved Lix frame and a plain backdrop."""
    walker = next(row for row in metadata['rows'] if row['activity'] == 'walker')['frames'][0]
    with tempfile.TemporaryDirectory(prefix='ultimate-lemmix-icon-') as temporary:
        directory = Path(temporary)
        source = directory / 'sprites.png'
        source.write_bytes(sheet)
        frame = directory / 'frame.png'
        geometry = f"{walker['width']}x{walker['height']}+{walker['x']}+{walker['y']}"
        colour = 'rgb(' + ','.join(map(str, metadata['gridRGBA'][:3])) + ')'
        convert([source, '-crop', geometry, '+repage', '-transparent', colour, '-transparent', '#000000',
                 '-trim', '+repage', '-filter', 'point', '-resize', '640x640', frame])
        png = convert(['-size', '1024x1024', 'xc:#152333', '-fill', '#2d4655',
            '-draw', 'rectangle 64,64 959,959', '-fill', '#152333',
            '-draw', 'rectangle 96,96 927,927', frame, '-gravity', 'center',
            '-compose', 'over', '-composite', '-strip', '-define', 'png:exclude-chunks=date,time', 'png:-'])
        original = directory / 'icon.png'
        original.write_bytes(png)
        chunks = []
        for size, kind in ((16, b'icp4'), (32, b'icp5'), (64, b'icp6'), (128, b'ic07'),
                           (256, b'ic08'), (512, b'ic09'), (1024, b'ic10')):
            image = convert([original, '-filter', 'point', '-resize', f'{size}x{size}',
                             '-strip', '-define', 'png:exclude-chunks=date,time', 'png:-'])
            chunks.append(kind + struct.pack('>I', len(image) + 8) + image)
        body = b''.join(chunks)
        return {'AppIcon.png': png, 'AppIcon.icns': b'icns' + struct.pack('>I', len(body) + 8) + body}


def project_icon():
    """Retain the requested project artwork with its explicit rights-review record."""
    pin_path = ROOT / 'Resources/AlternativeAssets/project-icon-source.json'
    pin = json.loads(pin_path.read_text())
    if pin['cc0'] is not False or pin['redistributionCleared'] is not False or pin['rightsReviewRequired'] is not True:
        raise ValueError('The project icon rights-review scope changed.')
    png = read_checked(ROOT / pin['source'], pin)
    readme = (ROOT / pin['readme']).read_bytes()
    if sha(readme) != pin['readmeSHA256']:
        raise ValueError('The project icon source notice changed.')
    chunks = []
    with tempfile.TemporaryDirectory(prefix='lemmix-project-icon-') as temporary:
        source = Path(temporary) / 'icon.png'
        source.write_bytes(png)
        for size, kind in ((16, b'icp4'), (32, b'icp5'), (64, b'ic07'),
                           (128, b'ic07'), (256, b'ic08'), (512, b'ic09'), (1024, b'ic10')):
            if size == 64:
                kind = b'icp6'
            data = convert([source, '-filter', 'Lanczos', '-resize', f'{size}x{size}!',
                            '-strip', '-define', 'png:exclude-chunks=date,time', 'png:-'])
            chunks.append(kind + struct.pack('>I', len(data) + 8) + data)
    body = b''.join(chunks)
    return {'AppIcon.png': png, 'AppIcon.icns': b'icns' + struct.pack('>I', len(body) + 8) + body,
            'Provenance/project-icon-source.json': pin_path.read_bytes(),
            'Licences/Project-icon-source.md': readme}


def integration_files(allow_missing):
    """Include only the data-only helper archive and its verified notices."""
    archive = INTEGRATION / 'Ultimate-Lemmix-BYO.zip'
    if not archive.exists() and allow_missing:
        return {}
    manifest_path = INTEGRATION / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    data = read_checked(archive, {'bytes': manifest['archiveBytes'], 'sha256': manifest['archiveSHA256']})
    expected = {row['path']: row for row in manifest['files']}
    if set(expected) != {'byo-integration.json', 'README.txt'} or len(manifest['files']) != 2:
        raise ValueError('The integration helper has an unexpected inventory.')
    with zipfile.ZipFile(io.BytesIO(data)) as zipped:
        names = zipped.namelist()
        if len(names) != 3 or set(names) != set(expected) | {'manifest.json'}:
            raise ValueError('The integration helper contains extra or missing members.')
        for name in names:
            info = zipped.getinfo(safe_name(name))
            mode = stat.S_IFMT(info.external_attr >> 16)
            if info.is_dir() or mode not in (0, stat.S_IFREG):
                raise ValueError('The integration helper contains a non-file member.')
        for name, row in expected.items():
            value = zipped.read(name)
            if len(value) != row['bytes'] or sha(value) != row['sha256']:
                raise ValueError('An integration helper member changed.')
        inside = json.loads(zipped.read('manifest.json'))
        if inside['files'] != manifest['files']:
            raise ValueError('The integration helper manifests disagree.')
        contract = zipped.read('byo-integration.json')
        if contract != (ROOT / 'Resources/UltimateLemmix/byo-integration.json').read_bytes():
            raise ValueError('The integration helper does not match its source contract.')
        notice = zipped.read('README.txt')
    return {'Integration/Ultimate-Lemmix-BYO.zip': data,
            'Integration/manifest.json': manifest_path.read_bytes(), 'Integration/README.txt': notice}


def verify_sources():
    """Verify prepared media against pinned originals before either bundle path uses it."""
    for script in ('prepare-lix-alternative.sh', 'prepare-alternative-music.sh'):
        subprocess.run(['zsh', str(ROOT / 'Scripts' / script), '--verify'], check=True)


def privacy_manifest():
    """Accept only the reviewed no-collection declarations and actual API uses."""
    path = ROOT / 'Resources/UltimateLemmix/PrivacyInfo.xcprivacy'
    data = path.read_bytes()
    manifest = plistlib.loads(data)
    expected = {'NSPrivacyTracking': False, 'NSPrivacyCollectedDataTypes': [],
        'NSPrivacyAccessedAPITypes': [
            {'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryFileTimestamp',
             'NSPrivacyAccessedAPITypeReasons': ['C617.1', '3B52.1']},
            {'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategorySystemBootTime',
             'NSPrivacyAccessedAPITypeReasons': ['35F9.1']},
            {'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryUserDefaults',
             'NSPrivacyAccessedAPITypeReasons': ['CA92.1']}]}
    if manifest != expected:
        raise ValueError('The store privacy manifest differs from the reviewed declarations.')
    return data


def collect(allow_missing_integration=False):
    """Build a fresh allowlist with no legacy artwork, samples, campaigns or remixes."""
    verify_sources()
    graphics, art_files = prepared('lix')
    music, music_files = prepared('music')
    pin = json.loads((ROOT / 'Resources/AlternativeAssets/lix-source.json').read_text())
    lock = json.loads((ROOT / 'Resources/AlternativeAssets/music-sources.json').read_text())
    if (graphics['revision'] != pin['revision'] or graphics['licence']['spdx'] != 'CC0-1.0'
            or music['licence'] != 'CC0-1.0' or music['sourceLockSHA256'] != sha(
                (ROOT / 'Resources/AlternativeAssets/music-sources.json').read_bytes())
            or music['source'] != lock['source']):
        raise ValueError('The prepared resources do not match their approved source records.')
    output = {}
    font_files = prepare_lix_font.expected_files()
    prepare_lix_font.verify(files=font_files)
    output.update(font_files)
    output['PrivacyInfo.xcprivacy'] = privacy_manifest()
    for name, data in art_files.items():
        if ((name.startswith('assets/data/images/') and name.endswith('.png'))
                or (name.startswith('assets/images/') and name.endswith(('.png', '.txt')))
                or name in ('sprite-metadata.json', 'licences/copying.txt')):
            output['AlternativeAssets/Lix/' + name] = data
    catalogue = {'schemaVersion': 1, 'tracks': []}
    if [row['sourceTrack'] for row in music['tracks']] != lock['tracks']:
        raise ValueError('The approved music track list changed.')
    for row in music['tracks']:
        track, playback = row['sourceTrack'], row['playback']
        name = safe_name(playback['path'])
        if not name.startswith('Music/Lix/') or not name.endswith('.mp3'):
            raise ValueError('Only the approved Lix MP3 playback files may enter the store bundle.')
        output[name] = read_checked(ROOT / '.build/alternative-assets/music' / name, playback)
        relative = str(PurePosixPath(name).relative_to('Music'))
        catalogue['tracks'].append({'id': track['id'], 'game': 'lix', 'title': track['title'],
            'role': 'menu' if track['id'] == 'lix.menulix' else 'level', 'variants': [{
                'id': track['id'] + '.mp3', 'path': relative, 'port': 'lix',
                'quality': 'lossy-source', 'remix': 'original', 'confidence': 'documented',
                'sourcePath': track['path'], 'credits': track['creator'], 'licence': 'CC0-1.0',
                'evidence': lock['source']['licenceURL']} ]})
    output['Music/catalogue.json'] = encoded(catalogue)
    output['Music/libraries.json'] = encoded({'schemaVersion': 1, 'version': 'ultimate-lemmix-0.1', 'packs': []})
    output['Licences/Lix-copying.txt'] = music_files['Licences/Lix-copying.txt']
    output['Licences/Lix-music-credits.txt'] = music_files['Credits.txt']
    output['Licences/THIRD_PARTY_NOTICES.md'] = (ROOT / 'THIRD_PARTY_NOTICES.md').read_bytes()
    output['Licences/Distribution-scope.txt'] = (
        'Ultimate Lemmix store candidate\n\n'
        'This build includes approved CC0 Lix graphics and music, the separately\n'
        'licensed unchanged DejaVu font, and source-code licence notices.\n'
        'Licences/Lix-font-LICENSE.txt contains the full Bitstream and Arev notice.\n'
        'THIRD_PARTY_NOTICES.md is the shared project notice record.\n'
        'Its legacy asset and beta-package descriptions refer to the preservation edition.\n'
        'They do not describe the resources bundled in this separate store build.\n'
        'The store-resources-manifest.json file records the exact bundled resources.\n'
        'This audit does not establish App Store approval or complete legal clearance.\n'
    ).encode()
    output['OpenStarter/manifest.json'] = encoded({'schemaVersion': 1,
        'id': 'ultimate-lemmix-open-starter-v1', 'title': 'Open Starter',
        'generatorSource': 'Sources/NxlvKit/OpenStarterContent.swift',
        'generatorSourceSHA256': sha((ROOT / 'Sources/NxlvKit/OpenStarterContent.swift').read_bytes()),
        'commercialGameDataIncluded': False, 'generatedAtRuntime': True,
        'levels': [{'index': index, 'title': title} for index, title in enumerate(
            ('First Steps', 'Float to Safety', 'Over the Rise'))]})
    for filename in ('lix-source.json', 'music-sources.json'):
        output['Provenance/' + filename] = (ROOT / 'Resources/AlternativeAssets' / filename).read_bytes()
    output['Provenance/lix-preparation-manifest.json'] = encoded(graphics)
    output['Provenance/music-preparation-manifest.json'] = encoded(music)
    output.update(project_icon())
    from feature_resources import collect as feature_data
    output.update(feature_data())
    output.update(integration_files(allow_missing_integration))
    return output


def media_rights(files):
    """Identify font rights separately from the CC0 graphics and music."""
    licences = [{'scope': 'AlternativeAssets/Lix and Music/Lix', 'licence': 'CC0-1.0'}]
    has_font = 'Fonts/Lix/djvusans.ttf' in files
    if has_font:
        licences.append({'scope': 'Fonts/Lix/djvusans.ttf', 'licence': prepare_lix_font.LICENCE,
                         'notice': 'Licences/Lix-font-LICENSE.txt', 'modified': False})
    if 'Provenance/project-icon-source.json' in files:
        licences.append({'scope': 'Project app icon and derived platform icon catalogues',
                         'licence': 'Rights review required; not CC0',
                         'notice': 'Licences/Project-icon-source.md', 'redistributionCleared': False})
    return {'mediaLicence': 'mixed' if has_font else 'CC0-1.0', 'mediaLicences': licences}


def resource_manifest(files):
    """Record the exact bytes allowed in the store resource directory."""
    return {'schemaVersion': 1, 'kind': 'ultimate-lemmix-store-resources', **media_rights(files),
        'legacyContentIncluded': False, 'integrationIncluded': 'Integration/Ultimate-Lemmix-BYO.zip' in files,
        'files': [{'path': name, 'bytes': len(data), 'sha256': sha(data)} for name, data in sorted(files.items())]}


def build_inputs():
    """Hash only the exact Swift inputs and three reviewed store metadata files."""
    files = sorted([*ROOT.glob('Sources/NxlvKit/*.swift'), *ROOT.glob('Sources/LemmingsLocal/*.swift')])
    files += [ROOT / 'Resources/UltimateLemmix' / name
              for name in ('Info.plist', 'AppStore.entitlements', 'PrivacyInfo.xcprivacy')]
    return [{'path': path.relative_to(ROOT).as_posix(), 'bytes': path.stat().st_size,
             'sha256': sha(path.read_bytes())} for path in files]


def record_build_inputs(output):
    """Keep a pre-build snapshot so later source edits cannot enter the release evidence."""
    output.write_bytes(encoded({'schemaVersion': 1, 'files': build_inputs()}))


def write_build_evidence(output, compiler, sdk, identity, architectures, resource_inventory):
    """Record exact frozen source and resource provenance outside the signed application."""
    rows = build_inputs()
    before = json.loads((output.parent / 'source-inputs.json').read_text())
    if before != {'schemaVersion': 1, 'files': rows}:
        raise ValueError('Build inputs changed after the frozen source snapshot. Do not use this build as release evidence.')
    version = subprocess.run([compiler, '--version'], capture_output=True, text=True, check=True)
    git_head = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    dirty = bool(subprocess.check_output(['git', '-C', str(ROOT), 'status', '--porcelain', '--untracked-files=normal']))
    sdk_settings = json.loads((sdk / 'SDKSettings.json').read_text())
    evidence = {'schemaVersion': 1, 'app': 'Ultimate Lemmix',
        'distribution': 'ad-hoc local validation' if identity == '-' else 'signed local candidate',
        'submissionArchive': False, 'architectures': architectures, 'sdk': str(sdk),
        'sdkVersion': sdk_settings['Version'], 'compiler': (version.stdout + version.stderr).strip(),
        'sparkleIncluded': False, 'legacyResourcesIncluded': False,
        'gitHead': git_head, 'gitDirty': dirty, 'sourceSnapshotVerified': True,
        'sourceFiles': [row for row in rows if row['path'].startswith('Sources/')],
        'metadataFiles': [row for row in rows if row['path'].startswith('Resources/')],
        'resourceManifest': {'path': resource_inventory.relative_to(ROOT).as_posix(),
            'bytes': resource_inventory.stat().st_size, 'sha256': sha(resource_inventory.read_bytes())}}
    output.write_bytes(encoded(evidence))
    return evidence


def verify_tree(output, files):
    """Reject all extra resources, even when they use an otherwise allowed extension."""
    if output.is_symlink():
        raise ValueError('The store resource directory must not be a link.')
    actual = set()
    for path in output.rglob('*'):
        if path.is_symlink():
            raise ValueError('Links are not permitted in the store resources.')
        if path.is_file():
            actual.add(path.relative_to(output).as_posix())
    if actual != set(files) | {MANIFEST}:
        raise ValueError('The store resources contain extra or missing files.')
    expected = resource_manifest(files)
    if json.loads((output / MANIFEST).read_text()) != expected:
        raise ValueError('The store resource manifest is stale or changed.')
    for name, data in files.items():
        if (output / safe_name(name)).read_bytes() != data:
            raise ValueError(f'The store resource differs from its approved source: {name}')
    return expected


def validate_output(output):
    """Restrict writes to generated app resources beneath this checkout's build folder."""
    if output.is_symlink():
        raise ValueError('The store output must not be a link.')
    output = output.resolve()
    if (ROOT / '.build').resolve() not in output.parents or output.parts[-2:] != ('Contents', 'Resources'):
        raise ValueError('Store resources must be inside a generated app under .build.')
    build_name = output.relative_to((ROOT / '.build').resolve()).parts[0].lower()
    if build_name.startswith('ultimate-lemmix-personal-preview') or 'manual-review' in build_name:
        raise ValueError('The clean resource preparer must not write a personal-preview build.')
    if not output.parent.parent.name.endswith('.app'):
        raise ValueError('The store resource output must belong to an application bundle.')
    return output


def prepare(output, files):
    """Stage verified resources before replacing a prior generated resource directory."""
    output = validate_output(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists() and any(output.iterdir()) and not (output / MANIFEST).is_file():
        raise ValueError('Refusing to replace an unrelated resource directory.')
    with tempfile.TemporaryDirectory(prefix='store-resources-', dir=output.parent) as temporary:
        staging = Path(temporary) / 'Resources'
        staging.mkdir()
        for name, data in files.items():
            target = staging / safe_name(name)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        (staging / MANIFEST).write_bytes(encoded(resource_manifest(files)))
        verify_tree(staging, files)
        previous = Path(temporary) / 'previous'
        if output.exists():
            output.rename(previous)
        try:
            staging.rename(output)
        except OSError:
            if previous.exists():
                previous.rename(output)
            raise
    return verify_tree(output, files)


class ResourceSafetyTests(unittest.TestCase):
    """Check that unrelated game resources cannot enter an approved resource bundle."""

    def test_personal_preview_outputs_are_protected(self):
        for folder in ('ultimate-lemmix-personal-preview', 'ultimate-lemmix-personal-preview-build3',
                       'ultimate-lemmix-personal-preview-font-community-checkpoint',
                       'ULTIMATE-LEMMIX-PERSONAL-PREVIEW'):
            with self.subTest(folder=folder), self.assertRaises(ValueError):
                validate_output(ROOT / '.build' / folder / 'Ultimate Lemmix.app/Contents/Resources')

    def test_prohibited_extras_and_changed_audio(self):
        files = {'Music/Lix/example.mp3': b'approved test bytes', 'AppIcon.icns': b'approved clean icon'}
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            approved = output / 'Music/Lix/example.mp3'
            approved.parent.mkdir(parents=True)
            approved.write_bytes(files['Music/Lix/example.mp3'])
            (output / 'AppIcon.icns').write_bytes(files['AppIcon.icns'])
            (output / MANIFEST).write_bytes(encoded(resource_manifest(files)))
            verify_tree(output, files)
            for name in ('Ports/MAIN.DAT', 'MacArtwork/logo.png', 'AmigaArtwork/skills.png',
                         'NeoLemmix/styles/community.png', 'Hints/classic.json',
                         'Sounds/copyrighted.wav', 'Music/Remixes/unapproved.mp3', 'OriginalAppIcon.icns'):
                with self.subTest(name=name):
                    extra = output / name
                    extra.parent.mkdir(parents=True, exist_ok=True)
                    extra.write_bytes(b'unapproved')
                    with self.assertRaises(ValueError):
                        verify_tree(output, files)
                    extra.unlink()
            (output / 'AppIcon.icns').write_bytes(b'legacy icon under the approved name')
            with self.assertRaises(ValueError):
                verify_tree(output, files)
            (output / 'AppIcon.icns').write_bytes(files['AppIcon.icns'])
            approved.write_bytes(b'changed')
            with self.assertRaises(ValueError):
                verify_tree(output, files)

    def test_links_and_unsafe_paths(self):
        for name in ('../Ports/file', '/Ports/file', 'Music//file', 'Music/./file', 'Music\\file'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                safe_name(name)
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            (output / MANIFEST).write_bytes(encoded(resource_manifest({})))
            (output / 'linked.dat').symlink_to(output / MANIFEST)
            with self.assertRaises(ValueError):
                verify_tree(output, {})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument('--audit', action='store_true', help='Check exact approved resource membership and hashes.')
    parser.add_argument('--self-test', action='store_true', help='Run data-independent resource rejection tests.')
    parser.add_argument('--allow-missing-integration', action='store_true', help='Prepare early local resources before the helper exists.')
    args = parser.parse_args()
    if args.self_test:
        result = unittest.TextTestRunner(verbosity=1).run(unittest.defaultTestLoader.loadTestsFromTestCase(ResourceSafetyTests))
        return 0 if result.wasSuccessful() else 1
    files = collect(args.allow_missing_integration)
    manifest = verify_tree(args.output, files) if args.audit else prepare(args.output, files)
    print(f"Verified Ultimate Lemmix resources: {len(files)} files, {sum(r['bytes'] for r in manifest['files']):,} bytes. "
          f"Integration helper: {'included' if manifest['integrationIncluded'] else 'not yet prepared'}.")
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, OSError, KeyError, StopIteration, zipfile.BadZipFile) as error:
        raise SystemExit(f'FAILED: {error}') from error
