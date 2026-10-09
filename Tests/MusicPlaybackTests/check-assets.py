"""Check hash-bound source loops, measured trims and metadata packaging without audio output."""
import gzip
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import tempfile

ROOT = Path(__file__).resolve().parents[2]
MUSIC = ROOT/'Sources/Music'
payload = json.loads((ROOT/'Resources/Music/recording-playback.json').read_text())
assert (MUSIC/'recording-playback.json').read_bytes() == (ROOT/'Resources/Music/recording-playback.json').read_bytes()
catalogue = json.loads((ROOT/'Resources/Music/catalogue.json').read_text())
recordings = {v['id']: v for t in catalogue['tracks'] for v in t['variants'] if not v['path'].endswith('.mod')}
assert set(recordings) == {r['variantID'] for r in payload['variants']}
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
for row in payload['variants']:
    assert row['path'] == recordings[row['variantID']]['path']
    assert digest(MUSIC/row['path']) == row['sourceSHA256'], row['path']
    expected = min(6, -20-row['integratedLUFS'], -6-row['truePeakDBTP'])
    assert abs(row['gainDB']-expected) < 0.001
    assert row['truePeakDBTP']+row['gainDB'] <= -6.0+0.001
    assert row['integratedLUFS']+row['gainDB'] <= -20.0+0.001
    assert all(math.isfinite(row[name]) for name in ['integratedLUFS','truePeakDBTP','gainDB'])
    if row['loop']:
        loop = row['loop']; source = MUSIC/loop['sourcePath']
        assert digest(source) == loop['sourceSHA256']
        data = source.read_bytes()
        if data[:2] == b'\x1f\x8b': data = gzip.decompress(data)
        total, offset, count = struct.unpack_from('<III', data, 0x18)
        assert offset and count and loop['startFrame'] == total-count and loop['endFrame'] == total
        assert row['sampleRate'] == 44100 and loop['endFrame'] <= row['frameCount']
    else:
        assert row['loopStatus'] in ('unverified-source-loop', 'source-has-no-loop')
print('PASS all 422 recording hashes, conservative measured gain trims and 296 exact VGM loops')

def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT/f'Tools/MusicCatalogue/{name}.py')
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module

library = load('library'); package = load('package'); profiles = load('recording_profiles')
timing = json.loads((ROOT/'Resources/Music/timing.json').read_text())
subset = library.select(catalogue, lambda t, v: v['id'] == payload['variants'][0]['variantID'])
metadata = library.metadata(subset, timing)
assert len(json.loads(metadata['Music/recording-playback.json'])['variants']) == 1
path = payload['variants'][0]['path']
rewritten = library.with_playback(metadata, {path: 'b'*64})
assert json.loads(rewritten['Music/recording-playback.json'])['variants'][0]['playbackSHA256'] == 'b'*64

with tempfile.TemporaryDirectory() as scratch:
    scratch = Path(scratch); source = scratch/'source'; target = scratch/'target'
    source.mkdir(); target.mkdir()
    (source/'theme.wav').write_bytes(b'original'); (target/'theme.m4a').write_bytes(b'encoded')
    manifest = scratch/'catalogue.json'
    manifest.write_text(json.dumps(dict(schemaVersion=1, tracks=[dict(id='classic.theme', game='classic',
        variants=[dict(id='theme', path='theme.wav')])])) )
    profile = dict(payload['variants'][0], variantID='theme', path='theme.wav', sourceSHA256=digest(source/'theme.wav'))
    (scratch/'recording-playback.json').write_text(json.dumps(dict(schemaVersion=1, variants=[profile])))
    package.package(manifest, source, target, 'all')
    shipped = json.loads((target/'recording-playback.json').read_text())['variants'][0]
    assert shipped['path'] == 'theme.m4a' and shipped['playbackSHA256'] == digest(target/'theme.m4a')
    profile['sourceSHA256'] = '0'*64
    (scratch/'recording-playback.json').write_text(json.dumps(dict(schemaVersion=1, variants=[profile])))
    try: package.package(manifest, source, target, 'all')
    except ValueError: pass
    else: raise AssertionError('Stale profile packaged')
    # VGM frame counts are accepted only with unchanged render provenance.
    vgm = source/'theme.vgm'
    header = bytearray(64); header[:4] = b'Vgm '
    struct.pack_into('<III', header, 0x18, 88200, 12, 44100); vgm.write_bytes(header)
    output = source/'theme.m4a'; output.write_bytes(b'lossless-render')
    provenance = dict(source_sha256=digest(vgm), output_sha256=digest(output))
    loop, status = profiles.source_loop(vgm, output, provenance,
        dict(codec_name='alac', sample_rate='44100', duration='11'))
    assert status == 'verified-vgm' and loop['startFrame'] == 44100 and loop['endFrame'] == 88200
    output.write_bytes(b'changed')
    try: profiles.source_loop(vgm, output, provenance, dict(codec_name='alac', sample_rate='44100', duration='11'))
    except ValueError: pass
    else: raise AssertionError('Changed output inherited source loop')
print('PASS optional-library profile filtering, playback hash rewrites, source validation and package conversion')
