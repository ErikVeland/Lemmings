#!/usr/bin/env python3
"""Render short drum loops from stable measured bars, without changing source recordings."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
import numpy as np
import torch
from demucs.apply import apply_model
from demucs.pretrained import get_model

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()


def window(row):
    if row['barStatus'] != 'estimated-stable': return None
    grid = row['downbeats']; expected = row['secondsPerBar']
    for index in range(len(grid) - 2):
        start, middle, end = grid[index:index + 3]
        if start >= 2 and end <= row['durationSeconds'] - 1 and end - start <= 12:
            if max(abs((middle-start)/expected-1), abs((end-middle)/expected-1)) <= .04:
                return start, end
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--limit', type=int)
    parser.add_argument('--device', choices=['cpu', 'mps'], default='cpu')
    args = parser.parse_args()
    timing = json.loads((ROOT / 'Resources/Music/timing.json').read_text())
    rows = [r for r in timing['variants'] if not r['tracker']]
    if args.limit: rows = rows[:args.limit]
    output = ROOT / 'Sources/Music/.rhythm'; output.mkdir(exist_ok=True)
    cache = ROOT / '.build/music-rhythm'; cache.mkdir(exist_ok=True)
    torch.set_num_threads(4)
    model = get_model('htdemucs').eval()
    weights = Path(torch.hub.get_dir()) / 'checkpoints/955717e8-8726e21a.th'
    model_hash = sha(weights)
    results = []; failures = []; began = time.monotonic()
    for index, row in enumerate(rows):
        selected = window(row)
        if not selected: continue
        start, end = selected
        source = ROOT / 'Sources/Music' / row['path']
        destination = output / (row['variantID'] + '.m4a')
        record_path = cache / (row['variantID'] + '.json')
        key = dict(sourceSHA256=sha(source), modelSHA256=model_hash, startSeconds=start, endSeconds=end, schemaVersion=1)
        if key['sourceSHA256'] != row['sourceSHA256']: raise ValueError('Stale timing: ' + row['path'])
        try:
            cached = json.loads(record_path.read_text()) if record_path.exists() else None
            if cached and cached['inputs'] == key and destination.exists() and sha(destination) == cached['sha256']:
                results.append(cached); continue
            lead = max(0, start - 1)
            pcm = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(source), '-ss', str(lead),
                '-t', str(end-lead+1), '-ar', '44100', '-ac', '2', '-f', 'f32le', '-'])
            wave = torch.from_numpy(np.frombuffer(pcm, dtype='<f4').reshape(-1, 2).T.copy())
            reference = wave.mean(0); scale = reference.std().clamp(min=1e-8)
            with torch.inference_mode():
                stems = apply_model(model, ((wave-reference.mean())/scale)[None], shifts=0,
                    split=True, overlap=.1, device=args.device, progress=False)
            offset = round((start-lead)*44100); count = round((end-start)*44100)
            drums = (stems[0, model.sources.index('drums')].cpu() * scale).numpy()[:, offset:offset+count].copy()
            rms = float(np.sqrt(np.mean(drums**2)))
            mix_rms = float(torch.sqrt(torch.mean(wave[:, offset:offset+count]**2)))
            if rms < .0001 or rms / max(mix_rms, .0001) < .04: continue
            drums *= min(1, .98 / max(.98, float(np.max(np.abs(drums)))))
            fade = min(220, count // 4)
            drums[:, :fade] *= np.linspace(0, 1, fade)
            drums[:, -fade:] *= np.linspace(1, 0, fade)
            info = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'a:0',
                '-show_entries', 'stream=sample_rate,channels', '-of', 'json', str(source)]))['streams'][0]
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', '44100', '-ac', '2', '-i', '-',
                '-ar', info['sample_rate'], '-ac', str(info['channels']), '-c:a', 'alac', '-sample_fmt', 's16p', str(destination)],
                input=drums.T.astype('<f4').tobytes(), check=True)
            record = dict(variantID=row['variantID'], path=row['path'], sourceSHA256=key['sourceSHA256'],
                loopPath='.rhythm/' + destination.name, sha256=sha(destination), durationSeconds=end-start,
                bars=2, method='demucs-htdemucs-drum-estimate', inputs=key, drumRMS=round(rms, 6))
            record_path.write_text(json.dumps(record, separators=(',', ':')) + '\n')
            results.append(record)
        except Exception as error:
            failures.append(dict(path=row['path'], error=str(error)))
        print(f'{index+1}/{len(rows)} recordings; {len(results)} drum loops; {len(failures)} failures; {time.monotonic()-began:.1f}s', flush=True)
    payload = dict(schemaVersion=1, method='Demucs htdemucs, isolated two-bar drum loops',
        source='https://github.com/facebookresearch/demucs', modelSHA256=model_hash,
        reviewStatus='automated-separation-not-manually-verified', variants=results, failures=failures)
    target = cache / 'partial.json' if args.limit or failures else ROOT / 'Resources/Music/rhythm.json'
    target.write_text(json.dumps(payload, separators=(',', ':')) + '\n')
    if failures: raise SystemExit(1)
    print(f'Wrote {len(results)} loops to {target}', flush=True)


if __name__ == '__main__': main()
