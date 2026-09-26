#!/usr/bin/env python3
"""Build verified optional soundtrack libraries and main/full music bundles."""
import argparse
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
VERSION = '1.6'
# The same encoder, bitrate and cache as Scripts/compact-bundled-music.sh, so a
# library file is byte-identical to the copy inside a full update.
AAC_BITRATE = int(os.environ.get('MUSIC_AAC_BITRATE', '192000'))
AAC_CACHE = Path(os.environ.get('MUSIC_AAC_CACHE', ROOT / '.build/music-aac'))


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, separators=(',', ':')) + '\n').encode()


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def is_main(track, variant):
    return (variant['quality'] == 'native-module' and track['game'] != 'demo') or track['id'] == 'classic.mariarti'


def pack_name(track, variant):
    if variant['quality'] == 'native-module': return 'demos', 'Demos and prototypes'
    if variant['quality'] == 'composer-recording': return 'composer', 'CoLD SToRAGE recordings'
    if variant['remix'] != 'original': return 'remixes', 'Remixes'
    names = {'dos-opl2': 'DOS AdLib', 'dos-opl3': 'DOS OPL3', 'tandy': 'Tandy',
             'x68000': 'Sharp X68000', 'fm-towns': 'FM Towns', 'pc-98': 'PC-98',
             'lynx': 'Atari Lynx', 'archimedes': 'Archimedes', 'nes': 'NES', 'snes': 'SNES',
             'master-system': 'Master System', 'game-boy': 'Game Boy', 'spectrum': 'ZX Spectrum',
             'arcade': 'Arcade', 'mega-drive': 'Mega Drive', 'amiga': 'Amiga recordings'}
    return 'port-' + variant['port'], names.get(variant['port'], variant['port'])


def select(catalogue, predicate):
    tracks = []
    for track in catalogue['tracks']:
        variants = [v for v in track['variants'] if predicate(track, v)]
        if variants: tracks.append(dict(track, variants=variants))
    return dict(catalogue, tracks=tracks)


def metadata(catalogue, timing):
    identities = {v['id'] for t in catalogue['tracks'] for v in t['variants']}
    result = {'Music/catalogue.json': encoded(catalogue), 'Music/timing.json': encoded(dict(timing,
        variants=[r for r in timing['variants'] if r['variantID'] in identities]))}
    rhythm_path = ROOT / 'Resources/Music/rhythm.json'
    if rhythm_path.exists():
        rhythm = json.loads(rhythm_path.read_text())
        result['Music/rhythm.json'] = encoded(dict(rhythm, variants=[r for r in rhythm['variants'] if r['variantID'] in identities]))
    return result


def aac_copy(source_file, sha):
    """Return the 192 kbps AAC copy of an Apple Lossless file. Other files stay as they are."""
    if source_file.suffix.lower() != '.m4a': return source_file
    info = subprocess.run(['afinfo', source_file], capture_output=True, text=True).stdout
    if not any(line.startswith('Data format:') and 'alac' in line for line in info.splitlines()): return source_file
    cached = AAC_CACHE / f'{sha[:40]}-{AAC_BITRATE}.m4a'
    if not cached.is_file() or cached.stat().st_size == 0:
        AAC_CACHE.mkdir(parents=True, exist_ok=True)
        temporary = cached.with_name(cached.name + f'.{os.getpid()}.tmp')
        subprocess.run(['afconvert', '-f', 'm4af', '-d', 'aac', '-b', str(AAC_BITRATE), '-s', '2', '-q', '127',
                        source_file, temporary], check=True)
        temporary.replace(cached)
    return cached


def with_playback(payloads, played):
    """Point timing and rhythm entries at the hashes of the files that ship."""
    for name in ('Music/timing.json', 'Music/rhythm.json'):
        if name not in payloads: continue
        index = json.loads(payloads[name])
        for row in index['variants']:
            row.pop('playbackSHA256', None)
            if row['path'] in played and played[row['path']] != row['sourceSHA256']:
                row['playbackSHA256'] = played[row['path']]
        payloads[name] = encoded(index)
    return payloads


def rhythm_files(payloads):
    return json.loads(payloads.get('Music/rhythm.json', b'{"variants":[]}'))['variants']


