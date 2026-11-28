#!/usr/bin/env python3
"""Prepare and verify the pinned CC0 Lix alternative soundtrack without playback."""
import argparse
from array import array
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile
from urllib.request import urlopen
import wave
import zipfile

ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / 'Resources/AlternativeAssets/music-sources.json'
OUTPUT = ROOT / '.build/alternative-assets/music'
CACHE = ROOT / '.build/dependencies/alternative-music'


def digest(path):
    """Return a file's SHA-256 without loading the complete file into memory."""
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def checked(path, size, sha):
    """Reject missing, linked, changed or unexpectedly sized source files."""
    if path.is_symlink() or not path.is_file() or path.stat().st_size != size or digest(path) != sha:
        raise ValueError(f'File does not match its pinned size and SHA-256: {path}')
    return path


def acquire(path, url, size, sha, offline):
    """Download only the exact pinned source, then publish the verified cache file."""
    if path.exists() or path.is_symlink():
        return checked(path, size, sha)
    if offline:
        raise ValueError(f'Missing source cache: {path}. Prepare it without --offline first.')
    if not url.startswith('https://'):
        raise ValueError('Source downloads must use HTTPS.')
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            with urlopen(url, timeout=60) as response:
                if not response.geturl().startswith('https://'):
                    raise ValueError('The source download redirected away from HTTPS.')
                count = 0
                while True:
                    block = response.read(min(1024 * 1024, size + 1 - count))
                    if not block:
                        break
                    stream.write(block)
                    count += len(block)
                    if count > size:
                        raise ValueError('The source download exceeds its pinned size.')
            stream.close()
            checked(temporary, size, sha)
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)
    return path


def decoder_path(requested):
    """Find the installed libsndfile converter without installing dependencies."""
    candidates = [requested] if requested else [shutil.which('sndfile-convert'),
        '/opt/homebrew/bin/sndfile-convert', '/usr/local/bin/sndfile-convert']
    for value in candidates:
        if value and Path(value).is_file():
            return str(Path(value).resolve())
    raise ValueError('Install libsndfile or pass --converter /path/to/sndfile-convert.')


def run(command):
    """Run a silent file conversion and report a bounded diagnostic on failure."""
    result = subprocess.run(list(map(str, command)), capture_output=True, text=True)
    if result.returncode:
        raise ValueError(f'Audio conversion failed: {result.stderr[-2000:]} {result.stdout[-1000:]}')
    return result.stdout


def audio_info(path, converter, scratch):
    """Decode the complete file and check its frame count and non-silent PCM signal."""
    description = run([Path(converter).with_name('sndfile-info'), path])
    if path.suffix == '.mp3' and 'MPEG-1/2 Audio' not in description:
        raise ValueError(f'The playback copy is not an MP3 file: {path}')
    decoded = scratch / 'verification.wav'
    decoded.unlink(missing_ok=True)
    run([converter, '-pcm16', path, decoded])
    peak = frames_read = 0
    with wave.open(str(decoded), 'rb') as stream:
        channels, width, rate, frames, compression, _ = stream.getparams()
        if width != 2 or compression != 'NONE' or channels not in (1, 2) or rate <= 0 or frames <= 0:
            raise ValueError(f'Unsupported or empty decoded audio: {path}')
        while True:
            data = stream.readframes(65536)
            if not data:
                break
            samples = array('h', data)
            if sys.byteorder != 'little':
                samples.byteswap()
            peak = max(peak, max(map(abs, samples), default=0))
            frames_read += len(data) // (width * channels)
    decoded.unlink()
    if frames_read != frames or peak == 0:
        raise ValueError(f'Incomplete or silent decoded audio: {path}')
    return {'sampleRate': rate, 'channels': channels, 'frames': frames,
            'durationSeconds': round(frames / rate, 6), 'peakPCM16': peak}


def source_path(track):
    """Return the retained original's fixed relative path."""
    return 'Sources/' + track['path']


def playback_path(track):
    """Return the MP3 path without treating alternative music as an original variant."""
    return str(PurePosixPath('Music/Lix') / PurePosixPath(track['path']).relative_to('music').with_suffix('.mp3'))


