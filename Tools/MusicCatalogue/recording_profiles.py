#!/usr/bin/env python3
"""Measure constant music trims and recover exact loops from verified VGM conversions."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import gzip
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[2]
TARGET_LUFS = -20.0
# Leave room for the deck's shelves, nuke filter and crossfade.
PEAK_CEILING_DBTP = -6.0
MAX_BOOST_DB = 6.0


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for part in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(part)
    return digest.hexdigest()


def source_loop(source, output, conversion, info):
    """Only an unchanged ALAC output of the pinned two-loop renderer can inherit a loop."""
    if source.suffix.lower() not in ('.vgz', '.vgm'):
        return None, 'unverified-source-loop'
    if not conversion:
        return None, 'missing-conversion-provenance'
    if sha(source) != conversion['source_sha256'] or sha(output) != conversion['output_sha256']:
        raise ValueError(f'Stale VGM conversion: {source}')
    if info['codec_name'] != 'alac' or int(info['sample_rate']) != 44100:
        raise ValueError(f'VGM source frames require the pinned lossless render: {output}')
    data = source.read_bytes()
    if data[:2] == b'\x1f\x8b': data = gzip.decompress(data)
    if len(data) < 0x24 or data[:4] != b'Vgm ': raise ValueError(f'Invalid VGM header: {source}')
    total, offset, loop = struct.unpack_from('<III', data, 0x18)
    if total <= 0: raise ValueError(f'Missing VGM duration: {source}')
    if not offset and not loop: return None, 'source-has-no-loop'
    if not offset or not 0 < loop <= total or offset + 0x1c >= len(data):
        raise ValueError(f'Invalid VGM loop: {source}')
    expected = (total + loop) / 44100 + 8
    if abs(float(info['duration']) - expected) > 0.1:
        raise ValueError(f'VGM render duration mismatch: {output}')
    return dict(startFrame=total-loop, endFrame=total,
                sourceSHA256=conversion['source_sha256']), 'verified-vgm'


def measure(path, end_frame=None):
    trim = f'atrim=end_sample={end_frame},' if end_frame is not None else ''
    # Decode to the null muxer. This never opens an audio device or rewrites a recording.
    command = ['nice', '-n', '19', 'ffmpeg', '-hide_banner', '-nostdin', '-threads', '1',
               '-i', str(path), '-map', '0:a:0', '-af', trim+'ebur128=peak=true', '-f', 'null', '-']
    result = subprocess.run(command, capture_output=True, text=True, check=True)
    summary = result.stderr.rsplit('Summary:', 1)[-1]
    loudness = re.search(r'Integrated loudness:\s*I:\s*(-?[\d.]+) LUFS', summary)
    peak = re.search(r'True peak:\s*Peak:\s*(-?[\d.]+) dBFS', summary)
    if not loudness or not peak: raise ValueError(f'No finite loudness measurement: {path}')
    integrated, true_peak = float(loudness[1]), float(peak[1])
    if not math.isfinite(integrated) or not math.isfinite(true_peak) or integrated <= -70:
        raise ValueError(f'Silent or invalid recording: {path}')
    gain = min(MAX_BOOST_DB, TARGET_LUFS-integrated, PEAK_CEILING_DBTP-true_peak)
    return dict(integratedLUFS=integrated, truePeakDBTP=true_peak, gainDB=round(gain, 3))


def build(music, catalogue_path, cache, jobs):
    catalogue = json.loads(catalogue_path.read_text())
    report = json.loads((music/'conversion-report.json').read_text())
    if report.get('vgm_loops') != 2 or report.get('vgm_fade_seconds') != 8:
        raise ValueError('Unsupported VGM conversion settings')
    conversions = {row['output']: row for row in report['tracks']}
    variants = [v for t in catalogue['tracks'] for v in t['variants'] if not v['path'].endswith('.mod')]
    cache.mkdir(parents=True, exist_ok=True)

    def profile(variant):
        path = music/variant['path']
        digest = sha(path)
        info = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'a:0',
            '-show_streams', '-of', 'json', str(path)]))['streams'][0]
        loop, status = source_loop(music/variant['sourcePath'], path, conversions.get(variant['path']), info)
        if loop: loop['sourcePath'] = variant['sourcePath']
        end = loop['endFrame'] if loop else None
        key = f'{digest}-{end or "whole"}-ebur128-truepeak.json'
        cached = cache/key
        values = json.loads(cached.read_text()) if cached.exists() else measure(path, end)
        if not cached.exists(): cached.write_text(json.dumps(values)+'\n')
        # The cache owns measurements, not the mix policy. A changed target must
        # always recompute its constant trim from the original measured levels.
        values['gainDB'] = round(min(MAX_BOOST_DB, TARGET_LUFS-values['integratedLUFS'],
                                    PEAK_CEILING_DBTP-values['truePeakDBTP']), 3)
        return dict(variantID=variant['id'], path=variant['path'], sourceSHA256=digest,
                    sampleRate=float(info['sample_rate']),
                    frameCount=round(float(info['duration'])*float(info['sample_rate'])),
                    loop=loop, loopStatus=status, **values)

    with ThreadPoolExecutor(max_workers=jobs) as pool:
        rows = []
        for row in pool.map(profile, variants):
            rows.append(row)
            if len(rows) % 25 == 0: print(f'{len(rows)}/{len(variants)} recordings measured', flush=True)
    return dict(schemaVersion=1, method=dict(loudness='FFmpeg ebur128 integrated LUFS and true peak',
        targetLUFS=TARGET_LUFS, peakCeilingDBTP=PEAK_CEILING_DBTP, maximumBoostDB=MAX_BOOST_DB,
        trim='Constant gain only; no compression. VGM measurements omit repeated pass and fade.',
        loops='Pinned VGM total/loop sample counts at 44100 Hz; intro plays once.'),
        variants=sorted(rows, key=lambda row: row['path']))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--music', type=Path, default=ROOT/'Sources/Music')
    parser.add_argument('--catalogue', type=Path, default=ROOT/'Resources/Music/catalogue.json')
    parser.add_argument('--cache', type=Path, default=ROOT/'.build/music-playback')
    parser.add_argument('--output', type=Path, default=ROOT/'Resources/Music/recording-playback.json')
    parser.add_argument('--jobs', type=int, default=2)
    args = parser.parse_args()
    payload = build(args.music, args.catalogue, args.cache, args.jobs)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2)+'\n')
    (args.music/'recording-playback.json').write_bytes(args.output.read_bytes())
    print(f'Wrote {len(payload["variants"])} profiles; '
          f'{sum(row["loop"] is not None for row in payload["variants"])} verified source loops', flush=True)


if __name__ == '__main__': main()
