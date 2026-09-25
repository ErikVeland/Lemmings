# Music timing audit

This tool measures every playable version in the music catalogue. Audio stays local.
The first run downloads the [Beat This!](https://github.com/CPJKU/beat_this) `final0` model.
The game reads the resulting JSON. It does not run Python or the model.

The analysis requires Python 3.11 or later, FFmpeg, and the macOS Swift 6 toolchain.
The recorded run used Python 3.12 on Apple silicon. PyTorch uses MPS when available, or CPU otherwise.

From the project root:

```sh
python3.12 -m venv .build/music-analysis-venv
.build/music-analysis-venv/bin/python -m pip install -r Tools/MusicTiming/requirements.txt
zsh Scripts/analyze-music-timing.sh
zsh Scripts/run-music-timing-tests.sh
zsh Scripts/run-adaptive-dj-playback-tests.sh "$PWD/Sources/Music"
```

Set `MUSIC_TIMING_PYTHON` to use another environment. The script accepts a music directory as its first argument.
That directory must contain `catalogue.json` and every referenced audio file.
The complete scan takes several minutes with MPS. Module WAVs and inference caches stay under `.build/music-timing`.

The script writes:

- `Resources/Music/timing.json`: source hashes, candidate BPM, beat/downbeat timestamps, review reasons, and native tempo maps.
- `Sources/Music/timing.json`: the same data for local playback, when using the default music directory.
- `Documentation/MusicTiming.md`: coverage, method, limitations, and all per-version estimates.

`main.swift` renders one module traversal with the shipped ProTracker renderer.
It follows the renderer's Fxx/Bxx/Dxx clock and identifies the loop start.
It rejects a traversal longer than 600 seconds and reports unsupported timing commands.

`analyze.py` decodes complete recordings to mono 22,050 Hz PCM and detects beats and downbeats.
It keeps the exact four-row tracker clock separate from the estimated musical pulse.
Stable classifications are automated checks, not manual verification.
See the generated report for thresholds and runtime fallbacks.

Inference caches include audio hashes, model hashes, decoder details, and dependency versions.
Module metadata also records the source and renderer hashes. Changed inputs require a fresh render or inference.
To adjust summary thresholds without inference, run:

```sh
.build/music-analysis-venv/bin/python Tools/MusicTiming/analyze.py --summarize-only
cp Resources/Music/timing.json Sources/Music/timing.json
.build/music-analysis-venv/bin/python Tools/MusicTiming/report.py
```

Use `--limit` only with a separate `--output` path for experiments. Partial catalogues must not replace shipping metadata.
Do not change a review flag to stable without correcting and checking the beat and downbeat timestamps.
Replacing only the displayed BPM does not repair a wrong bar phase or a half/double-time interpretation.