def credits(lock):
    """Keep upstream authors, source links, licence scope and conversion changes together."""
    lines = [lock['title'], '', lock['scope'], '',
        'Licence: CC0 1.0 Universal', lock['licenceURL'],
        'Upstream licence: ' + lock['source']['licenceURL'],
        'Official music download: ' + lock['source']['archiveURL'],
        'Pinned source archive SHA-256: ' + lock['source']['archiveSHA256'], '',
        'Tracks and creators:']
    lines += [f"- {track['title']} — {track['creator']} ({track['path']})" for track in lock['tracks']]
    lines += ['', 'Changes: Ogg Vorbis originals are retained unchanged. Playback copies are',
        'peak-normalised MP3 files made with libsndfile. This is a lossy conversion.',
        'The minim-mobius credits follow the joint credit in the upstream licence.',
        'Rubix-directory tracks, fonts, code and other music are excluded.',
        'Lix and its creators do not endorse this project.', '']
    return '\n'.join(lines).encode('utf-8')


def file_record(root, relative):
    """Describe one output file for hash-checked packaging."""
    path = root / relative
    return {'path': relative, 'bytes': path.stat().st_size, 'sha256': digest(path)}


def verify(target, lock, converter):
    """Reject changed tracks, missing evidence, linked entries and unlisted files."""
    if target.is_symlink():
        raise ValueError('The soundtrack output must not be a symbolic link.')
    manifest = json.loads((target / 'manifest.json').read_text())
    if (manifest.get('schemaVersion') != 1 or manifest.get('sourceLockSHA256') != digest(LOCK)
            or manifest.get('id') != lock['id'] or manifest.get('licence') != lock['licence']
            or manifest.get('source') != lock['source']):
        raise ValueError('The soundtrack manifest does not match the source lock.')
    expected = {'Credits.txt', 'Licences/Lix-copying.txt'}
    expected.update(source_path(track) for track in lock['tracks'])
    expected.update(playback_path(track) for track in lock['tracks'])
    records = manifest['files']
    if len(records) != len(expected) or {row['path'] for row in records} != expected:
        raise ValueError('The soundtrack manifest contains a missing, duplicate or unapproved file.')
    actual = set()
    for path in target.rglob('*'):
        if path.is_symlink():
            raise ValueError(f'Linked entries are not permitted in a soundtrack pack: {path}')
        if path.is_file():
            actual.add(path.relative_to(target).as_posix())
    if actual != expected | {'manifest.json'}:
        raise ValueError('The soundtrack output contains missing or unlisted files.')
    for row in records:
        checked(target / row['path'], row['bytes'], row['sha256'])
    checked(target / 'Licences/Lix-copying.txt', lock['source']['licenceBytes'], lock['source']['licenceSHA256'])
    if (target / 'Credits.txt').read_bytes() != credits(lock):
        raise ValueError('The soundtrack credits do not match the source lock.')
    if len(manifest['tracks']) != len(lock['tracks']):
        raise ValueError('The soundtrack track list is incomplete.')
    with tempfile.TemporaryDirectory(prefix='music-verify-') as temporary:
        scratch = Path(temporary)
        for track, row in zip(lock['tracks'], manifest['tracks']):
            if row['sourceTrack'] != track or row['playback']['path'] != playback_path(track):
                raise ValueError('The soundtrack track metadata does not match the source lock.')
            checked(target / source_path(track), track['bytes'], track['sha256'])
            info = audio_info(target / playback_path(track), converter, scratch)
            if info != {key: row['playback'][key] for key in info}:
                raise ValueError(f"Decoded playback differs from the manifest: {track['title']}")
            if info['sampleRate'] != 44100 or info['channels'] != 2 or info['frames'] != track['frames']:
                raise ValueError(f"Playback format or duration differs from the source: {track['title']}")
            reference = scratch / 'reference.mp3'
            reference.unlink(missing_ok=True)
            run([converter, '-normalize', target / source_path(track), reference])
            if digest(reference) != row['playback']['sha256']:
                raise ValueError(f"Playback differs from the pinned source conversion: {track['title']}")
    print(f"Verified {len(lock['tracks'])} CC0 tracks, {sum(row['bytes'] for row in records):,} bytes. No audio played.")
    return manifest


