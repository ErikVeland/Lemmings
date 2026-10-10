import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[2]
catalogue = json.loads((ROOT / 'Resources/Music/catalogue.json').read_text())
libraries = json.loads((ROOT / 'Resources/Music/libraries.json').read_text())
versions = {v['id'] for t in catalogue['tracks'] for v in t['variants']}
main = {v['id'] for t in catalogue['tracks'] for v in t['variants']
        if (v['quality'] == 'native-module' and t['game'] != 'demo') or t['id'] == 'classic.mariarti'}
optional = set()
for pack in libraries['packs']:
    path = ROOT / '.build/music-libraries/1.6' / (pack['id'] + '.zip')
    assert path.stat().st_size == pack['bytes']
    with path.open('rb') as stream: assert hashlib.file_digest(stream, 'sha256').hexdigest() == pack['sha256']
    with zipfile.ZipFile(path) as archive:
        assert sorted(archive.namelist()) == sorted(f['path'] for f in pack['files'])
        for file in pack['files']:
            assert archive.getinfo(file['path']).file_size == file['bytes']
            with archive.open(file['path']) as stream:
                assert hashlib.file_digest(stream, 'sha256').hexdigest() == file['sha256']
        subset = json.loads(archive.read('Music/catalogue.json'))
        identities = {v['id'] for t in subset['tracks'] for v in t['variants']}
        assert len(identities) == pack['trackCount']
        assert not identities & (main | optional)
        optional |= identities
    print(f"PASS {pack['id']}: complete archive and every file hash", flush=True)
assert main | optional == versions
assert len(main) == 54 and len(optional) == 441
print('PASS main + optional libraries cover all 495 versions exactly once')
