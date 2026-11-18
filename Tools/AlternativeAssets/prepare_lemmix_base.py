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


def prepare(output, alternatives):
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
    subprocess.run(['python3', ROOT / 'Tools/TrolleyVerification/catalogue.py', 'bundle', output / 'Trolley'], check=True)
    subprocess.run(['python3', ROOT / 'Scripts/bundle-about.py', output / 'About'], check=True)
    for name, data in starter_resources().items():
        write(output / 'Ports/ultimate_lemmix_starter' / name, data)
    copy_tree(ROOT / 'Resources/UltimateLemmix/MenuArtwork', output / 'MenuArtwork')
    icon = ROOT / 'Resources/AppIcon/AppIcon.png'
    write(output / 'AppIcon.png', icon.read_bytes())
    write(output / 'Licences/Project-icon-source.md', (ROOT / 'Resources/AppIcon/README.md').read_bytes())
    write(output / 'Licences/THIRD_PARTY_NOTICES.md', (ROOT / 'THIRD_PARTY_NOTICES.md').read_bytes())
    write(output / 'Provenance/project-icon-source.json', (json.dumps({
        'kind': 'requested-existing-project-icon', 'cc0': False, 'redistributionCleared': False,
        'rightsReviewRequired': True, 'sha256': hashlib.sha256(icon.read_bytes()).hexdigest(),
        'notice': 'Licences/Project-icon-source.md'}, indent=2) + '\n').encode())
    # This is the normal ad-hoc capability configuration; code and UI stay present.
    boards = output / 'GameCenter/leaderboards.json'
    config = json.loads(boards.read_bytes())
    config['enabled'] = False
    boards.write_text(json.dumps(config, indent=2, sort_keys=True) + '\n')
    guide = (ROOT / 'Resources/UltimateLemmix/BYO-README.txt').read_bytes()
    contract = (ROOT / 'Resources/UltimateLemmix/byo-integration.json').read_bytes()
    integration = output / 'Integration'
    integration.mkdir()
    with zipfile.ZipFile(integration / 'Ultimate-Lemmix-BYO.zip', 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('README.txt', guide)
        archive.writestr('byo-integration.json', contract)
    write(integration / 'README.txt', guide)
    write(output / 'Licences/Distribution-scope.txt', (
        'Lix graphics and music retain their CC0 notices. The Lix font has its own full licence.\n'
        'The requested existing project icon is separate and requires rights review.\n'
        'Original game assets are supplied by the player and stay outside the installed app.\n'
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