def prepare(args, lock, converter):
    """Stage the allowlisted tracks and publish only a fully verified pack."""
    source = lock['source']
    if args.source_archive:
        archive = checked(args.source_archive, source['archiveBytes'], source['archiveSHA256'])
    else:
        archive = acquire(CACHE / f"lix-music-{source['archiveSHA256']}.zip",
            source['archiveURL'], source['archiveBytes'], source['archiveSHA256'], args.offline)
    if args.licence_file:
        licence = checked(args.licence_file, source['licenceBytes'], source['licenceSHA256'])
    else:
        licence = acquire(CACHE / f"copying-{source['licenceSHA256']}.txt",
            source['licenceURL'], source['licenceBytes'], source['licenceSHA256'], args.offline)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='music-stage-', dir=OUTPUT.parent) as temporary:
        staging = Path(temporary) / 'music'
        staging.mkdir()
        rows = []
        with zipfile.ZipFile(archive) as zipped:
            names = zipped.namelist()
            if len(names) != len(set(names)):
                raise ValueError('The source archive contains duplicate entries.')
            for track in lock['tracks']:
                data = zipped.read(track['path'])
                if len(data) != track['bytes'] or hashlib.sha256(data).hexdigest() != track['sha256']:
                    raise ValueError(f"Source track differs from the lock: {track['path']}")
                original = staging / source_path(track)
                original.parent.mkdir(parents=True, exist_ok=True)
                original.write_bytes(data)
                playback = staging / playback_path(track)
                playback.parent.mkdir(parents=True, exist_ok=True)
                run([converter, '-normalize', original, playback])
                info = audio_info(playback, converter, Path(temporary))
                rows.append({'sourceTrack': track, 'playback': dict(file_record(staging, playback_path(track)), **info)})
        (staging / 'Licences').mkdir()
        shutil.copyfile(licence, staging / 'Licences/Lix-copying.txt')
        (staging / 'Credits.txt').write_bytes(credits(lock))
        files = [file_record(staging, path.relative_to(staging).as_posix())
                 for path in sorted(staging.rglob('*')) if path.is_file()]
        info_tool = Path(converter).with_name('sndfile-info')
        help_result = subprocess.run([info_tool, '--help'], capture_output=True, text=True)
        version = next((line for line in (help_result.stdout + help_result.stderr).splitlines()
                        if line.startswith('Using libsndfile-')), None)
        if version is None:
            raise ValueError('The libsndfile version could not be verified.')
        manifest = {'schemaVersion': 1, 'id': lock['id'], 'title': lock['title'], 'licence': lock['licence'],
            'sourceLockSHA256': digest(LOCK), 'source': source,
            'conversion': {'tool': 'sndfile-convert', 'version': version, 'encoding': 'MP3',
                'options': ['-normalize'], 'lossy': True, 'audioPlayed': False},
            'tracks': rows, 'files': files}
        (staging / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
        verify(staging, lock, converter)
        if OUTPUT.exists():
            verify(OUTPUT, lock, converter)
            old = json.loads((OUTPUT / 'manifest.json').read_text())
            if old['files'] != manifest['files']:
                raise ValueError('The new pack differs from the existing verified pack. Keep the prior output for review.')
            print('The existing verified soundtrack is byte-identical. No output changed.')
        else:
            staging.rename(OUTPUT)
            print(f'Prepared {OUTPUT}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true', help='Verify the prepared pack without downloading or changing it.')
    parser.add_argument('--offline', action='store_true', help='Use verified local source caches only.')
    parser.add_argument('--source-archive', type=Path, help='Read the pinned official ZIP from this local path.')
    parser.add_argument('--licence-file', type=Path, help='Read the pinned upstream licence from this local path.')
    parser.add_argument('--converter', help='Use an installed libsndfile sndfile-convert executable.')
    args = parser.parse_args()
    lock = json.loads(LOCK.read_text())
    converter = decoder_path(args.converter)
    if args.verify:
        verify(OUTPUT, lock, converter)
    else:
        prepare(args, lock, converter)
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, OSError, KeyError, zipfile.BadZipFile) as error:
        print(f'FAILED: {error}', file=sys.stderr)
        raise SystemExit(1)
