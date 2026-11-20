#!/usr/bin/env python3
"""Prepare and audit the shared, allowlisted Ultimate Lemmix mobile resources."""
import argparse
import io
import json
from pathlib import Path
import plistlib
import tempfile
import zipfile

from byo_bundle import manifest_for, verify_archive, write_member
from store_resources import ROOT, collect, convert, encoded, media_rights, safe_name, sha


OUTPUT = ROOT / '.build/ultimate-lemmix-mobile-resources'
MANIFEST = 'mobile-resources-manifest.json'
FOLDERS = ('AlternativeAssets', 'Music', 'Licences', 'Provenance', 'Integration', 'OpenStarter',
           'Fonts', 'Progression', 'Hints', 'Trolley', 'GameCenter')


def resources():
    """Use the established source verifiers and remove Mac-only icon formats."""
    selected = {name: value for name, value in collect().items()
                if name not in ('AppIcon.icns', 'AppIcon.png')}
    selected.update(mobile_helper(selected['Integration/Ultimate-Lemmix-BYO.zip']))
    return selected


def mobile_helper(parent_archive):
    """Restrict the verified data-only helper to the implemented mobile Classic routes."""
    with zipfile.ZipFile(io.BytesIO(parent_archive)) as archive:
        contract = json.loads(archive.read('byo-integration.json'))
    contract['id'] = 'ultimate-lemmix-mobile-classic-byo-v1'
    contract['platforms'] = ['ios', 'tvos']
    contract['games'] = [game for game in contract['games'] if game['id'] == 'classic']
    contract['sourceSelection'] = (
        'iOS: choose a folder through Files. tvOS: transfer a Classic folder from a browser on the same local network.')
    contract['installation'] = (
        'The app copies and validates the files before replacing an import. iOS uses application support. '
        'tvOS uses caches that the system can purge. The source files stay on their original device.')
    contract['integrity']['networkTransfers'] = (
        'iOS uses the system folder picker. tvOS accepts bounded chunks through an explicit temporary local-browser session.')
    contract['networkAccessScope'] = 'This data-only helper performs no network requests. The app owns its import routes.'
    contract['applicationImportRoutes'] = {'ios': 'system-folder-picker',
        'tvos': 'temporary-local-browser-upload-with-session-token'}
    contract['engineLimit'] = 'These mobile editions import Classic DOS data only. Lemmings 2 and 3 are not enabled.'
    if (len(contract['games']) != 1 or contract['games'][0]['id'] != 'classic'
            or contract['containsCommercialAssets'] or contract['containsExecutableCode']
            or contract['networkAccess'] or contract['downloads']):
        raise ValueError('The mobile helper must remain asset-free and Classic-only.')
    readme = b'''Ultimate Lemmix: iPhone, iPad and Apple TV Classic import

This helper contains a JSON contract and this guide. It contains no game data
or executable code. It performs no downloads and grants no rights to game content.
The included starter puzzles need no original game files.

iPhone and iPad
1. Put your Classic DOS game folder in Files.
2. Open Ultimate Lemmix.
3. Choose IMPORT CLASSIC.
4. Select the folder containing MAIN.DAT.

Apple TV
1. Connect the TV and your source device to the same local network.
2. Open Ultimate Lemmix on the TV.
3. Choose IMPORT CLASSIC.
4. Open the displayed private address in a browser on your source device.
5. Select your Classic DOS folder.
6. Choose Import to TV.
7. Keep both import pages open until validation finishes.

The app checks limits, rejects links and validates staged files before replacement.
A failed replacement keeps the previous import. Your source files stay in place.
Apple TV stores imported data and checkpoints in caches. The system can purge them.
Keep your original files so you can import them again.

These mobile editions import Classic DOS content only. Lemmings 2 and 3 are not
enabled. Read byo-integration.json for required files and import limits.
'''
    payloads = {'byo-integration.json': encoded(contract), 'README.txt': readme}
    manifest = manifest_for(payloads)
    manifest['kind'] = 'asset-free-mobile-classic-byo-integration'
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w') as archive:
        for name, value in sorted(payloads.items()):
            write_member(archive, name, value)
        write_member(archive, 'manifest.json', encoded(manifest))
    value = stream.getvalue()
    verify_archive(io.BytesIO(value), payloads, manifest)
    record = dict(manifest, archiveBytes=len(value), archiveSHA256=sha(value))
    return {'Integration/Ultimate-Lemmix-BYO.zip': value, 'Integration/manifest.json': encoded(record),
            'Integration/README.txt': readme, 'Provenance/mobile-byo-source.json': encoded({
                'schemaVersion': 1, 'parentHelperSHA256': sha(parent_archive),
                'mobileIdentifier': contract['id'], 'platforms': contract['platforms'],
                'supportedGameIDs': ['classic'], 'containsCommercialAssets': False,
                'containsExecutableCode': False})}


