#!/usr/bin/env python3
"""Measure each playable version locally. No audio leaves this machine."""
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import importlib.metadata
import json
from pathlib import Path
import subprocess
import time

import numpy as np
import torch
from beat_this.inference import Audio2Frames
from beat_this.model.postprocessor import Postprocessor

ROOT = Path(__file__).resolve().parents[2]
SAMPLE_RATE = 22050
FPS = 50


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def decode(path):
    result = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le',
                             '-ac', '1', '-ar', str(SAMPLE_RATE), '-'], capture_output=True, check=True)
    return np.frombuffer(result.stdout, dtype='<f4').copy()


def summarize(raw, module=None):
    beats = np.array(raw['beats'], dtype=float)
    downbeats = np.array(raw['downbeats'], dtype=float)
    intervals = np.diff(beats)
    reasons = []
    bpm = low = high = regularity = 0.0
    coverage = float((beats[-1] - beats[0]) / raw['durationSeconds']) if len(beats) > 1 else 0
    if len(intervals) >= 4:
        period = float(np.median(intervals))
        regularity = float(np.mean(np.abs(intervals / period - 1) <= 0.10))
        # Longer spans reduce the model's 20 ms timestamp quantisation.
        widths = min(16, max(1, len(intervals) // 4))
        local = (beats[widths:] - beats[:-widths]) / widths
        local = local[(local >= period * 0.7) & (local <= period * 1.3)]
        if len(local):
            bpm = 60 / float(np.median(local))
            low, high = [float(v) for v in np.percentile(60 / local, [10, 90])]
    if len(beats) < 32 or raw['durationSeconds'] < 12: reasons.append('short-cue-or-too-few-beats')
    if coverage < 0.8: reasons.append('incomplete-beat-coverage')
    if regularity < 0.92: reasons.append('irregular-or-missing-beats')
    if bpm and (high - low) / bpm > 0.04: reasons.append('tempo-varies-or-detector-disagrees')
    if not bpm: reasons.append('no-reliable-pulse')
    positions = np.searchsorted(beats, downbeats)
    bar_counts = np.diff(positions)
    meter, agreement = None, 0.0
    if len(bar_counts):
        candidate, count = Counter(int(x) for x in bar_counts).most_common(1)[0]
        agreement = count / len(bar_counts)
        if 2 <= candidate <= 12: meter = candidate
    bar_reasons = list(reasons)
    if meter is None or len(bar_counts) < 8 or agreement < 0.9:
        bar_reasons.append('bar-count-or-downbeat-ambiguous')
    tracker = None
    if module:
        tracker = module
        if module['unsupportedTimingEffects']:
            reasons.append('module-uses-timing-effects-not-supported-by-player')
            bar_reasons.append('module-uses-timing-effects-not-supported-by-player')
        if len(module['segments']) > 1:
            reasons.append('module-has-tempo-changes')
            bar_reasons.append('module-has-tempo-changes')
        # A regular neural pulse can still disagree with the source's row clock.
        if bpm and module['segments']:
            ratio = bpm / module['segments'][0]['fourRowBPM']
            if min(abs(ratio / factor - 1) for factor in (0.5, 1, 2)) > 0.03:
                reasons.append('detected-pulse-disagrees-with-tracker-clock')
                bar_reasons.append('detected-pulse-disagrees-with-tracker-clock')
        # This exact tracker clock is not a declaration of musical metre.
        if bpm and module['segments']:
            tracker = dict(module)
            tracker['detectedBeatsPerFourRows'] = round(bpm / module['segments'][0]['fourRowBPM'], 4)
    return dict(baseBPM=round(bpm, 3) if bpm else None,
        bpmRange=[round(low, 3), round(high, 3)] if bpm else None,
        beatsPerBar=meter, secondsPerBar=round(meter * 60 / bpm, 5) if meter and bpm else None,
        firstBeatSeconds=float(beats[0]) if len(beats) else None,
        firstDownbeatSeconds=float(downbeats[0]) if len(downbeats) else None,
        beatCount=len(beats), completeBarCount=max(0, len(downbeats) - 1),
        beatRegularity=round(regularity, 4), beatCoverage=round(coverage, 4),
        barAgreement=round(agreement, 4),
        bpmStatus='estimated-stable' if not reasons else 'needs-review',
        barStatus='estimated-stable' if not bar_reasons else 'needs-review',
        reviewReasons=sorted(set(reasons + bar_reasons)),
        tracker=tracker, beats=raw['beats'], downbeats=raw['downbeats'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--music', type=Path, default=ROOT / 'Sources/Music')
    parser.add_argument('--cache', type=Path, default=ROOT / '.build/music-timing')
    parser.add_argument('--output', type=Path, default=ROOT / 'Resources/Music/timing.json')
    parser.add_argument('--model', default='final0')
    parser.add_argument('--limit', type=int)
    parser.add_argument('--summarize-only', action='store_true')
    args = parser.parse_args()
    if args.limit and args.output.resolve() == (ROOT / 'Resources/Music/timing.json').resolve():
        parser.error('--limit requires a separate --output path')
    catalogue = json.loads((args.music / 'catalogue.json').read_text())
    versions = [(track, version) for track in catalogue['tracks'] for version in track['variants']]
    if args.limit: versions = versions[:args.limit]
    cache = args.cache / args.model
    cache.mkdir(parents=True, exist_ok=True)
    torch.set_num_threads(4)
    device = 'mps' if torch.backends.mps.is_available() else 'cpu'
    model = None
    checkpoint = Path(torch.hub.get_dir()) / 'checkpoints' / ('beat_this-' + args.model + '.ckpt')
    if not checkpoint.exists():
        if args.summarize_only: raise ValueError('The model checkpoint is unavailable')
        model = Audio2Frames(checkpoint_path=args.model, device=device)
    inference = dict(modelSHA256=digest(checkpoint), sampleRate=SAMPLE_RATE,
        postprocessor='minimal', timestampResolutionSeconds=1/FPS,
        dependencies={name: importlib.metadata.version(name)
                      for name in ('beat-this', 'torch', 'torchaudio', 'numpy', 'scipy', 'soxr')},
        decoder=subprocess.check_output(['ffmpeg', '-version'], text=True).splitlines()[0])
    renderer_hash = hashlib.sha256((ROOT / 'Sources/NxlvKit/ProTrackerModule.swift').read_bytes()
                                  + (ROOT / 'Tools/MusicTiming/main.swift').read_bytes()).hexdigest()
    post = Postprocessor(type='minimal')
    results, failures = [], []
    started = time.monotonic()
    for index, (track, version) in enumerate(versions):
        path = args.music / version['path']
        cached = cache / (version['id'] + '.json')
        try:
            sha = digest(path)
            module = None
            audio = path
            if path.suffix.lower() == '.mod':
                module = json.loads((args.cache / 'modules' / (version['id'] + '.json')).read_text())
                if module.get('sourceSHA256') != sha or module.get('rendererSHA256') != renderer_hash:
                    raise ValueError('Stale module render. Run the native renderer first.')
                audio = args.cache / 'modules' / (version['id'] + '.wav')
            key = dict(inference, audioSHA256=digest(audio))
            raw = json.loads(cached.read_text()) if cached.exists() else None
            if not raw or raw['sourceSHA256'] != sha or raw.get('inference') != key:
                if args.summarize_only: raise ValueError('Missing or stale inference cache')
                if model is None: model = Audio2Frames(checkpoint_path=args.model, device=device)
                signal = decode(audio)
                if not len(signal): raise ValueError('Empty decoded audio')
                logits = model(signal, SAMPLE_RATE)
                beats, downbeats = post(*logits)
                raw = dict(sourceSHA256=sha, inference=key, durationSeconds=len(signal) / SAMPLE_RATE,
                    beats=[round(float(x), 3) for x in beats],
                    downbeats=[round(float(x), 3) for x in downbeats])
                cached.write_text(json.dumps(raw, separators=(',', ':')) + '\n')
            result = dict(variantID=version['id'], trackID=track['id'], title=track['title'],
                          path=version['path'], game=track['game'], port=version['port'], role=track['role'],
                          sourceSHA256=sha, durationSeconds=round(raw['durationSeconds'], 5),
                          **summarize(raw, module))
            results.append(result)
        except Exception as error:
            failures.append(dict(variantID=version['id'], path=version['path'], error=str(error)))
        if index % 10 == 0 or index == len(versions) - 1:
            print(f'{index+1}/{len(versions)} analysed; {len(failures)} failures; {time.monotonic()-started:.1f}s', flush=True)
    payload = dict(schemaVersion=1, generatedAt=datetime.now(timezone.utc).isoformat(),
        method=dict(name='Beat This! + native ProTracker row clock', model=args.model,
                    beatThisVersion=importlib.metadata.version('beat-this'), timestampResolutionSeconds=1/FPS,
                    modelSHA256=inference['modelSHA256'], dependencies=inference['dependencies'], decoder=inference['decoder'],
                    moduleRendererSHA256=digest(ROOT / 'Sources/NxlvKit/ProTrackerModule.swift'),
                    moduleAuditRendererSHA256=renderer_hash,
                    reviewStatus='automated-estimates-not-manually-verified',
                    source='https://github.com/CPJKU/beat_this'),
        catalogueSHA256=digest(args.music / 'catalogue.json'), variants=results, failures=failures)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    output = args.output.with_suffix('.failed.json') if failures else args.output
    output.write_text(json.dumps(payload, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(Counter(r['bpmStatus'] for r in results), Counter(r['barStatus'] for r in results), flush=True)
    if failures: raise SystemExit(1)


if __name__ == '__main__':
    main()
