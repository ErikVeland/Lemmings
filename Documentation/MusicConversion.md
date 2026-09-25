# Music conversion

`Sources/Music` retains its original files. Unsupported VGZ/VGM and OGG files receive an Apple Lossless `.m4a` beside the source, with the same base name. Existing WAV, MP3, M4A and MOD files already work with the app and do not need conversion.

VGZ is gzip-compressed VGM. Decompression exposes sound-chip commands, not PCM audio. [libvgm](https://github.com/ValleyBell/libvgm) renders these commands before FFmpeg encodes the resulting samples as Apple Lossless. OGG conversion preserves the decoded audio but cannot recover detail lost in the original lossy encoding.

## Conversion result — 25 September 2026

- Converted 304 VGZ files and 23 OGG files, with zero failures.
- Generated 327 M4A files: 867.3 minutes, 3.27 GB in total.
- All outputs passed complete FFmpeg decoding, signal and duration checks.
- Apple AVAudioFile decoded all 341 recordings completely, with zero failures. This checks decoder compatibility, not an in-game listening test.
- A repeat run verified all hashes and skipped all 327 outputs.

## Reproduce

The conversion uses libvgm revision `c8b998b606895990c409a512b86c5509070f9f0d`, Python 3, CMake, a C++ compiler, FFmpeg and ffprobe.

```sh
mkdir -p .build/music-tools
git clone https://github.com/ValleyBell/libvgm.git .build/music-tools/libvgm
git -C .build/music-tools/libvgm checkout c8b998b606895990c409a512b86c5509070f9f0d
cmake -S .build/music-tools/libvgm -B .build/music-tools/libvgm/build \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_PLAYER=OFF -DBUILD_LIBAUDIO=OFF \
  -DUSE_SANITIZERS=OFF
cmake --build .build/music-tools/libvgm/build -j 6
python3 Scripts/convert-music.py Sources/Music \
  --renderer .build/music-tools/libvgm/build/bin/vgm2wav
```

VGM renders use 44.1 kHz, 16-bit stereo, two loop passes and an eight-second fade for looping tracks. Non-looping cues retain their logged duration. These are finite recordings. The current audio deck repeats the whole recording, including any intro and fade; it does not use the original VGM loop point.

The converter checks the gzip payload, VGM signature, logged duration, encoded duration and complete M4A decode. It rejects silent renders and records source/output SHA-256 hashes in `Sources/Music/conversion-report.json`. Repeat runs skip verified unchanged outputs. Existing outputs without matching report hashes are protected from replacement.

Generated audio and the report remain in the ignored Music asset folder. The full-game bundle already copies M4A files and the shared soundtrack library discovers them. Standalone Lemmings 2 and Lemmings 3 packaging still includes only their selected Amiga module folders. Conversion does not change soundtrack selection, platform-specific tune mapping or those package rules.

## Added Archimedes, SNES and Master System assets

The 22 Master System files use gzip payloads despite their `.vgm` extension. Conversion now detects gzip by its signature and preserves the originals. All 22 were rendered to Apple Lossless M4A; the report now contains 349 conversions with zero failures. The 50 Archimedes/SNES MP3 files retain their existing supported format and passed full FFmpeg decoding.

At this checkpoint, the catalogue contained 486 playable versions. Later composition reconciliation and remix additions are recorded below. All 72 additions have explicit ports and source-quality labels. Unmatched melodies remain separate identities instead of being assigned by track number. Matching named compositions participate in the existing soundtrack journey. Result cues and endings remain separate from ordinary level music. Full-game packaging includes the playable files and excludes original VGM/VGZ logs.

Apple AVAudioFile also read all 72 new recordings to their audio end. One SNES MP3 reported EOF 86 samples (about 2 ms) before its advertised length; full FFmpeg decoding passed, and the Apple check treats this small MP3 duration discrepancy as end-of-stream. The remaining files decoded without that discrepancy. This does not establish original-hardware fidelity.

Catalogue coverage and packaging checks passed for all 486 versions, including the new port and failure-cue assertions. Adaptive DJ playback tests passed for assigned tunes, all three engine journeys, protected cues, retry stability and suspended crossfades. The nonseasonal discovery check found 479 tracks; seven seasonal entries remain in the seasonal pool. These changes update source assets and build inputs; no new release app was produced in this step.

## Additional remix conversion

Converted four MandelSoft Classic special remixes and five Paintball remixes from OGG to Apple Lossless M4A. All nine passed full signal/duration checks and Apple AVAudioFile decoding. The report now records 358 verified conversions with zero failures. The catalogue and packaging tests pass for 495 playable versions. No new release build was cut.

## Decoder-safe SNES recording

Full Core Audio decoding found error -39 at the end of `Lemmings (MP3)/13 As Long As You Try Your Best.mp3`. The original is preserved. Its Apple Lossless copy passed complete decoding and replaces the MP3 in both library scanners. The source remains lossy; this is a decoder compatibility repair.

```sh
python3 Scripts/convert-music.py Sources/Music \
  --renderer .build/music-tools/libvgm/build/bin/vgm2wav \
  --repair-mp3 'Lemmings (MP3)/13 As Long As You Try Your Best.mp3'
python3 Tools/MusicCatalogue/build.py --links
```

The report now has 359 verified conversions with zero failures. Previously verified MP3 repairs are included on repeat runs. The catalogue uses the report to preserve their original paths without offering both the source and its replacement as separate arrangements.

When a conversion already exists without a report entry, `--verify-existing` compares its complete decoded samples with a fresh render. Only an identical result is adopted. It never replaces existing audio.