def inventory(files):
    """Describe exact approved bytes independently of either mobile platform."""
    return {'schemaVersion': 1, 'kind': 'ultimate-lemmix-mobile-resources',
            **media_rights(files), 'legacyContentIncluded': False,
            'files': [{'path': name, 'bytes': len(data), 'sha256': sha(data)}
                      for name, data in sorted(files.items())]}


def verify(directory, files):
    """Reject links, additional files and changed media or licence records."""
    if directory.is_symlink():
        raise ValueError('The mobile resource folder must not be a link.')
    actual = set()
    for path in directory.rglob('*'):
        if path.is_symlink():
            raise ValueError('The mobile resources contain a link.')
        if path.is_file():
            actual.add(path.relative_to(directory).as_posix())
    if actual != set(files) | {MANIFEST}:
        raise ValueError('The mobile resource folder contains extra or missing files.')
    expected = inventory(files)
    if json.loads((directory / MANIFEST).read_text()) != expected:
        raise ValueError('The mobile resource manifest changed.')
    for name, value in files.items():
        if (directory / safe_name(name)).read_bytes() != value:
            raise ValueError('An approved mobile resource changed: ' + name)
    return expected


def prepare(files):
    """Replace only an existing generated resource folder, using staged bytes."""
    if OUTPUT.is_symlink() or (OUTPUT.exists() and not (OUTPUT / MANIFEST).is_file()):
        raise ValueError('Refusing to replace an unrelated mobile resource folder.')
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='lemmix-mobile-', dir=OUTPUT.parent) as temporary:
        staged = Path(temporary) / 'resources'
        staged.mkdir()
        for name, value in files.items():
            target = staged / safe_name(name)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(value)
        (staged / MANIFEST).write_bytes(encoded(inventory(files)))
        verify(staged, files)
        old = Path(temporary) / 'previous'
        if OUTPUT.exists():
            OUTPUT.rename(old)
        try:
            staged.rename(OUTPUT)
        except OSError:
            if old.exists():
                old.rename(OUTPUT)
            raise
    return verify(OUTPUT, files)


ICON_SOURCE = ROOT / 'Resources/UltimateLemmix/AppIcon/UltimateLemmix.png'
TV_CHARACTER_MASK = ROOT / 'Apps/UltimateLemmixSupport/Artwork/TV-character-mask.png'
PNG_OPTIONS = ['-depth', '8', '-strip', '-define', 'png:exclude-chunks=date,time']


def tv_layers(directory):
    """Separate the Lix and moss from the sky so the TV can move each layer on focus."""
    front = directory / 'front.png'
    convert([ICON_SOURCE, TV_CHARACTER_MASK, '-alpha', 'off', '-compose', 'CopyOpacity',
             '-composite', front])
    # Recover the colours behind the figure from nearby uncovered pixels in each row.
    columns, rows = 64, 128
    grid = [ICON_SOURCE, TV_CHARACTER_MASK, '-alpha', 'off', '-compose', 'CopyOpacity',
            '-composite', '-channel', 'A', '-negate', '+channel', '-resize', f'{columns}x{rows}!',
            '-depth', '8', 'rgba:-']
    samples = convert(grid)
    colours = bytearray()
    for y in range(rows):
        row = samples[y * columns * 4:(y + 1) * columns * 4]
        stops = [x for x in range(columns) if row[x * 4 + 3] >= 250]
        for x in range(columns):
            left = max((stop for stop in stops if stop <= x), default=stops[0])
            right = min((stop for stop in stops if stop >= x), default=stops[-1])
            weight = (x - left) / (right - left) if right > left else 0
            for channel in range(3):
                colours.append(round(row[left * 4 + channel] * (1 - weight)
                                     + row[right * 4 + channel] * weight))
    fill = directory / 'fill.rgb'
    fill.write_bytes(colours)
    plate = directory / 'plate.png'
    size = int(convert([ICON_SOURCE, '-format', '%w', 'info:']))
    convert([ICON_SOURCE, '(', '-size', f'{columns}x{rows}', '-depth', '8', fill,
             '-resize', f'{size}x{size}!', ')', '(', TV_CHARACTER_MASK, '-morphology',
             'Dilate', 'Disk:7', '-blur', '0x3', ')', '-compose', 'over', '-composite', plate])
    # The soft transition lies in the empty sky above the moss.
    middle = directory / 'middle.png'
    convert([plate, '(', '-size', f'1x{size}', 'xc:black', '-fx',
             'min(1,max(0,(j/h-.70)/.08))', '-resize', f'{size}x{size}!', ')',
             '-alpha', 'off', '-compose', 'CopyOpacity', '-composite', middle])
    back = directory / 'back.png'
    sky_height = size * 79 // 100
    convert([plate, '-crop', f'{size}x{sky_height}+0+0', '+repage', '-virtual-pixel', 'edge',
             '-set', 'option:distort:viewport', f'{size}x{size}+0+0', '-distort', 'SRT', '0',
             '+repage', back])
    return {'Back': back, 'Middle': middle, 'Front': front}


