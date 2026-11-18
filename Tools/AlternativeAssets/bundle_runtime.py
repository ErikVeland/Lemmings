#!/usr/bin/env python3
"""Add the approved optional Lix resources to the preservation application's bundle."""
import argparse
import json
from pathlib import Path
import shutil

from store_resources import collect, sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('resources', type=Path)
    args = parser.parse_args()
    target = args.resources.resolve()
    if target.name != 'Resources' or target.parent.name != 'Contents' or target.parent.parent.suffix != '.app':
        raise SystemExit('Choose an application Contents/Resources directory.')
    selected = {}
    for name, data in collect(allow_missing_integration=True).items():
        if name.startswith('AlternativeAssets/Lix/'):
            selected[name.removeprefix('AlternativeAssets/')] = data
        elif name.startswith('Music/Lix/') or name == 'Music/catalogue.json':
            selected[name] = data
        elif name.startswith(('Licences/', 'Provenance/')):
            selected[name] = data
    destination = target / 'AlternativeAssets'
    if destination.is_symlink():
        raise SystemExit('The alternative resource directory must not be a link.')
    if destination.exists():
        shutil.rmtree(destination)
    for name, data in selected.items():
        path = destination / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    (destination / 'runtime-manifest.json').write_text(json.dumps({
        'schemaVersion': 1,
        'files': [{'path': name, 'bytes': len(data), 'sha256': sha(data)}
                  for name, data in sorted(selected.items())]
    }, indent=2) + '\n')
    print(f'Bundled optional Lix resources: {len(selected)} files')


if __name__ == '__main__':
    main()
