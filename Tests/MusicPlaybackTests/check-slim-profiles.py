"""Check slim profiles against old library hashes without playing audio."""
from copy import deepcopy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('library', ROOT/'Tools/MusicCatalogue/library.py')
library = importlib.util.module_from_spec(spec)
spec.loader.exec_module(library)
digest = lambda value: hashlib.sha256(value).hexdigest()

with tempfile.TemporaryDirectory() as scratch:
    root = Path(scratch)
    source = root/'Sources/Music'; source.mkdir(parents=True)
    resources = root/'Resources/Music'; resources.mkdir(parents=True)
    target = root/'Music'; libraries = resources/'libraries.json'
    source_bytes = {'native.mod': b'native-module', 'main.m4a': b'main-source',
                    'legacy.m4a': b'lossless-source', 'unchanged.mp3': b'unchanged-source'}
    full_bytes = dict(source_bytes, **{'main.m4a': b'encoded-main', 'legacy.m4a': b'older-published-AAC'})
    for name, data in source_bytes.items(): (source/name).write_bytes(data)
    def variant(identity, path, quality):
        return dict(id=identity, path=path, quality=quality, port='amiga', remix='original')
    catalogue = dict(schemaVersion=1, tracks=[
        dict(id='classic.native', game='classic', variants=[variant('native', 'native.mod', 'native-module')]),
        dict(id='classic.mariarti', game='classic', variants=[variant('main', 'main.m4a', 'lossy-source')]),
        dict(id='classic.legacy', game='classic', variants=[variant('legacy', 'legacy.m4a', 'chip-render')]),
        dict(id='classic.unchanged', game='classic', variants=[variant('unchanged', 'unchanged.mp3', 'lossy-source')])])
    timing = dict(schemaVersion=1, variants=[dict(variantID=identity, sourceSHA256=digest(source_bytes[path]))
        for identity, path in [('native', 'native.mod'), ('main', 'main.m4a'), ('legacy', 'legacy.m4a'), ('unchanged', 'unchanged.mp3')]])
    def profile(identity, path):
        return dict(variantID=identity, path=path, sourceSHA256=digest(source_bytes[path]),
                    sampleRate=44100, frameCount=44100, integratedLUFS=-22, truePeakDBTP=-10, gainDB=2,
                    loopStatus='verified-vgm', loop=dict(startFrame=4410, endFrame=22050,
                    sourcePath=path+'.vgm', sourceSHA256='a'*64))
    canonical = dict(schemaVersion=1, variants=[profile(identity, path) for identity, path in
        [('main', 'main.m4a'), ('legacy', 'legacy.m4a'), ('unchanged', 'unchanged.mp3')]])
    (resources/'recording-playback.json').write_bytes(library.encoded(canonical))
    index = dict(packs=[dict(files=[dict(path='Music/'+path, sha256=digest(full_bytes[path]))
        for path in ['legacy.m4a', 'unchanged.mp3']])])
    libraries.write_bytes(library.encoded(index))
    def install_full():
        target.mkdir(exist_ok=True)
        for name, data in full_bytes.items(): (target/name).write_bytes(data)
        previous = deepcopy(canonical)
        for row in previous['variants']:
            if digest(full_bytes[row['path']]) != row['sourceSHA256']:
                row['playbackSHA256'] = digest(full_bytes[row['path']])
        (target/'recording-playback.json').write_bytes(library.encoded(previous))
        (target/'bundle.json').write_bytes(library.encoded(dict(scope='full', game='all')))
    old_root = library.ROOT
    library.ROOT = root
    try:
        install_full()
        library.bundle(source, catalogue, timing, target, 'main', 'all', libraries, preserve_recording_profiles=True)
        rows = {r['variantID']: r for r in json.loads((target/'recording-playback.json').read_text())['variants']}
        assert (target/'native.mod').read_bytes() == source_bytes['native.mod']
        assert (target/'main.m4a').read_bytes() == source_bytes['main.m4a']
        assert rows['main'].get('playbackSHA256', rows['main']['sourceSHA256']) == digest(source_bytes['main.m4a'])
        assert not (target/'legacy.m4a').exists() and not (target/'unchanged.mp3').exists()
        # Match the hash guard used by SoundtrackPlayer for an old installed library.
        download = root/'installed/old/Music/legacy.m4a'; download.parent.mkdir(parents=True)
        download.write_bytes(full_bytes['legacy.m4a'])
        assert rows['legacy']['playbackSHA256'] == library.digest(download)
        assert rows['legacy']['loop'] == canonical['variants'][1]['loop']
        assert rows['unchanged'].get('playbackSHA256', rows['unchanged']['sourceSHA256']) == digest(source_bytes['unchanged.mp3'])
        first = (target/'recording-playback.json').read_bytes()
        library.bundle(source, catalogue, timing, target, 'main', 'all', libraries, preserve_recording_profiles=True)
        assert (target/'recording-playback.json').read_bytes() == first
        for mutation in ['file', 'source', 'gain', 'loop', 'library', 'duplicate']:
            install_full(); libraries.write_bytes(library.encoded(index))
            previous = json.loads((target/'recording-playback.json').read_text())
            if mutation == 'file': (target/'legacy.m4a').write_bytes(b'changed')
            elif mutation == 'library':
                wrong = deepcopy(index); wrong['packs'][0]['files'][0]['sha256'] = 'b'*64
                libraries.write_bytes(library.encoded(wrong))
            elif mutation == 'duplicate': previous['variants'].append(deepcopy(previous['variants'][1]))
            elif mutation == 'loop': previous['variants'][1]['loop']['startFrame'] += 1
            else: previous['variants'][1][{'source': 'sourceSHA256', 'gain': 'gainDB'}[mutation]] = 'c'*64 if mutation == 'source' else 3
            (target/'recording-playback.json').write_bytes(library.encoded(previous))
            before = (target/'recording-playback.json').read_bytes()
            try:
                library.bundle(source, catalogue, timing, target, 'main', 'all', libraries, preserve_recording_profiles=True)
            except ValueError: pass
            else: raise AssertionError('Accepted invalid profile closure: '+mutation)
            assert (target/'recording-playback.json').read_bytes() == before
            assert (target/'bundle.json').read_text().find('full') >= 0
    finally: library.ROOT = old_root
