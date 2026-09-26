import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[2]
source = ROOT / 'Sources/Music'
catalogue = json.loads((ROOT / 'Resources/Music/catalogue.json').read_text())
timing = json.loads((ROOT / 'Resources/Music/timing.json').read_text())
versions = {v['id']: v for t in catalogue['tracks'] for v in t['variants']}
assert set(versions) == {r['variantID'] for r in timing['variants']}
assert not timing['failures']
for row in timing['variants']:
    assert row['path'] == versions[row['variantID']]['path']
    with (source / row['path']).open('rb') as stream:
        assert hashlib.file_digest(stream, 'sha256').hexdigest() == row['sourceSHA256'], row['path']
    if row['barStatus'] == 'estimated-stable':
        assert row['bpmStatus'] == 'estimated-stable' and row['barAgreement'] >= 0.9
print('PASS all 495 source hashes, exact version joins and stable-bar eligibility')

spec = importlib.util.spec_from_file_location('package_music', ROOT / 'Tools/MusicCatalogue/package.py')
package = importlib.util.module_from_spec(spec); spec.loader.exec_module(package)
with tempfile.TemporaryDirectory() as folder:
    scratch = Path(folder); src = scratch / 'source'; src.mkdir()
    target = scratch / 'target'; target.mkdir()
    (src / 'track.wav').write_bytes(b'source')
    (target / 'track.m4a').write_bytes(b'lossless-packaged')
    (scratch / 'catalogue.json').write_text(json.dumps({'schemaVersion': 1, 'tracks': [
        {'id': 'classic.a', 'game': 'classic', 'variants': [{'id': 'test', 'path': 'track.wav'}]}]}))
    row = dict(timing['variants'][0], variantID='test', path='track.wav', sourceSHA256=hashlib.sha256(b'source').hexdigest())
    (scratch / 'timing.json').write_text(json.dumps(dict(timing, variants=[row])))
    package.package(scratch / 'catalogue.json', src, target, 'all')
    stored = json.loads((target / 'timing.json').read_text())['variants'][0]
    assert stored['path'] == 'track.m4a'
    assert stored['sourceSHA256'] == row['sourceSHA256']
    assert stored['playbackSHA256'] == hashlib.sha256(b'lossless-packaged').hexdigest()
    fixture_catalogue = json.loads((scratch / 'catalogue.json').read_text())
    fixture_rows = [row]
    for game in ('lemmings2', 'lemmings3'):
        name = game + '.wav'
        (src / name).write_bytes(game.encode())
        fixture_catalogue['tracks'].append({'id': game + '.theme', 'game': game,
            'variants': [{'id': game, 'path': name}]})
        fixture_rows.append(dict(row, variantID=game, path=name,
            sourceSHA256=hashlib.sha256(game.encode()).hexdigest()))
    (scratch / 'catalogue.json').write_text(json.dumps(fixture_catalogue))
    (scratch / 'timing.json').write_text(json.dumps(dict(timing, variants=fixture_rows)))
    for game in ('lemmings2', 'lemmings3'):
        package.package(scratch / 'catalogue.json', src, scratch / game, game)
        subset = json.loads((scratch / game / 'timing.json').read_text())['variants']
        assert len(subset) == 1 and subset[0]['variantID'] == game
        assert subset[0]['sourceSHA256'] == subset[0]['playbackSHA256']
    (scratch / 'catalogue.json').write_text(json.dumps({'tracks': fixture_catalogue['tracks'][:1]}))
    (scratch / 'timing.json').write_text(json.dumps(dict(timing, variants=[row])))
    (src / 'track.wav').write_bytes(b'replaced')
    try:
        package.package(scratch / 'catalogue.json', src, target, 'all')
        raise AssertionError('Stale analysis was packaged')
    except ValueError:
        pass
print('PASS lossless path rewriting, packaged hashes, sequel subsets and stale timing rejection')
