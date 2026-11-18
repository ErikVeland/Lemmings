#!/usr/bin/env python3
"""Add the requested traditional remixes to a local manual build."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
TRACKS = ('classic.cancan', 'classic.mountain', 'classic.tim6',
          'classic.tim7', 'classic.tim8', 'classic.tim9')
SOURCE = 'https://www.lemmingsforums.net/index.php?topic=3921.0'


def prepare(source, output):
    audit = json.loads((ROOT / 'Resources/AlternativeAssets/fan-remix-rights.json').read_text())
    catalogue = json.loads((ROOT / 'Resources/Music/catalogue.json').read_text())
    target = output / 'Music/catalogue.json'
    current = json.loads(target.read_text())
    entries, files = [], []
    for identity in TRACKS:
        audited = next(t for t in audit['tracks'] if t['id'] == identity)
        recording = next(f for f in audited['files'] if f['role'] == 'playback')
        relative = Path(recording['path']).relative_to('Sources/Music')
        path = source / relative
        data = path.read_bytes()
        if len(data) != recording['bytes'] or hashlib.sha256(data).hexdigest() != recording['sha256']:
            raise ValueError('The local remix does not match its recorded source: ' + str(relative))
        track = next(t for t in catalogue['tracks'] if t['id'] == identity)
        variant = next(v for v in track['variants'] if v['path'] == relative.as_posix()).copy()
        destination = 'Traditional Remixes/' + path.name
        variant['path'] = destination
        variant['credits'] = 'MandelSoft — arrangement and recording'
        variant['evidence'] = SOURCE
        entry = {**track, 'variants': [variant]}
        entries.append(entry)
        dest = output / 'Music' / destination
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, dest)
        files.append({'id': identity, 'title': track['title'], 'path': 'Music/' + destination,
                      'sha256': recording['sha256'], 'bytes': len(data)})
    current['tracks'] = [t for t in current['tracks'] if t['id'] not in TRACKS] + entries
    target.write_text(json.dumps(current, indent=2) + '\n')
    provenance = output / 'Provenance/local-traditional-remixes.json'
    provenance.parent.mkdir(parents=True, exist_ok=True)
    provenance.write_text(json.dumps({'schemaVersion': 1, 'scope': 'local-manual-build',
        'creator': 'MandelSoft', 'permissionSource': SOURCE,
        'permissionScope': 'Credited level packs and replacement soundtracks.',
        'publicReleaseApproval': False, 'files': files}, indent=2) + '\n')
    notice = output / 'Licences/MandelSoft-remixes.txt'
    notice.parent.mkdir(parents=True, exist_ok=True)
    notice.write_text('Traditional Remixes\nArrangements and recordings by MandelSoft.\n'
        'Included for the requested local manual build.\n'
        'The creator permits credited use in level packs and replacement soundtracks.\n'
        + SOURCE + '\n\n' + '\n'.join(t['title'] for t in entries) + '\n')
    print('Prepared six credited traditional and classical remixes for local playback.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    prepare(args.source, args.output)