print('PASS slim old-AAC library binding, original main sources, unchanged MP3, repeated stripping and six fail-before-delete guards')

canonical = {r['variantID']: r for r in json.loads((ROOT/'Resources/Music/recording-playback.json').read_text())['variants']}
index = json.loads((ROOT/'Resources/Music/libraries.json').read_text())
checked = set()
for pack in index['packs']:
    path = ROOT/'.build/music-libraries'/index['version']/(pack['id']+'.zip')
    files = {f['path']: f for f in pack['files']}
    assert library.digest(path) == pack['sha256'], pack['id']
    with zipfile.ZipFile(path) as archive:
        timing_bytes = archive.read('Music/timing.json')
        assert digest(timing_bytes) == files['Music/timing.json']['sha256']
        catalogue_bytes = archive.read('Music/catalogue.json')
        assert digest(catalogue_bytes) == files['Music/catalogue.json']['sha256']
        variants = {v['id']: v for t in json.loads(catalogue_bytes)['tracks'] for v in t['variants']}
        for row in json.loads(timing_bytes)['variants']:
            if row['variantID'] not in canonical: continue
            profile = canonical[row['variantID']]
            assert row['path'] == profile['path'] == variants[row['variantID']]['path']
            assert row['sourceSHA256'] == profile['sourceSHA256']
            pinned = files['Music/'+profile['path']]['sha256']
            assert row.get('playbackSHA256', row['sourceSHA256']) == pinned
            with archive.open('Music/'+profile['path']) as stream:
                assert hashlib.file_digest(stream, 'sha256').hexdigest() == pinned
            checked.add(row['variantID'])
main = {v['id'] for t in json.loads((ROOT/'Resources/Music/catalogue.json').read_text())['tracks']
        for v in t['variants'] if library.is_main(t, v)}
assert checked == set(canonical)-main
print(f'PASS {len(checked)} older-library recording source/identity/playback bindings across all {len(index["packs"])} immutable archives')
