import importlib.util
import json
from pathlib import Path
import tempfile

ROOT=Path(__file__).resolve().parents[2]
MUSIC=ROOT/'Sources/Music'
catalogue=json.loads((ROOT/'Resources/Music/catalogue.json').read_text())
variants=[v for t in catalogue['tracks'] for v in t['variants']]
known={v['path'] for v in variants}
actual={p.relative_to(MUSIC).as_posix() for p in MUSIC.rglob('*') if p.is_file() and not p.is_symlink() and p.suffix.lower() in {'.mod','.m4a','.wav','.mp3'}}
assert known==actual, (known-actual,actual-known)
links=list((MUSIC/'By Track').rglob('*'))
assert all(p.exists() for p in links), 'Broken browsing link'
assert {p.resolve() for p in links if p.is_symlink()} >= {MUSIC/p for p in known}
assert all(p.is_symlink() for p in links if p.is_file()), 'Browsing view duplicates audio'
spec=importlib.util.spec_from_file_location('package',ROOT/'Tools/MusicCatalogue/package.py')
package=importlib.util.module_from_spec(spec);spec.loader.exec_module(package)
with tempfile.TemporaryDirectory() as folder:
    scratch=Path(folder); source=scratch/'source';source.mkdir()
    # Small fixtures test package filtering and WAV-to-M4A catalogue rewriting.
    for name in ['classic.wav','l2.mod','l2.m4a','l3.mod']: (source/name).write_bytes(b'fixture')
    tracks=[dict(id='classic.a',game='classic',variants=[dict(path='classic.wav')]),
            dict(id='lemmings2.a',game='lemmings2',variants=[dict(path='l2.mod'),dict(path='l2.m4a')]),
            dict(id='lemmings3.a',game='lemmings3',variants=[dict(path='l3.mod')])]
    manifest=scratch/'catalogue.json';manifest.write_text(json.dumps(dict(schemaVersion=1,tracks=tracks)))
    for game,count in [('lemmings2',2),('lemmings3',1)]:
        target=scratch/game
        package.package(manifest,source,target,game)
        installed=json.loads((target/'catalogue.json').read_text())
        assert len(installed['tracks'])==1 and installed['tracks'][0]['game']==game
        assert len(list(target.glob('*')))==count+1
    target=scratch/'all';target.mkdir()
    for name in ['classic.m4a','l2.mod','l2.m4a','l3.mod']: (target/name).write_bytes(b'fixture')
    package.package(manifest,source,target,'all')
    assert json.loads((target/'catalogue.json').read_text())['tracks'][0]['variants'][0]['path']=='classic.m4a'
print('PASS complete asset coverage, browsing links and Classic/L2/L3 packaging')

for folder, port, count, quality in [('Archimedes/', 'archimedes', 21, 'lossy-source'), ('Lemmings (MP3)/', 'snes', 29, 'lossy-source'), ('Lemmings-SMS/', 'master-system', 22, 'chip-render')]:
    added = [v for v in variants if v['path'].startswith(folder)]
    assert len(added) == count
    assert all(v['port'] == port and v['quality'] == quality for v in added)
for port in ['snes', 'master-system']:
    assert any(t['role'] == 'failure' and any(v['port'] == port for v in t['variants']) for t in catalogue['tracks'])
print('PASS new port coverage, provenance and failure cue classification')

for key in ['beasti', 'beastii', 'awesome', 'menace']:
    track = next(t for t in catalogue['tracks'] if t['id'] == 'classic.'+key)
    assert track['role'] == 'special'
    assert any(v['remix'] == 'mandelsoft' and '/orig_special_music_mandelsoft/' in v['path'] for v in track['variants'])
paintball = [t for t in catalogue['tracks'] if t['game'] == 'paintball']
assert len(paintball) == 5 and all(t['role'] == 'bonus' for t in paintball)
assert all(v['remix'] == 'mandelsoft' for t in paintball for v in t['variants'])
print('PASS special remixes retain their themes; Paintball tracks remain separate bonus entries')
