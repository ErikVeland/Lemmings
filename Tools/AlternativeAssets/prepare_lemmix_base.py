#!/usr/bin/env python3
"""Prepare the alternative asset profile with current full-game metadata."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import zipfile
from prepare_open_starter import resources as starter_resources

ROOT = Path(__file__).resolve().parents[2]
PIN = ROOT / 'Resources/UltimateLemmix/alternative-resource-source.json'


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def copy_tree(source, target, suffix=None):
    for path in sorted(source.rglob('*')):
        if path.is_symlink():
            raise ValueError('Resource inputs must not contain links.')
        if path.is_file() and (suffix is None or path.suffix == suffix):
            write(target / path.relative_to(source), path.read_bytes())


def prepare_game_center(directory):
    """Give Lemmix separate Apple identities without changing ranked conditions or scores."""
    runtime_path = directory / 'leaderboards.json'
    setup_path = directory / 'app-store-connect-boards.json'
    runtime = json.loads(runtime_path.read_bytes())
    setup = json.loads(setup_path.read_bytes())
    original = json.loads(json.dumps([runtime, setup]))
    career_keys = ('starsID', 'clearsID', 'perfectID')
    level_keys = ('leaderboardID', 'fastestClearID', 'fastestAllSavedID')

    def replace_id(value, before, after):
        if not isinstance(value, str) or not value.startswith(before):
            raise ValueError('The Game Center source identifier has an unexpected namespace.')
        result = after + value[len(before):]
        if len(result) > 100:
            raise ValueError('The Lemmix Game Center identifier exceeds 100 characters.')
        return result

    def remap(config, manifest, before, after):
        for key in career_keys:
            config[key] = replace_id(config[key], before, after)
        for row in config['levels']:
            for key in level_keys:
                if row.get(key) is not None:
                    row[key] = replace_id(row[key], before, after)
        for row in manifest['leaderboards']:
            for key in ('id', 'set'):
                row[key] = replace_id(row[key], before, after)

    if setup.get('bundleID') != 'academy.glasscode.lemmings':
        raise ValueError('The shared Game Center manifest names an unexpected product.')
    remap(runtime, setup, 'ul.v1.', 'ulx.v1.')
    setup['bundleID'] = 'academy.glasscode.ultimatelemmix'
    identifiers = [runtime[key] for key in career_keys]
    identifiers += [row[key] for row in runtime['levels'] for key in level_keys if row.get(key) is not None]
    apple_ids = [row['id'] for row in setup['leaderboards']]
    if (len(set(identifiers)) != len(identifiers) or len(set(apple_ids)) != len(apple_ids)
            or set(identifiers) != set(apple_ids)):
        raise ValueError('The Lemmix runtime and Apple manifests must contain the same unique identifiers.')
    restored_runtime, restored_setup = json.loads(json.dumps([runtime, setup]))
    remap(restored_runtime, restored_setup, 'ulx.v1.', 'ul.v1.')
    restored_setup['bundleID'] = 'academy.glasscode.lemmings'
    if [restored_runtime, restored_setup] != original:
        raise ValueError('The Lemmix Game Center transform changed non-identity data.')
    for path, value in ((runtime_path, runtime), (setup_path, setup)):
        write(path, (json.dumps(value, indent=2, sort_keys=True) + '\n').encode())


def write_data_inventory(output):
    """List prepared data files before an Apple target adds code and signing metadata."""
    name = 'ultimate-lemmix-data-inventory.json'
    excluded = {name, 'ultimate-lemmix-mobile-resources.json'}
    rows = []
    for path in sorted(output.rglob('*')):
        if path.is_symlink():
            raise ValueError('Prepared resource data must not contain links.')
        if path.is_file() and path.relative_to(output).as_posix() not in excluded:
            data = path.read_bytes()
            rows.append({'path': path.relative_to(output).as_posix(), 'bytes': len(data),
                         'sha256': hashlib.sha256(data).hexdigest()})
    write(output / name, (json.dumps({'schemaVersion': 1, 'kind': 'ultimate-lemmix-trusted-base-data',
                                     'files': rows}, indent=2) + '\n').encode())


def prepare(output, alternatives, store=False):
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise ValueError('Prepare resources in a new, empty output directory.')
    pin = json.loads(PIN.read_bytes())
    for row in pin['files']:
        source = alternatives / row['path']
        if source.is_symlink() or not source.is_file():
            raise ValueError('An approved alternative asset is missing or linked.')
        data = source.read_bytes()
        if len(data) != row['bytes'] or hashlib.sha256(data).hexdigest() != row['sha256']:
            raise ValueError('An approved alternative asset changed: ' + row['path'])
        write(output / row['path'], data)
    write(output / 'Provenance/alternative-resource-source.json', PIN.read_bytes())
    copy_tree(ROOT / 'Sources/NxlvKit/Resources/Localization.bundle', output / 'Localization.bundle')
    for name in ('Hints', 'Progression', 'GameCenter'):
        copy_tree(ROOT / 'Resources' / name, output / name, '.json')
    prepare_game_center(output / 'GameCenter')
    subprocess.run(['python3', ROOT / 'Tools/TrolleyVerification/catalogue.py', 'bundle', output / 'Trolley'], check=True)
    subprocess.run(['python3', ROOT / 'Scripts/bundle-about.py', output / 'About'], check=True)
    publication = json.loads((ROOT / 'Resources/Publishing/ultimate-lemmix.json').read_bytes())
    notes = ROOT / ('Documentation/ReleaseNotes-UltimateLemmix-' + publication['version']
                    + '-build' + str(publication['platforms']['macos']['build']) + '.md')
    history = '\n'.join(line for line in notes.read_text().splitlines()
                        if not line.startswith(('Build:', 'Release base:', 'Platform builds:')))
    write(output / 'About/VersionHistory.md', (history.strip() + '\n').encode())
    for name, data in starter_resources().items():
        write(output / 'Ports/ultimate_lemmix_starter' / name, data)
    copy_tree(ROOT / 'Resources/UltimateLemmix/MenuArtwork', output / 'MenuArtwork')
    if store:
        from store_resources import clean_icon
        from prepare_project_pixel import resources as pixel_resources
        metadata = json.loads((output / 'AlternativeAssets/Lix/sprite-metadata.json').read_bytes())
        sheet = output / 'AlternativeAssets/Lix/assets' / metadata['sourcePath']
        for name, data in clean_icon(sheet.read_bytes(), metadata).items():
            write(output / name, data)
        for name, data in pixel_resources().items():
            write(output / name, data)
    else:
        icon = ROOT / 'Resources/AppIcon/AppIcon.png'
        write(output / 'AppIcon.png', icon.read_bytes())
        write(output / 'Licences/Project-icon-source.md', (ROOT / 'Resources/AppIcon/README.md').read_bytes())
        write(output / 'Provenance/project-icon-source.json', (json.dumps({
            'kind': 'requested-existing-project-icon', 'cc0': False, 'redistributionCleared': False,
            'rightsReviewRequired': True, 'sha256': hashlib.sha256(icon.read_bytes()).hexdigest(),
            'notice': 'Licences/Project-icon-source.md'}, indent=2) + '\n').encode())
        boards = output / 'GameCenter/leaderboards.json'
        config = json.loads(boards.read_bytes())
        config['enabled'] = False
        boards.write_text(json.dumps(config, indent=2, sort_keys=True) + '\n')
    write(output / 'Licences/THIRD_PARTY_NOTICES.md', (ROOT / 'THIRD_PARTY_NOTICES.md').read_bytes())
    guide = (ROOT / 'Resources/UltimateLemmix/BYO-README.txt').read_bytes()
    contract = (ROOT / 'Resources/UltimateLemmix/byo-integration.json').read_bytes()
    integration = output / 'Integration'
    integration.mkdir()
    with zipfile.ZipFile(integration / 'Ultimate-Lemmix-BYO.zip', 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in (('README.txt', guide), ('byo-integration.json', contract)):
            entry = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, data)
    write(integration / 'README.txt', guide)
    write(output / 'Licences/Distribution-scope.txt', (
        'Lix graphics and music retain their CC0 notices. The Lix font has its own full licence.\n' +
        ('The Store icon uses the approved CC0 Lix sprite. Interface lettering uses the shared Ultimate Lemmings pixel font.\n'
         if store else 'The requested existing project icon is separate and requires rights review.\n') +
        'Players supply any original game assets used for restoration.\n'
        'Imports and this helper do not grant redistribution rights.\n').encode())
    fingerprint = (output / 'Trolley/engine-fingerprint.txt').read_text().strip()
    print('Prepared current full-game metadata with alternative media. Engine fingerprint: ' + fingerprint)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--alternative-resources', type=Path)
    parser.add_argument('--inventory-only', action='store_true')
    arguments = parser.parse_args()
    if arguments.inventory_only:
        write_data_inventory(arguments.output)
    else:
        if arguments.alternative_resources is None:
            parser.error('--alternative-resources is required when preparing data.')
        prepare(arguments.output, arguments.alternative_resources)
