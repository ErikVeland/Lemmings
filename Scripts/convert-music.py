#!/usr/bin/env python3
"""Render unsupported soundtrack files beside their originals as Apple Lossless."""
import argparse
import concurrent.futures
import gzip
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import tempfile


def run(args):
    result = subprocess.run(list(map(str, args)), capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.decode(errors='replace')[-4000:])
    return result.stdout


def convert(source, root, renderer, verify_existing=False):
    target = source.with_suffix('.m4a')
    if target.exists() and not verify_existing:
        raise ValueError(f'Refusing to overwrite {target}')
    expected = None
    if source.suffix.lower() in {'.vgz', '.vgm'}:
        data = source.read_bytes()
        if data[:2] == b'\x1f\x8b': data = gzip.decompress(data)
        if len(data) < 0x24 or data[:4] != b'Vgm ':
            raise ValueError(f'Invalid VGM header: {source}')
        samples, _, loop_samples = struct.unpack_from('<III', data, 0x18)
        expected = (samples + loop_samples) / 44100 + (8 if loop_samples else 0)
        if not samples:
            raise ValueError(f'Missing VGM duration: {source}')
    with tempfile.TemporaryDirectory(prefix='music-render-') as scratch:
        audio = source
        if expected is not None:
            audio = Path(scratch) / 'render.wav'
            run([renderer, '--loops', '2', '--fade', '8', '--samplerate', '44100', '--bps', '16', source, audio])
        encoded = Path(scratch) / 'encoded.m4a'
        run(['ffmpeg', '-v', 'error', '-nostdin', '-i', audio, '-map', '0:a:0', '-c:a', 'alac',
             '-metadata', f'title={source.stem}', '-metadata', f'album={source.parent.name}', encoded])
        info = json.loads(run(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', encoded]))
        duration = float(info['format']['duration'])
        if duration <= 0 or (expected is not None and abs(duration - expected) > 0.1):
            raise ValueError(f'Duration mismatch: {source}: {duration} versus {expected}')
        # Decode the complete result. Check that each rendered track contains signal.
        pcm = run(['ffmpeg', '-v', 'error', '-nostdin', '-i', encoded, '-f', 'f32le', '-ac', '1', '-ar', '8000', '-'])
        samples = [v[0] for v in struct.iter_unpack('<f', pcm)]
        peak = max(map(abs, samples), default=0)
        if not math.isfinite(peak) or peak == 0:
            raise ValueError(f'Silent or invalid render: {source}')
        # Publish only after validation, without overwriting a concurrent output.
        if target.exists() and verify_existing:
            # Adopt only sample-identical outputs. Never replace existing audio.
            def pcm_hash(path):
                return hashlib.sha256(run(['ffmpeg','-v','error','-nostdin','-i',path,
                    '-map','0:a:0','-f','s32le','-'])).hexdigest()
            if pcm_hash(target) != pcm_hash(encoded):
                raise ValueError(f'Existing output differs from the source render: {target}')
        else:
            with target.open('xb') as output:
                output.write(encoded.read_bytes())
    return {'source': str(source.relative_to(root)), 'output': str(target.relative_to(root)),
            'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'output_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
            'duration_seconds': duration, 'peak_mono': peak, 'codec': info['streams'][0]['codec_name']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--renderer', type=Path, required=True)
    parser.add_argument('--jobs', type=int, default=4)
    parser.add_argument('--verify-existing', action='store_true', help='Adopt existing files only when their decoded samples match a fresh render.')
    args = parser.parse_args()
    root = args.root.resolve()
    sources = sorted(p for p in root.rglob('*') if not p.is_symlink() and 'By Track' not in p.parts and p.suffix.lower() in {'.vgz', '.vgm', '.ogg'})
    report_path = root / 'conversion-report.json'
    previous = json.loads(report_path.read_text()) if report_path.exists() else {'tracks': []}
    known = {row['source']: row for row in previous['tracks']}
    pending = []
    rows = []
    for source in sources:
        row = known.get(str(source.relative_to(root)))
        target = source.with_suffix('.m4a')
        if row and target.exists() and hashlib.sha256(source.read_bytes()).hexdigest() == row['source_sha256'] and hashlib.sha256(target.read_bytes()).hexdigest() == row['output_sha256']:
            rows.append(row)
        else:
            pending.append(source)
    failures = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(convert, p, root, args.renderer.resolve(), args.verify_existing): p for p in pending}
        for future in concurrent.futures.as_completed(futures):
            try:
                row = future.result()
                rows.append(row)
                print(f'[{len(rows)}/{len(sources)}] {row["output"]}', flush=True)
            except Exception as error:
                failures.append({'source': str(futures[future].relative_to(root)), 'error': str(error)})
                print(f'FAILED: {failures[-1]}', flush=True)
            report_path.write_text(json.dumps({'vgm_loops': 2, 'vgm_fade_seconds': 8,
                'tracks': sorted(rows, key=lambda row: row['source']), 'failures': failures}, indent=2) + '\n')
    print(f'{len(rows)} verified conversions; {len(failures)} failures.', flush=True)
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
