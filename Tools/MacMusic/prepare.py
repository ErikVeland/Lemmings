#!/usr/bin/env python3
"""Render supplied Macintosh SONG/INST/MIDI resources without an audio device."""
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import wave

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT / 'Tools/MacArtwork'))
from prepare import resources


def digest(data):
    return hashlib.sha256(data).hexdigest()


def run(args, log):
    with log.open('ab') as stream:
        subprocess.run([str(x) for x in args], stdout=stream, stderr=stream, check=True)


def pcm_copy(source, destination):
    """Preserve dynamics, with one constant trim if the float mix exceeds headroom."""
    data = source.read_bytes()
    if data[:4] != b'RIFF' or data[8:12] != b'WAVE':
        raise ValueError('Renderer did not produce a WAVE file')
    if struct.unpack_from('<I', data, 4)[0] + 8 != len(data):
        raise ValueError('Invalid WAVE size')
    offset = 12
    fmt = payload = None
    while offset + 8 <= len(data):
        tag, size = struct.unpack_from('<4sI', data, offset)
        chunk = data[offset + 8:offset + 8 + size]
        if len(chunk) != size:
            raise ValueError('Truncated WAVE chunk')
        if tag == b'fmt ':
            fmt = struct.unpack_from('<HHIIHH', chunk)
        elif tag == b'data':
            payload = chunk
        offset += 8 + size + (size & 1)
    if not fmt or fmt != (3, 2, 22050, 176400, 8, 32) or not payload or len(payload) % 8:
        raise ValueError('Unexpected renderer format')
    samples = array.array('f', payload)
    if sys.byteorder != 'little':
        samples.byteswap()
    if not all(math.isfinite(x) for x in samples):
        raise ValueError('Non-finite sample')
    peak = max(abs(x) for x in samples)
    if peak <= 0:
        raise ValueError('Silent Macintosh song')
    gain = min(1.0, 0.95 / peak)
    pcm = array.array('h', (round(x * gain * 32767) for x in samples))
    if sys.byteorder != 'little':
        pcm.byteswap()
    with wave.open(str(destination), 'wb') as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(22050)
        output.writeframes(pcm.tobytes())
    return {'frames': len(samples) // 2, 'sampleRate': 22050, 'peak': peak, 'gain': gain}


def prepare(output, tools):
    build = PROJECT / '.build/mac-artwork'
    # MacArtwork preparation extracts these from the supplied disk images first.
    sources = {
        'classic': build / 'original/Music.rsrc',
        'ohno': build / 'ohno/Music.rsrc',
        'xmas': PROJECT / "Sources/Ports/mac_extracted/Holiday_Lem93_94/Extras/X-Mas Demo '92/Music/..namedfork/rsrc",
    }
    cache = PROJECT / '.build/mac-music'
    cache.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    version = (PROJECT / '.build/mac-reference/versions').read_text().strip()
    report = {'version': 1, 'renderer': version, 'songs': [], 'limits': [
        'SoundMusicSys hardware voice stealing is not emulated.',
        'The Holiday 1994 installer contains Oh No! tunes. Seasonal playback uses verified Xmas 1992 resources.',
        'Listening and an original-hardware comparison require a separate test.',
    ]}
    for game, source in sources.items():
        raw = source.read_bytes()
        key = digest(raw + version.encode() + Path(__file__).read_bytes())
        folder = cache / game / key
        folder.mkdir(parents=True, exist_ok=True)
        fork = folder / 'Music.rsrc'
        fork.write_bytes(raw)
        decoded = folder / 'decoded'
        if not decoded.exists():
            run([tools / 'resource_dasm', '--data-fork', fork, decoded], folder / 'decode.log')
        songs = [(i, n, d) for t, i, n, d in resources(raw) if t == 'SONG']
        if len(songs) != {'classic': 21, 'ohno': 6, 'xmas': 4}[game]:
            raise ValueError(f'Incomplete Macintosh {game} song bank')
        destination = output / game
        destination.mkdir(exist_ok=True)
        expected = set()
        for song_id, name, data in songs:
            title = name.lower().replace(' ', '')
            expected.add(title + '.m4a')
            env_files = list(decoded.glob(f'Music.rsrc_SONG_{song_id}_*_smssynth_env.json'))
            if len(env_files) != 1:
                raise ValueError(f'Missing SONG environment {game}/{song_id}')
            env = json.loads(env_files[0].read_text())
            if not (decoded / env['sequence_filename']).is_file() or any(
                not (decoded / r['filename']).is_file()
                for instrument in env['instruments'] for r in instrument['regions']
            ):
                raise ValueError(f'Missing Macintosh sequence or instrument {game}/{song_id}')
            rendered = folder / (title + '.wav')
            pcm = folder / (title + '-pcm.wav')
            metadata = folder / (title + '.json')
            lossless = folder / (title + '.m4a')
            if not lossless.exists() or not metadata.exists():
                run([tools / 'smssynth', '--json-environment=' + str(env_files[0]), '--quiet',
                     '--sample-rate=22050', '--resample-method=hold', '--time-limit=600',
                     '--output-filename=' + str(rendered)], folder / (title + '-render.log'))
                info = pcm_copy(rendered, pcm)
                if info['frames'] >= 600 * info['sampleRate']:
                    raise ValueError(f'Macintosh song exceeded render limit: {game}/{name}')
                temporary = folder / (title + '-pending.m4a')
                run(['/usr/bin/afconvert', '-f', 'm4af', '-d', 'alac', pcm, temporary], folder / 'convert.log')
                temporary.replace(lossless)
                metadata.write_text(json.dumps(info))
            info = json.loads(metadata.read_text())
            shutil.copyfile(lossless, destination / lossless.name)
            report['songs'].append(dict(info, game=game, name=name, songID=song_id,
                sourceSHA256=digest(raw), songSHA256=digest(data), path=f'{game}/{lossless.name}',
                sha256=digest(lossless.read_bytes())))
        for file in destination.glob('*.m4a'):
            if file.name not in expected:
                file.unlink()
    (output / 'manifest.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Prepared {len(report["songs"])} original Macintosh arrangements in {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--tools', type=Path, required=True)
    args = parser.parse_args()
    prepare(args.output.resolve(), args.tools.resolve())