def artwork_assets(platform):
    """Render the product icon at each catalogue size."""
    info = {'author': 'academy.glasscode.ultimatelemmix', 'version': 1}
    output = {'Contents.json': encoded({'info': info})}
    with tempfile.TemporaryDirectory(prefix='lemmix-mobile-icons-') as temporary:
        directory = Path(temporary)
        layers = tv_layers(directory) if platform == 'tvos' else {}

        def layer(width, height, kind):
            geometry = f'{width}x{height}'
            extra_width = (width - height) // 2
            if kind == 'Front':
                return convert([layers[kind], '-filter', 'Lanczos', '-resize', f'{height}x{height}!',
                                '-background', 'none', '-gravity', 'center', '-extent', geometry,
                                *PNG_OPTIONS, 'png:-'])
            # Extend only the clear scenery at the edges into the landscape margins.
            band = round(height * .14)
            wings = []
            for gravity in ('west', 'east'):
                wings.append(['(', '+clone', '-gravity', gravity, '-crop', f'{band}x{height}+0+0',
                              '+repage', '-flop', '-resize', f'{min(extra_width, band * 3)}x{height}!',
                              '-gravity', 'northwest', '-virtual-pixel', 'mirror', '-filter', 'point',
                              '-set', 'option:distort:viewport',
                              f'{extra_width}x{height}{min(0, band * 3 - extra_width) if gravity == "west" else 0:+d}+0',
                              '-distort', 'SRT', '0', '+repage', ')'])
            return convert([layers[kind], '-filter', 'Lanczos', '-resize', f'{height}x{height}!',
                            *wings[0], '+swap', *wings[1], '+append', *PNG_OPTIONS, 'png:-'])

        if platform == 'ios':
            image = convert([ICON_SOURCE, '-filter', 'Lanczos', '-resize', '1024x1024!',
                             '-alpha', 'off', *PNG_OPTIONS, 'PNG24:-'])
            output['AppIcon.appiconset/AppIcon-1024.png'] = image
            output['AppIcon.appiconset/Contents.json'] = encoded({'info': info, 'images': [{
                'filename': 'AppIcon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}]})
        else:
            brand = 'AppIcon.brandassets/'
            assets = []
            for title, width, height, scales in (('App Icon', 400, 240, (1, 2)),
                                                 ('App Icon - App Store', 1280, 768, (1,))):
                stack = title + '.imagestack'
                assets.append({'idiom': 'tv', 'filename': stack, 'role': 'primary-app-icon',
                               'size': f'{width}x{height}'})
                output[brand + stack + '/Contents.json'] = encoded({'info': info,
                    'layers': [{'filename': kind + '.imagestacklayer'} for kind in ('Front', 'Middle', 'Back')]})
                for kind in ('Front', 'Middle', 'Back'):
                    base = brand + stack + '/' + kind + '.imagestacklayer/'
                    output[base + 'Contents.json'] = encoded({'info': info})
                    images = []
                    for scale in scales:
                        filename = kind.lower() + f'@{scale}x.png'
                        output[base + 'Content.imageset/' + filename] = layer(width * scale, height * scale, kind)
                        images.append({'filename': filename, 'idiom': 'tv', 'scale': f'{scale}x'})
                    output[base + 'Content.imageset/Contents.json'] = encoded({'info': info, 'images': images})
            for title, width, role in (('Top Shelf Image', 1920, 'top-shelf-image'),
                                       ('Top Shelf Image Wide', 2320, 'top-shelf-image-wide')):
                images = []
                assets.append({'idiom': 'tv', 'filename': title + '.imageset', 'role': role,
                               'size': f'{width}x720'})
                for scale in (1, 2):
                    pieces = []
                    for kind in ('Back', 'Middle', 'Front'):
                        path = directory / f'{title}-{scale}-{kind}.png'
                        path.write_bytes(layer(width * scale, 720 * scale, kind))
                        pieces.append(path)
                    filename = f'top@{scale}x.png'
                    output[brand + title + '.imageset/' + filename] = convert([
                        pieces[0], pieces[1], '-compose', 'over', '-composite', pieces[2],
                        '-compose', 'over', '-composite', '-alpha', 'off', '-strip',
                        '-define', 'png:exclude-chunks=date,time', 'png:-'])
                    images.append({'filename': filename, 'idiom': 'tv', 'scale': f'{scale}x'})
                output[brand + title + '.imageset/Contents.json'] = encoded({'info': info, 'images': images})
            output[brand + 'Contents.json'] = encoded({'info': info, 'assets': assets})
    return output


def icons(write):
    """Verify source asset catalogues against their approved deterministic generation."""
    for platform, app in (('ios', 'UltimateLemmixIOS'), ('tvos', 'UltimateLemmixTVOS')):
        directory = ROOT / 'Apps' / app / 'Assets.xcassets'
        selected = artwork_assets(platform)
        if directory.is_symlink():
            raise ValueError('An application asset catalogue is a link.')
        actual = set()
        for path in directory.rglob('*'):
            if path.is_symlink():
                raise ValueError('A clean icon source folder contains a link.')
            if path.is_file():
                actual.add(path.relative_to(directory).as_posix())
        other_assets = {'StartupLogo.imageset/Contents.json', 'StartupLogo.imageset/startup-logo.png',
                        'LaunchBackground.colorset/Contents.json'}
        if actual - set(selected) - other_assets:
            raise ValueError('The clean asset catalogue contains an unapproved member.')
        for name, value in selected.items():
            target = directory / name
            if target.is_symlink():
                raise ValueError('A clean icon source is a link.')
            if write and (not target.exists() or target.read_bytes() != value):
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(value)
            if not target.is_file() or target.read_bytes() != value:
                raise ValueError('The clean icon differs from the pinned artwork: ' + str(target))


def audit_app(app, platform, files):
    """Audit app resources after Xcode copies them into the flat mobile bundle."""
    app = app.resolve()
    if ROOT / '.build' not in app.parents or app.suffix != '.app':
        raise ValueError('Audit a generated mobile application below .build.')
    expected_info = plistlib.loads((ROOT / 'Apps' / ('UltimateLemmixIOS' if platform == 'ios' else 'UltimateLemmixTVOS') / 'Info.plist').read_bytes())
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if (info.get('CFBundleIdentifier') != f'academy.glasscode.ultimatelemmix.{platform}'
            or info.get('CFBundleDisplayName') != 'Ultimate Lemmix'
            or not info.get('UltimateLemmixStore') or info.get('CFBundleShortVersionString') != '0.1'):
        raise ValueError('The application identity differs from the separate store edition.')
    if platform == 'tvos' and info.get('NSLocalNetworkUsageDescription') != expected_info.get('NSLocalNetworkUsageDescription'):
        raise ValueError('The local-transfer privacy purpose changed.')
    managed = set(files) | {MANIFEST}
    executable = info['CFBundleExecutable']
    generated = {'Info.plist', 'PkgInfo', 'Assets.car', executable, '_CodeSignature/CodeResources',
                 'embedded.mobileprovision', 'AppIcon60x60@2x.png', 'AppIcon60x60@3x.png',
                 'AppIcon76x76@2x~ipad.png', 'AppIcon83.5x83.5@2x~ipad.png'}
    for path in app.rglob('*'):
        if path.is_symlink():
            raise ValueError('The mobile application contains a symbolic link.')
        if not path.is_file():
            continue
        name = path.relative_to(app).as_posix()
        if name not in managed | generated:
            raise ValueError('The mobile application contains an unapproved file: ' + name)
    for name, value in files.items():
        if (app / name).read_bytes() != value:
            raise ValueError('The bundled mobile resource changed: ' + name)
    if json.loads((app / MANIFEST).read_text()) != inventory(files):
        raise ValueError('The mobile bundle resource manifest changed.')
    return {'resourceFiles': len(files), 'resourceBytes': sum(map(len, files.values())),
            'resourceManifestSHA256': sha((app / MANIFEST).read_bytes()),
            'displayName': info['CFBundleDisplayName'], 'bundleIdentifier': info['CFBundleIdentifier']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare', action='store_true')
    parser.add_argument('--icons', action='store_true', help='Create absent approved icon sources, then verify all icons.')
    parser.add_argument('--audit-app', type=Path)
    parser.add_argument('--platform', choices=('ios', 'tvos'))
    args = parser.parse_args()
    files = resources()
    if args.prepare:
        prepare(files)
    else:
        verify(OUTPUT, files)
    icons(args.icons)
    if args.audit_app:
        if not args.platform:
            parser.error('--audit-app requires --platform')
        print(json.dumps(audit_app(args.audit_app, args.platform, files), sort_keys=True))
    else:
        print(f'PASS approved mobile resources: {len(files)} files, {sum(map(len, files.values())):,} bytes; both clean icon catalogues verified.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit('FAILED: ' + str(error)) from error