def build_packs(source, catalogue, timing, output, base_url):
    output.mkdir(parents=True, exist_ok=True)
    groups = defaultdict(set)
    labels = {}
    for track in catalogue['tracks']:
        for variant in track['variants']:
            if is_main(track, variant): continue
            identity, label = pack_name(track, variant)
            groups[identity].add(variant['id']); labels[identity] = label
    hashes = {r['variantID']: r['sourceSHA256'] for r in timing['variants']}
    optional = [(source / v['path'], v['id']) for t in catalogue['tracks'] for v in t['variants'] if v['id'] in set().union(*groups.values())]
    def prepare(item):
        source_file, identity = item
        if digest(source_file) != hashes[identity]: raise ValueError(f'Stale music timing: {source_file}')
        shipped = aac_copy(source_file, hashes[identity])
        return identity, shipped, digest(shipped)
    with ThreadPoolExecutor(os.cpu_count()) as pool: shipped = {i: (f, h) for i, f, h in pool.map(prepare, optional)}
    packs = []
    for identity, ids in sorted(groups.items()):
        subset = select(catalogue, lambda t, v: v['id'] in ids)
        played = {v['path']: shipped[v['id']][1] for t in subset['tracks'] for v in t['variants']}
        payloads = with_playback(metadata(subset, timing), played)
        files = []
        archive = output / f'{identity}.zip'
        with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
            for track in subset['tracks']:
                for variant in track['variants']:
                    shipped_file, sha = shipped[variant['id']]
                    name = 'Music/' + variant['path']
                    # Fixed timestamps make identical libraries byte-for-byte reproducible.
                    info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
                    # Encoded audio does not deflate. Store it to save packing time.
                    info.compress_type = zipfile.ZIP_STORED if shipped_file.suffix.lower() in ('.m4a', '.mp3', '.ogg') else zipfile.ZIP_DEFLATED
                    with shipped_file.open('rb') as reader, zipped.open(info, 'w') as writer:
                        shutil.copyfileobj(reader, writer)
                    files.append(dict(path=name, bytes=shipped_file.stat().st_size, sha256=sha))
            for rhythm in rhythm_files(payloads):
                loop = source / rhythm['loopPath']
                if digest(loop) != rhythm['sha256']: raise ValueError(f'Stale drum loop: {loop}')
                name = 'Music/' + rhythm['loopPath']
                info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0)); info.compress_type = zipfile.ZIP_DEFLATED
                zipped.writestr(info, loop.read_bytes())
                files.append(dict(path=name, bytes=loop.stat().st_size, sha256=rhythm['sha256']))
            for name, data in payloads.items():
                info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0)); info.compress_type = zipfile.ZIP_DEFLATED
                zipped.writestr(info, data)
                files.append(dict(path=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
        packs.append(dict(id=identity, title=labels[identity], url=base_url.rstrip('/') + '/' + archive.name,
            bytes=archive.stat().st_size, sha256=digest(archive), trackCount=len(ids), files=files))
        print(f'{labels[identity]}: {len(ids)} versions, {archive.stat().st_size / 1_000_000:.1f} MB', flush=True)
    index = dict(schemaVersion=1, version=VERSION, packs=packs)
    (output / 'libraries.json').write_bytes(encoded(index))
    return index


def bundle(source, catalogue, timing, target, scope, game, libraries):
    if target.name != 'Music' or target.is_symlink() or target.resolve() == source.resolve():
        raise ValueError('The output must be a generated Music directory, separate from the source')
    available = select(catalogue, lambda t, v: game == 'all' or t['game'] == game)
    selected = select(available, lambda t, v: scope == 'full' or is_main(t, v))
    # This directory belongs to the generated app bundle. Clear old optional files on a main rebuild.
    if target.exists(): shutil.rmtree(target)
    target.mkdir(parents=True)
    hashes = {r['variantID']: r['sourceSHA256'] for r in timing['variants']}
    count = size = 0
    for track in selected['tracks']:
        for variant in track['variants']:
            original = source / variant['path']
            if digest(original) != hashes[variant['id']]: raise ValueError(f'Stale music timing: {original}')
            destination = target / variant['path']; destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(original, destination)
            count += 1; size += original.stat().st_size
    for rhythm in rhythm_files(metadata(selected, timing)):
        original = source / rhythm['loopPath']; destination = target / rhythm['loopPath']
        if digest(original) != rhythm['sha256']: raise ValueError(f'Stale drum loop: {original}')
        destination.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(original, destination)
    for path, data in metadata(available, timing).items(): (target / Path(path).name).write_bytes(data)
    shutil.copy2(libraries, target / 'libraries.json')
    (target / 'bundle.json').write_bytes(encoded(dict(version=VERSION, scope=scope, game=game, trackCount=count, bytes=size)))
    print(f'{scope}: {count} versions, {size / 1_000_000:.1f} MB')


def playback(target):
    """Record the hash of each re-encoded bundled file, so timing and rhythm still match it."""
    changed = 0
    for name in ('timing.json', 'rhythm.json'):
        path = target / name
        if not path.exists(): continue
        index = json.loads(path.read_text())
        for row in index['variants']:
            bundled = target / row['path']
            if not bundled.is_file(): continue
            sha = digest(bundled)
            row.pop('playbackSHA256', None)
            if sha != row['sourceSHA256']: row['playbackSHA256'] = sha; changed += 1
        path.write_bytes(encoded(index))
    print(f'playback: {changed} re-encoded entries')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['packs', 'bundle', 'playback'])
    parser.add_argument('--source', type=Path, default=ROOT / 'Sources/Music')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--base-url', default='https://github.com/ErikVeland/Lemmings/releases/download/music-1.6')
    parser.add_argument('--scope', choices=['main', 'full'], default='main')
    parser.add_argument('--game', choices=['all', 'lemmings2', 'lemmings3'], default='all')
    parser.add_argument('--libraries', type=Path, default=ROOT / 'Resources/Music/libraries.json')
    args = parser.parse_args()
    catalogue = json.loads((ROOT / 'Resources/Music/catalogue.json').read_text())
    timing = json.loads((ROOT / 'Resources/Music/timing.json').read_text())
    if args.command == 'playback': return playback(args.output)
    if args.command == 'packs': build_packs(args.source, catalogue, timing, args.output, args.base_url)
    else: bundle(args.source, catalogue, timing, args.output, args.scope, args.game, args.libraries)


if __name__ == '__main__': main()
