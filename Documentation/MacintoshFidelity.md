# Macintosh sound and counters — 1.9

The 1.9 development source adds **Macintosh (original)** to Settings → Audio
and **Original Macintosh** to Settings → Graphics → Counters. Existing
preferences keep their current counter style. Counter and soundtrack choices
are independent of the selected terrain artwork.

## Counters and release-rate sound

Counter digits come from frames 96–105 of the supplied Macintosh `Charset2`
bank. Frame 107 supplies the recessed pale-pink counter socket. Digits use
whole-pixel scales. The same Classic/NeoLemmix panel keeps its skill identities,
counts, selection state, mouse targets and accessible names. Unlimited supplies
use the existing bitmap infinity symbol.

The original executable's `CODE 3:$0AC6` rate handler plays effect 14,
`MousePress`, after a successful change. Its pitch step is
`floor((rate - 50) / 2)`. `CODE 2:$3672` uses 24 steps per octave, giving a
playback ratio of `2^(step / 24)`. The app uses that sample and rule, including
keyboard limits and held controls. Clamped or locked changes stay silent.
NeoLemmix waits for its queued spawn-interval command to apply; shorter
intervals give higher pitches. Holds reuse one interface voice. Effects volume,
mute and replay sample selection remain shared.

## Music preparation and selection

`Tools/MacMusic/prepare.py` renders the supplied `SONG`, `MIDI`, `INST` and
`snd` resources to 22,050 Hz, stereo, 16-bit Apple Lossless files. It uses each
song's tempo, channel-to-instrument mapping, sample loops, note decay and pitch
shift. A constant trim prevents float mixes above full scale from clipping.
This uses the game's sampled instruments; a General MIDI sound bank is not used.

| Resource bank | Prepared arrangements | Selection |
| --- | ---: | --- |
| Macintosh Lemmings 1.5.2 disk | 21 | Existing 17-theme Classic cycle and four special-level overrides |
| Macintosh Oh No! disk | 6 | Tune names 1–6; resource IDs alone do not give tune order |
| Supplied Xmas Demo '92 resource fork | 4 | Jangle, Rudy, Frosto, Re-Jangle, in resource-ID order |

The seasonal option uses the Xmas '92 arrangements across the four seasonal
campaigns. This is a selected Mac score cycle, not proof of each edition's
historical level ordering. The supplied Holiday 1994 installer music contains
the six Oh No! tunes, so it does not establish a separate Holiday score.
Frosto remains a separate Mac seasonal theme; it is not labelled as the Amiga
Walking in a Winter Wonderland composition.

The unified full and slim builds include `MacMusic`, separate from the DJ
catalogue. Settings offers the source only when all 31 prepared files and their
manifest are present. Campaign selection, retries and direct level selection
use stable tune identities. An unavailable port-exclusive theme follows the
existing assigned-module fallback. The Mac files use the shared decoded-audio
deck with a dry base mix; mute, volume, pause/resume, speed, nuke filtering and
recording capture follow that deck. Turntable pause effects remain available.

Lemmings 2 and 3 retain their native sequel soundtracks and panels. They do not
have the Classic release-rate control. Standalone sequel bundles do not include
these Classic Mac recordings.

## Reproducible build and limits

The bundle script prepares Mac artwork first, then runs
`Scripts/ensure-mac-music-tools.sh` and the music preparer. A cold preparation
needs Git, CMake, a C++23 compiler, Python and Apple's `afconvert`. Dependencies
are cached under `.build`; they are not runtime dependencies.

The file-only renderer is MIT-licensed
[resource_dasm](https://github.com/fuzziqersoftware/resource_dasm), revision
`2f1ec79429f0129691791d76c443f411291eb10b`, with phosg revision
`5c2a7213dafb698e3eac41828a86204d848bc7ba`. SDL output is disabled. The build
corrects two RIFF-size fields in that pinned writer: interleaved stereo samples
must not be counted twice. Instrument decoding and synthesis are unchanged.
The generated manifest records the renderer revisions, source/song/output
hashes, sample counts and trim for every arrangement. Invalid, silent,
non-finite or truncated output fails preparation.

The renderer does not reproduce original SoundMusicSys hardware voice stealing.
An audible comparison with an original Mac and historical loop/ordering checks
remain separate validation. Automated tests stay muted and offscreen.

Reproduce the focused app checks with:

```sh
LEMMINGS_TEST_AUDIO=muted TEST_SCOPE=mac-fidelity \
  zsh Scripts/run-app-integration-tests.sh
python3 Tools/MacMusic/test_prepare.py
zsh Scripts/run-mac-music-tests.sh /path/to/App.app/Contents/Resources/MacMusic
```

The app checks need a newly prepared bundle; set `LEMMINGS_TEST_APP` to that
bundle when it is outside `.build/local`. They cover file hashes and decoded
lengths, campaign routing, source transitions, pause/resume, the original
rate sample/pitches, mute/volume/replay, queued and locked Neo input, and
rendered counter/settings targets. Source changes retain both manual and
interruption pauses, then resume the selected soundtrack. The source update
has not been published.
