# Music timing audit

Generated 2026-09-25T12:50:54.694439+00:00 from the installed playable catalogue.

**495 versions across 210 track identities analysed.** 276 have stable BPM estimates and 209 have stable bar estimates. 219 BPM estimates and 286 bar estimates need review. Analysis failures: 0.

These are automated estimates. No listening review or manual downbeat correction has been completed. A regular detected pulse can still have the wrong musical beat or bar phase.

## Coverage

Each catalogue version is measured separately. Ports and remixes do not inherit the tempo of another arrangement. Archive originals, conversion inputs, and `By Track` symlink duplicates are outside this playable-file count.

Formats: 360 .m4a, 73 .mod, 50 .mp3, 12 .wav.

| Catalogue game | Versions | Stable BPM estimates | Stable bar estimates |
| --- | ---: | ---: | ---: |
| classic | 318 | 197 | 152 |
| demo | 21 | 5 | 3 |
| holiday | 7 | 4 | 0 |
| lemmings2 | 65 | 22 | 12 |
| lemmings3 | 17 | 8 | 5 |
| lemmings3d | 38 | 19 | 16 |
| ohno | 24 | 17 | 17 |
| paintball | 5 | 4 | 4 |

## What the numbers mean

`baseBPM` is the detected musical pulse at normal playback speed. It is not the gameplay speed multiplier. Speed pitch changes do not change this tempo. DJ tempo matching scales the effective BPM separately.

Native modules also have an exact tracker clock. For four rows per pulse, `fourRowBPM = tickBPM × 6 / ticksPerRow`. Four rows do not establish a musical beat, meter, or downbeat. The report preserves this source clock beside the detected pulse instead of treating them as interchangeable.

BPM values below use one decimal for readability. The JSON retains three decimals, but that precision does not imply measurement accuracy. The range is the 10th–90th percentile of local tempo estimates, not a statistical confidence interval.

## Method and acceptance rules

Recordings are decoded completely by FFmpeg to mono 22,050 Hz PCM. Modules are rendered through the shipped ProTracker player for one traversal, including any opening section. The scanner records tempo commands and the loop start. It rejects traversals longer than 600 seconds. No scanned module exceeded that limit or used an unsupported timing command.

[Beat This!](https://github.com/CPJKU/beat_this) `final0`, package `1.1.0`, supplies beat and downbeat positions. The minimal postprocessor has a 20 ms timestamp resolution. The model runs locally. Its first use downloads the model weights.

The summary uses median tempo over 16-beat spans where possible. It excludes spans outside 70–130% of the median beat period. This reduces timestamp quantisation without forcing every file to one assumed BPM.

A stable BPM estimate requires at least 32 beats, at least 12 seconds of audio, 80% beat coverage, 92% regular beat intervals, and at most 4% spread between local tempo percentiles. Regular intervals are within 10% of the median period. Modules with clock changes need review. A detected module pulse must also agree with the opening four-row clock, half that clock, or twice that clock within 3%.

A stable bar estimate also requires at least eight complete bars and 90% agreement on beats per bar. Accepted candidate meters contain 2–12 beats per bar. Uncertain candidates remain visible below, but the DJ does not use them for bar alignment.

Stable meter candidates: 2 with 2 beats per bar, 206 with 4 beats per bar, 1 with 6 beats per bar.

These checks favour conservative automatic use. They do not prove meter or phrase structure. Waltzes, pickups, sparse arrangements, and half/double-time ambiguity still need listening review. No 8-bar or 16-bar phrase labels are inferred.

## Native modules with clock changes

6 modules contain more than one tracker tempo segment. These keep timed fades and do not use fixed-BPM matching. Each entry below lists four-row BPM at source seconds. The JSON also records order, row, tick tempo, and speed.

| File | Four-row BPM @ seconds |
| --- | --- |
| `lemmings_2_music_mod_tsyu/circus.mod` | 262.5 @ 0.00, 97.5 @ 58.51 |
| `lemmings_2_music_mod_tsyu/classic.mod` | 126.0 @ 0.00, 252.0 @ 60.95, 250.0 @ 68.57, 126.0 @ 76.25, 198.0 @ 91.49 |
| `lemmings_2_music_mod_tsyu/egyptian.mod` | 216.0 @ 0.00, 108.9 @ 33.33, 217.7 @ 112.70, 108.9 @ 125.93 |
| `lemmings_2_music_mod_tsyu/highland.mod` | 240.0 @ 0.00, 120.0 @ 76.00, 240.0 @ 92.00 |
| `lemmings_2_music_mod_tsyu/space.mod` | 264.0 @ 0.00, 288.0 @ 0.06, 264.0 @ 9.17, 256.0 @ 23.72, 130.0 @ 27.47, 114.0 @ 27.93, 145.0 @ 29.51, 143.0 @ 32.82, 125.0 @ 33.24, 145.0 @ 34.68, 136.0 @ 37.99, 138.0 @ 39.75, 136.0 @ 43.23, 138.0 @ 48.52, 143.0 @ 50.26, 138.0 @ 53.62, 145.0 @ 55.36, 147.0 @ 58.67, 145.0 @ 65.20, 143.0 @ 70.17 |
| `lemmings_3_music_mod_tsyu/SHADOW2.mod` | 105.4 @ 0.00, 120.0 @ 54.63 |

## Review queue

Reason counts overlap. One file can need review for several reasons.

| Reason | Versions |
| --- | ---: |
| `bar-count-or-downbeat-ambiguous` | 268 |
| `tempo-varies-or-detector-disagrees` | 186 |
| `irregular-or-missing-beats` | 172 |
| `short-cue-or-too-few-beats` | 22 |
| `detected-pulse-disagrees-with-tracker-clock` | 22 |
| `incomplete-beat-coverage` | 11 |
| `no-reliable-pulse` | 9 |
| `module-has-tempo-changes` | 6 |

9 versions have no reliable pulse estimate:

- `Lemmings_Series_(IBM_PC_AT)/01 Let's Go.m4a`
- `Lemmings-SMS/Lemmings - 21 - Let's Go!.m4a`
- `Lemmings-SMS/Lemmings - 22 - Oh No!.m4a`
- `Lemmings (MP3)/99 Trapdoor.mp3`
- `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/05 Bronze Medal.m4a`
- `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/03 Gold Medal.m4a`
- `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/02 Let's Go!.m4a`
- `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/04 Silver Medal.m4a`
- `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/06 Tribe Complete.m4a`

## How DJ mixing uses this data

Classic, Lemmings 2, and Lemmings 3 use the shared DJ player. The player verifies the current audio hash before using a timing grid. Packaging filters timing data to the installed catalogue and records hashes for converted playback files.

Stable beat grids provide source-position timing and nearby tempo matching, within the existing 8% limit. A grid marked for review does not trigger automatic beat or bar matching. Without analysed timing, native modules retain their existing four-row clock fallback. Recordings without timing retain a timed gain fade.

Bar alignment requires matching candidate meters and effective BPM within 1%. The incoming first downbeat must be within two seconds. The outgoing start wait is capped at four seconds. A short incoming pickup plays silently, then the gain fade covers whole measured outgoing bars.

The planner also checks both local grids across the complete fade. Each bar must be within 4% of the expected period, and corresponding boundaries must agree within 80 ms. Missing boundaries, irregular local bars, long introductions, and incompatible grids keep the timed fade. The player does not extrapolate beyond the last analysed beat.

This is approximate musical alignment. Beat detection uses 20 ms frames, and audio processing latency and main-actor scheduling can add error. The gain envelopes are not sample-accurate or phrase-aware. Loop positions follow the source duration and the native module loop start. No listening test of every possible transition has been completed.

## Validation and reproduction

The timing suite checks catalogue coverage, audio hashes, measured beat positions, tempo scaling, loop positions, pickups, whole bars, uncertain grids, local irregular bars, and packaging. The playback suite checks real audio loading, timing routing, stale-grid rejection, tempo-unit settings, speed pitch, all three game journeys, and suspended fades.

Run instructions and dependencies are in [Tools/MusicTiming](../Tools/MusicTiming/README.md). Run `zsh Scripts/run-music-timing-tests.sh`, `zsh Scripts/run-music-catalogue-tests.sh`, and `zsh Scripts/run-adaptive-dj-playback-tests.sh "$PWD/Sources/Music"` after changes.

## Sources and provenance

- [Playable catalogue](../Resources/Music/catalogue.json): version identities and source paths.
- [Timing data](../Resources/Music/timing.json): per-file SHA-256, all beat/downbeat timestamps, and review reasons.
- [Source audit](MusicSourceAudit.md): collection provenance and known collection limits.
- [Native ProTracker implementation](../Sources/NxlvKit/ProTrackerModule.swift): module audio and tracker timing.
- [Beat This! implementation](https://github.com/CPJKU/beat_this): beat/downbeat detector.

Catalogue SHA-256: `dfb831f258b47957bbcaa3f7897777faa415cb496dfd3cf159583973c0486e85`.

Model SHA-256: `8c328b45f59d8dd3dff219253ff6a8d6482be57d0133a29140e2febbf8eb8331`.

The timing JSON records decoder and dependency versions. Audio, model, decoder, dependency, or renderer changes invalidate the corresponding cache.

## Every playable version

**Stable** means the automated checks passed. **Review** means the estimate is retained for inspection only. The beats/bar column is a candidate meter, including rows marked Review. The clock column applies only to native modules. A range there means the module changes clock.

### classic

| Track / port | Source file | Estimated BPM (p10–p90) | Four-row clock | Beats/bar | BPM | Bars |
| --- | --- | ---: | ---: | ---: | --- | --- |
| Clear 1 / arcade | `Lemmings_(Arcade)/15 Clear 1.m4a` | 128.6 (128.6–130.4) | — | 4 | Review | Review |
| Clear 2 / arcade | `Lemmings_(Arcade)/16 Clear 2.m4a` | 157.9 (156.2–187.5) | — | 5 | Review | Review |
| Clear 3 / arcade | `Lemmings_(Arcade)/17 Clear 3.m4a` | 187.5 (176.5–189.9) | — | 6 | Review | Review |
| Clear 4 / arcade | `Lemmings_(Arcade)/18 Clear 4.m4a` | 108.7 (107.9–110.7) | — | 4 | Review | Review |
| Awesome / archimedes | `Archimedes/20. Awesome (Archimedes).mp3` | 685.7 (615.4–738.5) | — | — | Review | Review |
| Awesome / amiga | `CoLD SToRAGE - Lemmings - the original AMIGA game audio/CoLD SToRAGE - Lemmings - the original AMIGA game audio - 01 Lemmings - Awesome.wav` | 154.3 (153.8–197.5) | — | 4 | Review | Review |
| Awesome / snes | `Lemmings (MP3)/24 Awesome.mp3` | 151.4 (150.9–170.8) | — | 4 | Review | Review |
| Awesome / fm-towns | `Lemmings_(FM_Towns)/21 Awesome.m4a` | 152.4 (151.9–152.9) | — | 4 | Stable | Stable |
| Awesome / pc-98 | `Lemmings_(NEC_PC-9801)/20 Awesome.m4a` | 151.4 (150.9–151.9) | — | 4 | Stable | Stable |
| Awesome / x68000 | `Lemmings_(Sharp_X68000)/21 Awesome.m4a` | 170.2 (170.2–170.8) | — | 4 | Stable | Stable |
| Awesome / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/21 Awesome.m4a` | 155.8 (131.5–156.4) | — | 4 | Review | Review |
| Awesome / tandy | `Lemmings_Series_(Tandy_1000)/20 Awesome Main Theme (Wright&Wright).m4a` | 155.8 (155.8–156.4) | — | 4 | Stable | Stable |
| Awesome / dos-opl2 | `Remixes/orig_special_music_mandelsoft/awesome.m4a` | 160.0 (160.0–160.5) | — | 4 | Stable | Stable |
| Awesome / amiga | `lemmings_music_mod/awesome.mod` | 151.9 (151.9–152.4) | 152.0 | 4 | Stable | Stable |
| Shadow of the Beast / archimedes | `Archimedes/18 - Shadow of the Beast I (Archimedes).mp3` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| Shadow of the Beast / snes | `Lemmings (MP3)/22 Beast I.mp3` | 73.3 (73.2–93.8) | — | 2 | Review | Review |
| Shadow of the Beast / fm-towns | `Lemmings_(FM_Towns)/19 Beast.m4a` | 145.9 (145.5–146.3) | — | 4 | Stable | Stable |
| Shadow of the Beast / pc-98 | `Lemmings_(NEC_PC-9801)/18 Beast.m4a` | 134.8 (114.6–143.3) | — | 4 | Review | Review |
| Shadow of the Beast / x68000 | `Lemmings_(Sharp_X68000)/19 Beast.m4a` | 85.1 (85.1–85.3) | — | 4 | Stable | Review |
| Shadow of the Beast / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/19 Beast.m4a` | 136.4 (128.5–136.8) | — | 4 | Review | Review |
| Shadow of the Beast / tandy | `Lemmings_Series_(Tandy_1000)/18 Shadow of the Beast Opening (Whittaker).m4a` | 136.8 (136.4–137.3) | — | 4 | Stable | Stable |
| Shadow of the Beast / dos-opl2 | `Remixes/orig_special_music_mandelsoft/beasti.m4a` | 198.3 (145.9–233.0) | — | 4 | Review | Review |
| Shadow of the Beast / amiga | `lemmings_music_mod/beastI.mod` | 145.0 (136.9–145.0) | 145.0 | 4 | Review | Review |
| Shadow of the Beast II / archimedes | `Archimedes/21 - Shadow of the Beast II (Archimedes).mp3` | 104.6 (104.6–104.8) | — | 4 | Stable | Stable |
| Shadow of the Beast II / amiga | `CoLD SToRAGE - Lemmings - the original AMIGA game audio/CoLD SToRAGE - Lemmings - the original AMIGA game audio - 02 Lemmings - Shadow of the Beast II.wav` | 155.3 (154.5–183.7) | — | 4 | Review | Review |
| Shadow of the Beast II / snes | `Lemmings (MP3)/25 Beast II.mp3` | 151.4 (150.9–162.9) | — | 4 | Review | Review |
| Shadow of the Beast II / fm-towns | `Lemmings_(FM_Towns)/22 BeastII.m4a` | 152.4 (151.9–203.4) | — | 4 | Review | Review |
| Shadow of the Beast II / pc-98 | `Lemmings_(NEC_PC-9801)/21 BeastII.m4a` | 151.4 (121.2–151.9) | — | 4 | Review | Review |
| Shadow of the Beast II / x68000 | `Lemmings_(Sharp_X68000)/22 BeastII.m4a` | 96.6 (90.4–120.6) | — | — | Review | Review |
| Shadow of the Beast II / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/22 BeastII.m4a` | 155.8 (146.8–167.2) | — | 4 | Review | Review |
| Shadow of the Beast II / tandy | `Lemmings_Series_(Tandy_1000)/21 Shadow of the Beast II Level 2-3 (Wright&Wright).m4a` | 155.8 (138.3–164.1) | — | 4 | Review | Review |
| Shadow of the Beast II / dos-opl2 | `Remixes/orig_special_music_mandelsoft/beastii.m4a` | 154.8 (137.6–165.5) | — | 4 | Review | Review |
| Shadow of the Beast II / amiga | `lemmings_music_mod/beastII.mod` | 151.9 (151.9–180.1) | 152.0 | 4 | Review | Review |
| Can-Can / archimedes | `Archimedes/01 - Can Can (Archimedes).mp3` | 170.8 (153.4–192.0) | — | 4 | Review | Review |
| Can-Can / snes | `Lemmings (MP3)/05 Just Dig!.mp3` | 85.0 (80.4–105.0) | — | 2 | Review | Review |
| Can-Can / master-system | `Lemmings-SMS/Lemmings - 02 - Can-Can (Galop Infernal).m4a` | 214.3 (201.7–214.3) | — | — | Review | Review |
| Can-Can / arcade | `Lemmings_(Arcade)/01 Can-Can (Infernal Galop).m4a` | 174.5 (174.5–175.2) | — | 4 | Stable | Stable |
| Can-Can / lynx | `Lemmings_(Atari_Lynx)/07 Can-Can.m4a` | 149.1 (148.6–149.4) | — | 4 | Stable | Review |
| Can-Can / fm-towns | `Lemmings_(FM_Towns)/07 Can-Can.m4a` | 183.2 (175.2–201.0) | — | 4 | Review | Review |
| Can-Can / pc-98 | `Lemmings_(NEC_PC-9801)/07 Can-Can.m4a` | 98.8 (98.6–126.3) | — | 2 | Review | Review |
| Can-Can / nes | `Lemmings_(NES)/02 Can-Can.m4a` | 96.4 (84.7–119.6) | — | — | Review | Review |
| Can-Can / nes | `Lemmings_(NES)/10 Can-Can (alt).m4a` | 180.9 (161.2–241.6) | — | — | Review | Review |
| Can-Can / game-boy | `Lemmings_(Nintendo_Game_Boy)/05 Can-Can.m4a` | 98.9 (89.6–119.7) | — | — | Review | Review |
| Can-Can / x68000 | `Lemmings_(Sharp_X68000)/07 Can-Can.m4a` | 193.5 (161.6–206.9) | — | 2 | Review | Review |
| Can-Can / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/07 Can-Can.m4a` | 103.9 (91.1–124.9) | — | 4 | Review | Review |
| Can-Can / tandy | `Lemmings_Series_(Tandy_1000)/06 Can-Can (Infernal Galop, Offenbach).m4a` | 93.8 (90.8–106.0) | — | — | Review | Review |
| Can-Can / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_06.m4a` | 172.0 (171.4–172.0) | — | 4 | Stable | Review |
| Can-Can / amiga | `lemmings_music_mod/cancan.mod` | 175.2 (164.7–175.2) | 175.0 | 2 | Review | Review |
| How Much Is That Doggie in the Window / archimedes | `Archimedes/08 - How Much Is That Doggie in the Window (Archimedes).mp3` | 162.7 (160.0–173.8) | — | 3 | Review | Review |
| How Much Is That Doggie in the Window / snes | `Lemmings (MP3)/12 Not As Complicated As it Looks.mp3` | 151.4 (150.9–151.9) | — | — | Stable | Review |
| How Much Is That Doggie in the Window / master-system | `Lemmings-SMS/Lemmings - 09 - (How Much Is) That Doggie In The Window.m4a` | 183.2 (166.1–242.7) | — | — | Review | Review |
| How Much Is That Doggie in the Window / lynx | `Lemmings_(Atari_Lynx)/12 That Doggie In The Window.m4a` | 122.8 (118.8–142.6) | — | — | Review | Review |
| How Much Is That Doggie in the Window / fm-towns | `Lemmings_(FM_Towns)/12 That Doggie In The Window.m4a` | 155.8 (146.4–178.3) | — | 3 | Review | Review |
| How Much Is That Doggie in the Window / x68000 | `Lemmings_(Sharp_X68000)/12 That Doggie In The Window.m4a` | 154.3 (137.1–169.0) | — | — | Review | Review |
| How Much Is That Doggie in the Window / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/12 That Doggy In The Window.m4a` | 164.9 (136.6–175.2) | — | 2 | Review | Review |
| How Much Is That Doggie in the Window / tandy | `Lemmings_Series_(Tandy_1000)/11 That Doggie in the Window (Bob Merrill).m4a` | 175.2 (174.5–181.8) | — | 4 | Review | Review |
| How Much Is That Doggie in the Window / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_12.m4a` | 134.8 (122.1–160.0) | — | 6 | Review | Review |
| How Much Is That Doggie in the Window / amiga | `lemmings_music_mod/doggie.mod` | 155.8 (152.9–156.4) | 195.0 | 4 | Review | Review |
| Let's Go! / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/01 Let's Go.m4a` | — | — | — | Review | Review |
| March of the Mods / arcade | `Lemmings_(Arcade)/02 March of the Mods (The Finnjenka Dance).m4a` | 89.7 (89.6–89.7) | — | — | Stable | Review |
| March of the Mods / lynx | `Lemmings_(Atari_Lynx)/01 Intro.m4a` | 124.4 (123.7–138.4) | — | — | Review | Review |
| March of the Mods / fm-towns | `Lemmings_(FM_Towns)/01 Intro.m4a` | 204.7 (159.1–252.6) | — | — | Review | Review |
| March of the Mods / pc-98 | `Lemmings_(NEC_PC-9801)/01 Intro.m4a` | 127.3 (127.0–171.5) | — | 4 | Review | Review |
| March of the Mods / x68000 | `Lemmings_(Sharp_X68000)/01 Intro.m4a` | 121.7 (109.7–130.8) | — | 4 | Review | Review |
| March of the Mods / amiga | `lemmings_music_mod/intro.mod` | 146.3 (136.4–177.7) | 146.0 | — | Review | Review |
| Lemming 1 / archimedes | `Archimedes/02 - Palcelbel's Cannon (Archimedes).mp3` | 85.4 (85.3–85.4) | — | 2 | Stable | Review |
| Lemming 1 / snes | `Lemmings (MP3)/06 Only Floaters Can Survive This.mp3` | 131.9 (124.0–131.9) | — | 4 | Review | Review |
| Lemming 1 / master-system | `Lemmings-SMS/Lemmings - 03 - Lemming 1.m4a` | 125.0 (125.0–125.0) | — | 2 | Stable | Review |
| Lemming 1 / arcade | `Lemmings_(Arcade)/03 Lemming 1.m4a` | 87.4 (87.3–87.4) | — | 4 | Stable | Review |
| Lemming 1 / lynx | `Lemmings_(Atari_Lynx)/02 Lemming 1.m4a` | 124.0 (124.0–124.4) | — | 4 | Stable | Stable |
| Lemming 1 / fm-towns | `Lemmings_(FM_Towns)/02 Lemming 1.m4a` | 148.6 (148.1–154.3) | — | 4 | Review | Review |
| Lemming 1 / pc-98 | `Lemmings_(NEC_PC-9801)/02 Lemming 1.m4a` | 150.9 (150.5–151.9) | — | 4 | Stable | Stable |
| Lemming 1 / x68000 | `Lemmings_(Sharp_X68000)/02 Lemming 1.m4a` | 154.8 (154.3–155.3) | — | 4 | Stable | Review |
| Lemming 1 / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/02 Lemming 1.m4a` | 145.5 (145.5–145.9) | — | 4 | Stable | Stable |
| Lemming 1 / tandy | `Lemmings_Series_(Tandy_1000)/01 Lemming 1.m4a` | 72.8 (72.7–72.8) | — | 4 | Stable | Review |
| Lemming 1 / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_01.m4a` | 148.1 (147.7–148.1) | — | 4 | Stable | Review |
| Lemming 1 / amiga | `lemmings_music_mod/lemming1.mod` | 147.2 (146.3–148.1) | 221.0 | 4 | Review | Review |
| Lemming 2 / archimedes | `Archimedes/04 - One Way or Another (Archimedes).mp3` | 128.3 (128.0–170.8) | — | 4 | Review | Review |
| Lemming 2 / snes | `Lemmings (MP3)/08 Now Use Miners and Climbers.mp3` | 131.9 (131.5–131.9) | — | 4 | Stable | Stable |
| Lemming 2 / master-system | `Lemmings-SMS/Lemmings - 05 - One Way Or Another.m4a` | 125.0 (125.0–125.0) | — | 4 | Stable | Stable |
| Lemming 2 / arcade | `Lemmings_(Arcade)/06 Lemming 2.m4a` | 199.2 (177.1–200.0) | — | — | Review | Review |
| Lemming 2 / lynx | `Lemmings_(Atari_Lynx)/03 Lemming 2.m4a` | 124.0 (124.0–124.4) | — | 4 | Stable | Stable |
| Lemming 2 / fm-towns | `Lemmings_(FM_Towns)/03 Lemming 2.m4a` | 137.9 (137.5–151.1) | — | 4 | Review | Review |
| Lemming 2 / pc-98 | `Lemmings_(NEC_PC-9801)/03 Lemming 2.m4a` | 143.3 (142.9–143.3) | — | 4 | Stable | Review |
| Lemming 2 / x68000 | `Lemmings_(Sharp_X68000)/03 Lemming 2.m4a` | 152.4 (152.4–152.9) | — | 4 | Stable | Review |
| Lemming 2 / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/03 Lemming 2.m4a` | 136.4 (136.4–136.8) | — | 4 | Stable | Stable |
| Lemming 2 / tandy | `Lemmings_Series_(Tandy_1000)/02 Lemming 2.m4a` | 141.2 (136.4–174.5) | — | 4 | Review | Review |
| Lemming 2 / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_02.m4a` | 137.1 (136.4–137.5) | — | 4 | Stable | Stable |
| Lemming 2 / amiga | `lemmings_music_mod/lemming2.mod` | 137.1 (136.8–141.4) | 137.0 | 4 | Stable | Stable |
| Lemming 3 / archimedes | `Archimedes/10 - Keep Your Hair On Mr. Lemming (Archimedes).mp3` | 150.7 (146.3–203.4) | — | 4 | Review | Review |
| Lemming 3 / snes | `Lemmings (MP3)/14 Smile if You Love Lemmings.mp3` | 131.9 (131.5–131.9) | — | 4 | Stable | Stable |
| Lemming 3 / master-system | `Lemmings-SMS/Lemmings - 11 - Keep Your Hair On Mr Lemming.m4a` | 150.0 (150.0–150.0) | — | 4 | Stable | Stable |
| Lemming 3 / lynx | `Lemmings_(Atari_Lynx)/04 Lemming 3.m4a` | 124.4 (124.0–157.7) | — | 4 | Review | Review |
| Lemming 3 / fm-towns | `Lemmings_(FM_Towns)/04 Lemming 3.m4a` | 150.0 (148.8–155.8) | — | 4 | Review | Review |
| Lemming 3 / pc-98 | `Lemmings_(NEC_PC-9801)/04 Lemming 3.m4a` | 151.4 (127.3–152.4) | — | 4 | Review | Review |
| Lemming 3 / x68000 | `Lemmings_(Sharp_X68000)/04 Lemming 3.m4a` | 161.1 (160.5–161.1) | — | 4 | Stable | Stable |
| Lemming 3 / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/04 Lemming 3.m4a` | 155.8 (155.8–156.4) | — | 4 | Stable | Review |
| Lemming 3 / tandy | `Lemmings_Series_(Tandy_1000)/03 Lemming 3.m4a` | 155.8 (155.8–156.4) | — | 4 | Stable | Stable |
| Lemming 3 / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_03.m4a` | 148.1 (147.7–148.1) | — | 4 | Stable | Review |
| Lemming 3 / amiga | `lemmings_music_mod/lemming3.mod` | 149.1 (148.6–192.2) | 149.0 | 4 | Review | Review |
| CoLD SToRAGE - Lemmings - March of the Greentops - / amiga | `Remixes/CoLD SToRAGE - Lemmings - March of the Greentops -.m4a` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| Professor Mariarti / archimedes | `Archimedes/14. Professor Mariarti (Archimedes).mp3` | 162.7 (162.7–163.3) | — | 3 | Stable | Review |
| Don't Dilly-Dally on the Way / master-system | `Lemmings-SMS/Lemmings - 18 - Don't Dilly-Dally on the Way.m4a` | 280.7 (236.4–300.0) | — | 2 | Review | Review |
| Failure / master-system | `Lemmings-SMS/Lemmings - 20 - Failure.m4a` | 66.7 (59.5–74.9) | — | — | Review | Review |
| Let's Go! / master-system | `Lemmings-SMS/Lemmings - 21 - Let's Go!.m4a` | — | — | — | Review | Review |
| Levels 13 & 30 / master-system | `Lemmings-SMS/Lemmings - 14 - Levels 13 & 30.m4a` | 125.0 (125.0–125.0) | — | 4 | Stable | Stable |
| Miniature Overture / master-system | `Lemmings-SMS/Lemmings - 15 - Miniature Overture.m4a` | 125.0 (125.0–125.0) | — | 4 | Stable | Stable |
| Oh No! / master-system | `Lemmings-SMS/Lemmings - 22 - Oh No!.m4a` | — | — | — | Review | Review |
| Scotland The Brave / master-system | `Lemmings-SMS/Lemmings - 16 - Scotland The Brave.m4a` | 125.0 (124.7–125.3) | — | 4 | Stable | Stable |
| Success / master-system | `Lemmings-SMS/Lemmings - 19 - Success.m4a` | 125.0 (122.4–125.0) | — | 2 | Review | Review |
| Title Screen / master-system | `Lemmings-SMS/Lemmings - 01 - Title Screen.m4a` | 166.7 (166.7–167.2) | — | 4 | Stable | Review |
| Ending Theme / mega-drive | `Lemmings (Mega Drive, Genesis)/24 - Ending Theme.m4a` | 219.2 (179.8–279.9) | — | — | Review | Review |
| Opening Theme / mega-drive | `Lemmings (Mega Drive, Genesis)/01 - Opening Theme.m4a` | 129.4 (116.1–156.9) | — | — | Review | Review |
| Opening Theme (Loop Version) / mega-drive | `Lemmings (Mega Drive, Genesis)/25 - Opening Theme (Loop Version).m4a` | 129.4 (110.3–168.7) | — | — | Review | Review |
| Stage Theme 1 / mega-drive | `Lemmings (Mega Drive, Genesis)/02 - Stage Theme 1.m4a` | 186.0 (186.0–186.8) | — | 4 | Stable | Review |
| Stage Theme 10 / mega-drive | `Lemmings (Mega Drive, Genesis)/11 - Stage Theme 10.m4a` | 133.0 (111.9–133.3) | — | 4 | Review | Review |
| Stage Theme 11 / mega-drive | `Lemmings (Mega Drive, Genesis)/12 - Stage Theme 11.m4a` | 124.4 (124.0–124.4) | — | 4 | Stable | Stable |
| Stage Theme 12 / mega-drive | `Lemmings (Mega Drive, Genesis)/13 - Stage Theme 12.m4a` | 133.0 (133.0–133.3) | — | 4 | Stable | Stable |
| Stage Theme 13 / mega-drive | `Lemmings (Mega Drive, Genesis)/14 - Stage Theme 13.m4a` | 133.0 (133.0–133.3) | — | 4 | Stable | Stable |
| Stage Theme 14 / mega-drive | `Lemmings (Mega Drive, Genesis)/15 - Stage Theme 14.m4a` | 133.0 (133.0–133.3) | — | 4 | Stable | Stable |
| Stage Theme 15 / mega-drive | `Lemmings (Mega Drive, Genesis)/16 - Stage Theme 15.m4a` | 133.0 (133.0–133.3) | — | 4 | Stable | Stable |
| Stage Theme 16 / mega-drive | `Lemmings (Mega Drive, Genesis)/17 - Stage Theme 16.m4a` | 133.0 (133.0–133.3) | — | 2 | Stable | Review |
| Stage Theme 17 / mega-drive | `Lemmings (Mega Drive, Genesis)/18 - Stage Theme 17.m4a` | 77.7 (77.5–78.7) | — | 4 | Review | Review |
| Stage Theme 18 / mega-drive | `Lemmings (Mega Drive, Genesis)/19 - Stage Theme 18.m4a` | 133.0 (133.0–133.3) | — | 4 | Stable | Stable |
| Stage Theme 19 / mega-drive | `Lemmings (Mega Drive, Genesis)/20 - Stage Theme 19.m4a` | 155.3 (154.8–155.3) | — | 4 | Stable | Stable |
| Stage Theme 2 / mega-drive | `Lemmings (Mega Drive, Genesis)/03 - Stage Theme 2.m4a` | 71.4 (62.2–95.6) | — | — | Review | Review |
| Stage Theme 20 / mega-drive | `Lemmings (Mega Drive, Genesis)/21 - Stage Theme 20.m4a` | 155.3 (154.8–155.3) | — | 4 | Stable | Stable |
| Stage Theme 21 / mega-drive | `Lemmings (Mega Drive, Genesis)/22 - Stage Theme 21.m4a` | 155.3 (145.9–155.3) | — | 4 | Review | Review |
| Stage Theme 3 / mega-drive | `Lemmings (Mega Drive, Genesis)/04 - Stage Theme 3.m4a` | 155.3 (154.8–155.3) | — | 4 | Stable | Stable |
| Stage Theme 4 / mega-drive | `Lemmings (Mega Drive, Genesis)/05 - Stage Theme 4.m4a` | 133.0 (133.0–133.3) | — | 4 | Stable | Stable |
| Stage Theme 5 / mega-drive | `Lemmings (Mega Drive, Genesis)/06 - Stage Theme 5.m4a` | 155.3 (154.8–155.3) | — | 4 | Stable | Review |
| Stage Theme 6 / mega-drive | `Lemmings (Mega Drive, Genesis)/07 - Stage Theme 6.m4a` | 116.5 (116.2–116.5) | — | 4 | Stable | Stable |
| Stage Theme 7 / mega-drive | `Lemmings (Mega Drive, Genesis)/08 - Stage Theme 7.m4a` | 177.1 (177.1–177.8) | — | 4 | Stable | Review |
| Stage Theme 8 / mega-drive | `Lemmings (Mega Drive, Genesis)/09 - Stage Theme 8.m4a` | 133.0 (133.0–133.3) | — | 4 | Stable | Stable |
| Stage Theme 9 / mega-drive | `Lemmings (Mega Drive, Genesis)/10 - Stage Theme 9.m4a` | 133.0 (133.0–133.3) | — | 4 | Stable | Stable |
| Sunsoft Special / mega-drive | `Lemmings (Mega Drive, Genesis)/23 - Sunsoft Special.m4a` | 155.3 (154.8–155.3) | — | 4 | Stable | Stable |
| Menace / archimedes | `Archimedes/19 - Menace (Archimedes).mp3` | 209.6 (208.7–209.6) | — | 4 | Stable | Stable |
| Menace / snes | `Lemmings (MP3)/23 Menace.mp3` | 280.7 (231.9–333.3) | — | 4 | Review | Review |
| Menace / lynx | `Lemmings_(Atari_Lynx)/19 Menace.m4a` | 149.1 (148.6–158.4) | — | 4 | Review | Review |
| Menace / fm-towns | `Lemmings_(FM_Towns)/20 Menace.m4a` | 163.8 (154.3–180.9) | — | 4 | Review | Review |
| Menace / pc-98 | `Lemmings_(NEC_PC-9801)/19 Menace.m4a` | 167.2 (166.1–190.8) | — | 4 | Review | Review |
| Menace / x68000 | `Lemmings_(Sharp_X68000)/20 Menace.m4a` | 96.6 (96.4–116.8) | — | 4 | Review | Review |
| Menace / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/20 Menace.m4a` | 156.4 (155.8–200.0) | — | 4 | Review | Review |
| Menace / tandy | `Lemmings_Series_(Tandy_1000)/19 Menace Main BGM (Whittaker).m4a` | 155.8 (146.8–156.4) | — | 4 | Review | Review |
| Menace / dos-opl2 | `Remixes/orig_special_music_mandelsoft/menace.m4a` | 148.1 (147.7–170.2) | — | 4 | Review | Review |
| Menace / amiga | `lemmings_music_mod/menace.mod` | 164.4 (162.7–217.2) | 163.0 | 4 | Review | Review |
| Coming Round the Mountain / snes | `Lemmings (MP3)/21 Easy When You Know How.mp3` | 122.1 (121.8–122.1) | — | 2 | Stable | Stable |
| Coming Round the Mountain / master-system | `Lemmings-SMS/Lemmings - 17 - She'll Be Coming 'Round the Mountain.m4a` | 200.0 (199.2–200.8) | — | 4 | Stable | Review |
| Coming Round the Mountain / arcade | `Lemmings_(Arcade)/14 She'll Be Coming 'Round The Mountain When She Comes.m4a` | 134.5 (114.8–158.9) | — | 4 | Review | Review |
| Coming Round the Mountain / lynx | `Lemmings_(Atari_Lynx)/05 She'll Be Coming 'Round The Mountain When She Comes.m4a` | 198.3 (198.3–199.2) | — | 4 | Review | Review |
| Coming Round the Mountain / fm-towns | `Lemmings_(FM_Towns)/05 She'll Be Coming 'Round The Mountain When She Comes.m4a` | 103.7 (100.6–134.1) | — | 4 | Review | Review |
| Coming Round the Mountain / pc-98 | `Lemmings_(NEC_PC-9801)/05 She'll Be Coming 'Round The Mountain When She Comes.m4a` | 104.1 (104.1–114.8) | — | 2 | Review | Review |
| Coming Round the Mountain / x68000 | `Lemmings_(Sharp_X68000)/05 She'll Be Coming 'Round The Mountain When She Comes.m4a` | 108.6 (108.4–144.6) | — | 2 | Review | Review |
| Coming Round the Mountain / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/05 She'll Be Coming 'Round The Mountain When She Comes.m4a` | 109.3 (109.1–129.4) | — | 4 | Review | Review |
| Coming Round the Mountain / tandy | `Lemmings_Series_(Tandy_1000)/04 She'll Be Coming 'Round The Mountain When She Comes (Traditional).m4a` | 218.2 (218.2–219.2) | — | 4 | Stable | Stable |
| Coming Round the Mountain / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_04.m4a` | 100.0 (99.8–100.2) | — | 4 | Stable | Stable |
| Coming Round the Mountain / amiga | `lemmings_music_mod/mountain.mod` | 100.8 (100.6–140.4) | 252.0 | 2 | Review | Review |
| Title Screen / nes | `Lemmings_(NES)/01 Title Screen.m4a` | 150.0 (146.0–150.7) | — | — | Stable | Review |
| Ending / snes | `Lemmings (MP3)/27 Ending.mp3` | 77.9 (71.2–78.2) | — | 2 | Review | Review |
| Failure / snes | `Lemmings (MP3)/04 Failure.mp3` | 122.0 (122.0–122.3) | — | 2 | Stable | Stable |
| Intermission / snes | `Lemmings (MP3)/26 Intermission.mp3` | 173.9 (155.8–195.1) | — | 2 | Review | Review |
| Staff Roll / snes | `Lemmings (MP3)/28 Staff Roll.mp3` | 127.0 (126.6–127.0) | — | 4 | Stable | Review |
| Stage Clear / snes | `Lemmings (MP3)/03 Stage Clear.mp3` | 122.0 (122.0–122.3) | — | 4 | Stable | Review |
| Stage Intro / snes | `Lemmings (MP3)/02 Stage Intro.mp3` | 150.5 (131.9–170.2) | — | 4 | Review | Review |
| Title Screen / snes | `Lemmings (MP3)/01 Title Screen.mp3` | 131.9 (131.5–131.9) | — | 4 | Stable | Stable |
| Trapdoor / snes | `Lemmings (MP3)/99 Trapdoor.mp3` | — | — | — | Review | Review |
| Ten Lemmings / archimedes | `Archimedes/17 - Ten Green Bottles (Archimedes).mp3` | 162.7 (162.2–163.3) | — | 4 | Stable | Review |
| Ten Lemmings / snes | `Lemmings (MP3)/20 Don't Do Anything Too Hasty.mp3` | 156.4 (155.8–156.4) | — | 4 | Stable | Review |
| Ten Lemmings / lynx | `Lemmings_(Atari_Lynx)/06 Ten Lemmings.m4a` | 165.5 (148.0–194.3) | — | — | Review | Review |
| Ten Lemmings / fm-towns | `Lemmings_(FM_Towns)/06 Ten Lemmings.m4a` | 166.7 (166.1–166.7) | — | 4 | Stable | Review |
| Ten Lemmings / pc-98 | `Lemmings_(NEC_PC-9801)/06 Ten Lemmings.m4a` | 90.7 (87.8–111.4) | — | 2 | Review | Review |
| Ten Lemmings / x68000 | `Lemmings_(Sharp_X68000)/06 Ten Lemmings.m4a` | 92.1 (89.4–96.2) | — | 2 | Review | Review |
| Ten Lemmings / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/06 Ten Lemmings.m4a` | 161.6 (147.1–162.2) | — | 4 | Review | Review |
| Ten Lemmings / tandy | `Lemmings_Series_(Tandy_1000)/05 Ten Lemmings (Ten Green Bottles, Traditional).m4a` | 161.6 (161.6–162.2) | — | 4 | Stable | Review |
| Ten Lemmings / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_05.m4a` | 150.0 (149.5–150.5) | — | 4 | Stable | Review |
| Ten Lemmings / amiga | `lemmings_music_mod/tenlemmings.mod` | 165.5 (164.9–165.5) | 124.0 | 4 | Review | Review |
| Rainbow Islands / archimedes | `Archimedes/13 - Rainbow Islands (Archimedes).mp3` | 146.3 (146.3–146.8) | — | 4 | Stable | Stable |
| Rainbow Islands / amiga | `CoLD SToRAGE - Lemmings - the original AMIGA game audio/CoLD SToRAGE - Lemmings - the original AMIGA game audio - 03 Lemmings - Rainbow Islands.wav` | 125.0 (124.7–125.3) | — | 4 | Stable | Stable |
| Rainbow Islands / snes | `Lemmings (MP3)/17 We All Fall Down.mp3` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| Rainbow Islands / lynx | `Lemmings_(Atari_Lynx)/08 Tim 1.m4a` | 124.0 (110.5–152.4) | — | 4 | Review | Review |
| Rainbow Islands / fm-towns | `Lemmings_(FM_Towns)/08 Tim 1.m4a` | 122.1 (122.1–122.4) | — | 4 | Stable | Stable |
| Rainbow Islands / pc-98 | `Lemmings_(NEC_PC-9801)/08 Tim 1.m4a` | 120.6 (120.3–120.6) | — | 4 | Stable | Stable |
| Rainbow Islands / game-boy | `Lemmings_(Nintendo_Game_Boy)/06 Tim 1.m4a` | 128.0 (127.7–128.0) | — | 4 | Stable | Stable |
| Rainbow Islands / x68000 | `Lemmings_(Sharp_X68000)/08 Tim 1.m4a` | 127.3 (127.3–127.7) | — | 4 | Stable | Stable |
| Rainbow Islands / spectrum | `Lemmings_(ZX_Spectrum_128)/01 Tim 1.m4a` | 125.3 (125.3–125.7) | — | 4 | Stable | Stable |
| Rainbow Islands / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/08 Tim 1.m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Stable |
| Rainbow Islands / tandy | `Lemmings_Series_(Tandy_1000)/07 Tim 1.m4a` | 121.5 (121.2–121.5) | — | 4 | Review | Review |
| Rainbow Islands / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_07.m4a` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| Rainbow Islands / amiga | `lemmings_music_mod/tim1.mod` | 122.1 (121.8–122.1) | 122.0 | 4 | Stable | Stable |
| Forest Green / archimedes | `Archimedes/15 - Forest Green (Archimedes).mp3` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| Forest Green / amiga | `CoLD SToRAGE - Lemmings - the original AMIGA game audio/CoLD SToRAGE - Lemmings - the original AMIGA game audio - 10 Lemmings - Forest Green.wav` | 125.0 (125.0–125.0) | — | 4 | Stable | Stable |
| Forest Green / snes | `Lemmings (MP3)/18 Origins and Lemmings.mp3` | 112.4 (112.2–120.0) | — | 2 | Review | Review |
| Forest Green / arcade | `Lemmings_(Arcade)/12 Forest Green.m4a` | 84.7 (77.7–101.3) | — | 2 | Review | Review |
| Forest Green / lynx | `Lemmings_(Atari_Lynx)/18 Forest Green.m4a` | 124.0 (124.0–124.4) | — | 4 | Stable | Stable |
| Forest Green / fm-towns | `Lemmings_(FM_Towns)/18 Forest Green.m4a` | 122.4 (122.1–148.6) | — | 4 | Review | Review |
| Forest Green / pc-98 | `Lemmings_(NEC_PC-9801)/17 Forest Green.m4a` | 120.6 (120.3–120.6) | — | 4 | Stable | Stable |
| Forest Green / nes | `Lemmings_(NES)/09 Tim 10.m4a` | 150.5 (150.0–159.5) | — | 4 | Review | Review |
| Forest Green / game-boy | `Lemmings_(Nintendo_Game_Boy)/02 Forest Green.m4a` | 149.5 (149.1–149.5) | — | 4 | Stable | Stable |
| Forest Green / x68000 | `Lemmings_(Sharp_X68000)/18 Forest Green.m4a` | 131.9 (131.9–132.2) | — | 4 | Stable | Stable |
| Forest Green / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/18 Tim 10 - Forest Green.m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Stable |
| Forest Green / tandy | `Lemmings_Series_(Tandy_1000)/17 Forest Green (Traditional).m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Stable |
| Forest Green / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_17.m4a` | 128.0 (128.0–128.0) | — | 4 | Stable | Stable |
| Forest Green / amiga | `lemmings_music_mod/tim10.mod` | 122.1 (121.8–122.1) | 122.0 | 4 | Stable | Stable |
| Smile if You Love Lemmings / archimedes | `Archimedes/03 - Smile if You Love Lemmings (Archimedes).mp3` | 139.5 (139.5–139.9) | — | 4 | Stable | Stable |
| Smile if You Love Lemmings / amiga | `CoLD SToRAGE - Lemmings - the original AMIGA game audio/CoLD SToRAGE - Lemmings - the original AMIGA game audio - 04 Lemmings - Smile if you Love Lemmings.wav` | 125.0 (125.0–125.0) | — | 4 | Stable | Stable |
| Smile if You Love Lemmings / snes | `Lemmings (MP3)/07 Tailor-Made For Blockers.mp3` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| Smile if You Love Lemmings / master-system | `Lemmings-SMS/Lemmings - 04 - Smile If You Love Lemmings.m4a` | 77.9 (68.2–90.9) | — | 2 | Review | Review |
| Smile if You Love Lemmings / arcade | `Lemmings_(Arcade)/05 Tim 2.m4a` | 158.9 (158.9–159.5) | — | — | Stable | Review |
| Smile if You Love Lemmings / lynx | `Lemmings_(Atari_Lynx)/09 Tim 2.m4a` | 124.0 (124.0–124.4) | — | 4 | Stable | Review |
| Smile if You Love Lemmings / fm-towns | `Lemmings_(FM_Towns)/09 Tim 2.m4a` | 122.1 (122.1–126.3) | — | 4 | Stable | Stable |
| Smile if You Love Lemmings / pc-98 | `Lemmings_(NEC_PC-9801)/09 Tim 2.m4a` | 120.6 (120.3–120.6) | — | 4 | Stable | Stable |
| Smile if You Love Lemmings / nes | `Lemmings_(NES)/03 Tim 2.m4a` | 128.7 (128.7–129.0) | — | 4 | Stable | Stable |
| Smile if You Love Lemmings / game-boy | `Lemmings_(Nintendo_Game_Boy)/07 Tim 2.m4a` | 432.4 (390.2–484.8) | — | — | Review | Review |
| Smile if You Love Lemmings / x68000 | `Lemmings_(Sharp_X68000)/09 Tim 2.m4a` | 126.3 (126.0–126.3) | — | 4 | Stable | Stable |
| Smile if You Love Lemmings / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/09 Tim 2.m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Stable |
| Smile if You Love Lemmings / tandy | `Lemmings_Series_(Tandy_1000)/08 Tim 2.m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Stable |
| Smile if You Love Lemmings / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_08.m4a` | 115.1 (114.8–115.1) | — | 4 | Stable | Stable |
| Smile if You Love Lemmings / amiga | `lemmings_music_mod/tim2.mod` | 122.1 (121.8–122.1) | 122.0 | 4 | Stable | Stable |
| Lend a Helping Hand / archimedes | `Archimedes/06 - Lend a Helping Hand (Archimedes).mp3` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| Lend a Helping Hand / amiga | `CoLD SToRAGE - Lemmings - the original AMIGA game audio/CoLD SToRAGE - Lemmings - the original AMIGA game audio - 05 Lemmings - Lend a Helping Hand.wav` | 125.0 (124.7–125.3) | — | 4 | Stable | Stable |
| Lend a Helping Hand / snes | `Lemmings (MP3)/10 A Task For Blockers and Bombers.mp3` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| Lend a Helping Hand / master-system | `Lemmings-SMS/Lemmings - 07 - Lend A Helping Hand.m4a` | 125.0 (125.0–133.0) | — | 4 | Review | Review |
| Lend a Helping Hand / arcade | `Lemmings_(Arcade)/07 Tim 3.m4a` | 106.0 (106.0–106.0) | — | 4 | Stable | Review |
| Lend a Helping Hand / lynx | `Lemmings_(Atari_Lynx)/10 Tim 3.m4a` | 124.0 (124.0–124.4) | — | 4 | Stable | Stable |
| Lend a Helping Hand / fm-towns | `Lemmings_(FM_Towns)/10 Tim 3.m4a` | 122.1 (122.1–122.4) | — | 4 | Stable | Stable |
| Lend a Helping Hand / pc-98 | `Lemmings_(NEC_PC-9801)/10 Tim 3.m4a` | 135.6 (135.6–136.0) | — | 4 | Stable | Stable |
| Lend a Helping Hand / nes | `Lemmings_(NES)/04 Tim 3.m4a` | 128.7 (120.9–170.3) | — | — | Review | Review |
| Lend a Helping Hand / game-boy | `Lemmings_(Nintendo_Game_Boy)/08 Tim 3.m4a` | 128.0 (127.7–136.8) | — | 4 | Review | Review |
| Lend a Helping Hand / x68000 | `Lemmings_(Sharp_X68000)/10 Tim 3.m4a` | 131.9 (131.9–132.2) | — | 4 | Stable | Stable |
| Lend a Helping Hand / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/10 Tim 3.m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Stable |
| Lend a Helping Hand / tandy | `Lemmings_Series_(Tandy_1000)/09 Tim 3.m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Stable |
| Lend a Helping Hand / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_09.m4a` | 125.0 (124.7–125.3) | — | 4 | Stable | Stable |
| Lend a Helping Hand / amiga | `lemmings_music_mod/tim3.mod` | 122.1 (121.8–122.1) | 122.0 | 4 | Stable | Stable |
| Postcard from Lemmingland / archimedes | `Archimedes/16 - Postcard from Lemmingland (Archimedes).mp3` | 133.3 (133.0–133.3) | — | 4 | Stable | Stable |
| Postcard from Lemmingland / amiga | `CoLD SToRAGE - Lemmings - the original AMIGA game audio/CoLD SToRAGE - Lemmings - the original AMIGA game audio - 06 Lemmings - Postcard from Lemmingland.wav` | 125.0 (125.0–125.0) | — | 4 | Stable | Stable |
| Postcard from Lemmingland / snes | `Lemmings (MP3)/19 Don't Let Your Eyes Deceive You.mp3` | 122.1 (121.8–122.1) | — | 4 | Stable | Review |
| Postcard from Lemmingland / arcade | `Lemmings_(Arcade)/13 Tim 4.m4a` | 89.7 (89.6–89.7) | — | 4 | Stable | Review |
| Postcard from Lemmingland / lynx | `Lemmings_(Atari_Lynx)/11 Tim 4.m4a` | 124.0 (124.0–124.4) | — | 4 | Stable | Review |
| Postcard from Lemmingland / fm-towns | `Lemmings_(FM_Towns)/11 Tim 4.m4a` | 122.1 (122.1–130.4) | — | 4 | Review | Review |
| Postcard from Lemmingland / pc-98 | `Lemmings_(NEC_PC-9801)/11 Tim 4.m4a` | 129.0 (128.7–129.0) | — | 4 | Stable | Stable |
| Postcard from Lemmingland / x68000 | `Lemmings_(Sharp_X68000)/11 Tim 4.m4a` | 138.3 (137.9–138.3) | — | 4 | Stable | Stable |
| Postcard from Lemmingland / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/11 Tim 4.m4a` | 121.5 (121.2–143.7) | — | 4 | Review | Review |
| Postcard from Lemmingland / tandy | `Lemmings_Series_(Tandy_1000)/10 Tim 4.m4a` | 121.2 (121.2–121.5) | — | 4 | Stable | Stable |
| Postcard from Lemmingland / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_10.m4a` | 125.0 (125.0–125.0) | — | 4 | Stable | Stable |
| Postcard from Lemmingland / amiga | `lemmings_music_mod/tim4.mod` | 122.1 (121.8–122.1) | 122.0 | 4 | Stable | Stable |
| Mind the Step / archimedes | `Archimedes/07 - Mind The Step (Archimedes).mp3` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| Mind the Step / amiga | `CoLD SToRAGE - Lemmings - the original AMIGA game audio/CoLD SToRAGE - Lemmings - the original AMIGA game audio - 07 Lemmings - Mind the Step.wav` | 125.0 (124.7–125.0) | — | 4 | Stable | Stable |
| Mind the Step / snes | `Lemmings (MP3)/11 Builders Will Help You Here.mp3` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| Mind the Step / master-system | `Lemmings-SMS/Lemmings - 08 - Mind The Step.m4a` | 125.0 (124.7–125.3) | — | 4 | Stable | Stable |
| Mind the Step / arcade | `Lemmings_(Arcade)/10 Tim 5.m4a` | 109.3 (109.1–109.3) | — | 4 | Stable | Stable |
| Mind the Step / lynx | `Lemmings_(Atari_Lynx)/13 Tim 5.m4a` | 124.0 (124.0–124.4) | — | 4 | Stable | Stable |
| Mind the Step / fm-towns | `Lemmings_(FM_Towns)/13 Tim 5.m4a` | 122.1 (122.1–122.4) | — | 4 | Stable | Stable |
| Mind the Step / pc-98 | `Lemmings_(NEC_PC-9801)/12 Tim 5.m4a` | 120.6 (120.3–120.6) | — | 4 | Stable | Stable |
| Mind the Step / nes | `Lemmings_(NES)/05 Tim 5.m4a` | 484.8 (419.6–516.1) | — | — | Review | Review |
| Mind the Step / game-boy | `Lemmings_(Nintendo_Game_Boy)/09 Tim 5.m4a` | 128.0 (127.7–128.0) | — | 4 | Stable | Stable |
| Mind the Step / x68000 | `Lemmings_(Sharp_X68000)/13 Tim 5.m4a` | 126.3 (126.0–126.3) | — | 4 | Stable | Stable |
| Mind the Step / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/13 Tim 5.m4a` | 121.2 (121.2–121.5) | — | 4 | Stable | Stable |
| Mind the Step / tandy | `Lemmings_Series_(Tandy_1000)/12 Tim 5.m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Stable |
| Mind the Step / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_11.m4a` | 120.0 (119.7–120.0) | — | 4 | Stable | Stable |
| Mind the Step / amiga | `lemmings_music_mod/tim5.mod` | 121.8 (121.8–122.1) | 122.0 | 4 | Stable | Stable |
| Dance of the Reed Flutes / archimedes | `Archimedes/09 - Dance of the Reed Flutes (Archimedes).mp3` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| Dance of the Reed Flutes / amiga | `CoLD SToRAGE - Lemmings - the original AMIGA game audio/CoLD SToRAGE - Lemmings - the original AMIGA game audio - 08 Lemmings - Dance of the Reed Flutes.wav` | 125.0 (124.7–125.3) | — | 4 | Stable | Stable |
| Dance of the Reed Flutes / snes | `Lemmings (MP3)/13 As Long As You Try Your Best.m4a` | 112.4 (112.2–112.4) | — | 4 | Stable | Review |
| Dance of the Reed Flutes / master-system | `Lemmings-SMS/Lemmings - 10 - Dance Of The Reed Flutes.m4a` | 125.0 (125.0–125.0) | — | 2 | Stable | Review |
| Dance of the Reed Flutes / arcade | `Lemmings_(Arcade)/08 Dance of the Toy Flutes (The Nutcracker Act II No. 12 V).m4a` | 125.0 (124.7–125.0) | — | 4 | Stable | Stable |
| Dance of the Reed Flutes / lynx | `Lemmings_(Atari_Lynx)/14 Dance of the Reed-Flutes.m4a` | 124.0 (124.0–124.4) | — | 4 | Stable | Review |
| Dance of the Reed Flutes / fm-towns | `Lemmings_(FM_Towns)/14 Dance of the Reed-Flutes.m4a` | 122.1 (122.1–134.8) | — | 4 | Review | Review |
| Dance of the Reed Flutes / pc-98 | `Lemmings_(NEC_PC-9801)/13 Dance of the Reed-Flutes.m4a` | 120.6 (120.3–120.6) | — | 4 | Stable | Stable |
| Dance of the Reed Flutes / nes | `Lemmings_(NES)/06 Tim 6.m4a` | 128.7 (128.7–129.0) | — | — | Stable | Review |
| Dance of the Reed Flutes / game-boy | `Lemmings_(Nintendo_Game_Boy)/01 Dance of the Reed-Flutes.m4a` | 128.0 (127.7–128.0) | — | 4 | Stable | Review |
| Dance of the Reed Flutes / x68000 | `Lemmings_(Sharp_X68000)/14 Dance of the Reed-Flutes.m4a` | 126.3 (126.0–126.3) | — | 4 | Stable | Stable |
| Dance of the Reed Flutes / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/14 Tim 6 - Dance of the Reed-Flutes.m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Review |
| Dance of the Reed Flutes / tandy | `Lemmings_Series_(Tandy_1000)/13 Dance of the Toy Flutes (The Nutcracker Act II No. 12 V, Tchaikovsky).m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Stable |
| Dance of the Reed Flutes / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_13.m4a` | 120.0 (119.7–120.3) | — | 4 | Stable | Stable |
| Dance of the Reed Flutes / amiga | `lemmings_music_mod/tim6.mod` | 122.1 (121.8–122.1) | 122.0 | 4 | Stable | Stable |
| Turkish March / archimedes | `Archimedes/11 - Rondo Alla Turca (Archimedes).mp3` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| Turkish March / amiga | `CoLD SToRAGE - Lemmings - the original AMIGA game audio/CoLD SToRAGE - Lemmings - the original AMIGA game audio - 09 Lemmings - Turkish March.wav` | 125.0 (124.7–125.3) | — | 4 | Stable | Stable |
| Turkish March / snes | `Lemmings (MP3)/15 Keep Your Hair on Mr. Lemming.mp3` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| Turkish March / master-system | `Lemmings-SMS/Lemmings - 12 - Ronda Alla Turca.m4a` | 125.0 (125.0–125.3) | — | 4 | Stable | Stable |
| Turkish March / arcade | `Lemmings_(Arcade)/09 Ronda Alla Turca (Piano Sonata No. 11 III).m4a` | 166.1 (140.4–166.7) | — | 4 | Review | Review |
| Turkish March / lynx | `Lemmings_(Atari_Lynx)/15 Ronda Alla Turca.m4a` | 124.0 (124.0–124.4) | — | 4 | Stable | Stable |
| Turkish March / fm-towns | `Lemmings_(FM_Towns)/15 Ronda Alla Turca.m4a` | 122.1 (122.1–126.3) | — | 4 | Stable | Stable |
| Turkish March / pc-98 | `Lemmings_(NEC_PC-9801)/14 Ronda Alla Turca.m4a` | 120.6 (120.3–120.6) | — | 4 | Stable | Stable |
| Turkish March / nes | `Lemmings_(NES)/07 Tim 7.m4a` | 128.7 (128.7–129.0) | — | 4 | Stable | Stable |
| Turkish March / game-boy | `Lemmings_(Nintendo_Game_Boy)/04 Ronda Alla Turca.m4a` | 128.0 (127.7–128.0) | — | 4 | Stable | Stable |
| Turkish March / x68000 | `Lemmings_(Sharp_X68000)/15 Ronda Alla Turca.m4a` | 126.3 (126.0–126.3) | — | 4 | Stable | Stable |
| Turkish March / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/15 Tim 7 - Ronda Alla Turca.m4a` | 121.4 (121.2–121.5) | — | 4 | Stable | Stable |
| Turkish March / tandy | `Lemmings_Series_(Tandy_1000)/14 Alla Turca (Piano Sonata No. 11 III, Mozart).m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Stable |
| Turkish March / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_14.m4a` | 120.0 (119.8–120.0) | — | 4 | Stable | Stable |
| Turkish March / amiga | `lemmings_music_mod/tim7.mod` | 122.1 (121.8–122.1) | 122.0 | 4 | Stable | Stable |
| Dance of the Little Swans / archimedes | `Archimedes/05 - Dance of the Little Swans (Archimedes).mp3` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| Dance of the Little Swans / amiga | `CoLD SToRAGE - Lemmings - the original AMIGA game audio/CoLD SToRAGE - Lemmings - the original AMIGA game audio - 12 Lemmings - Dance of the Little Swans.wav` | 125.0 (125.0–125.0) | — | 4 | Stable | Stable |
| Dance of the Little Swans / snes | `Lemmings (MP3)/09 You Need Bashers This Time.mp3` | 139.1 (122.1–177.8) | — | 4 | Review | Review |
| Dance of the Little Swans / master-system | `Lemmings-SMS/Lemmings - 06 - Dance Of The Four Little Swans.m4a` | 125.0 (125.0–125.0) | — | 4 | Stable | Stable |
| Dance of the Little Swans / arcade | `Lemmings_(Arcade)/04 Allegro moderato (Swan Lake Act II No. 13 IV).m4a` | 166.7 (166.1–166.7) | — | 4 | Stable | Stable |
| Dance of the Little Swans / lynx | `Lemmings_(Atari_Lynx)/16 Dance Of The Four Little Swans.m4a` | 124.0 (124.0–124.4) | — | 4 | Stable | Stable |
| Dance of the Little Swans / fm-towns | `Lemmings_(FM_Towns)/16 Dance Of The Four Little Swans.m4a` | 122.4 (122.1–126.3) | — | 4 | Stable | Stable |
| Dance of the Little Swans / pc-98 | `Lemmings_(NEC_PC-9801)/15 Dance Of The Four Little Swans.m4a` | 120.6 (120.3–120.6) | — | 4 | Stable | Stable |
| Dance of the Little Swans / x68000 | `Lemmings_(Sharp_X68000)/16 Dance Of The Four Little Swans.m4a` | 126.3 (126.0–126.3) | — | 4 | Stable | Stable |
| Dance of the Little Swans / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/16 Tim 8 - Dance Of The Four Little Swans.m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Stable |
| Dance of the Little Swans / tandy | `Lemmings_Series_(Tandy_1000)/15 Allegro moderato (Swan Lake Act II No. 13 IV, Tchaikovsky).m4a` | 121.5 (121.2–155.3) | — | 4 | Review | Review |
| Dance of the Little Swans / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_15.m4a` | 120.0 (120.0–126.0) | — | 4 | Review | Review |
| Dance of the Little Swans / amiga | `lemmings_music_mod/tim8.mod` | 122.1 (121.8–130.1) | 122.0 | 4 | Review | Review |
| London Bridge Is Falling Down / archimedes | `Archimedes/12 - London Bridge is Falling Down (Archimedes).mp3` | 122.1 (121.8–122.1) | — | 4 | Stable | Stable |
| London Bridge Is Falling Down / amiga | `CoLD SToRAGE - Lemmings - the original AMIGA game audio/CoLD SToRAGE - Lemmings - the original AMIGA game audio - 11 Lemmings - London Bridge is Falling Down.wav` | 125.0 (124.7–125.3) | — | 4 | Stable | Stable |
| London Bridge Is Falling Down / snes | `Lemmings (MP3)/16 Patience.mp3` | 112.4 (112.2–112.4) | — | 4 | Stable | Review |
| London Bridge Is Falling Down / master-system | `Lemmings-SMS/Lemmings - 13 - London Bridge Is Falling Down.m4a` | 125.0 (125.0–125.0) | — | 4 | Review | Review |
| London Bridge Is Falling Down / arcade | `Lemmings_(Arcade)/11 London Bridge Is Falling Down.m4a` | 109.3 (109.1–109.3) | — | 4 | Stable | Stable |
| London Bridge Is Falling Down / lynx | `Lemmings_(Atari_Lynx)/17 London Bridge Is Falling Down.m4a` | 124.0 (124.0–124.4) | — | 4 | Stable | Stable |
| London Bridge Is Falling Down / fm-towns | `Lemmings_(FM_Towns)/17 London Bridge Is Falling Down.m4a` | 122.1 (122.1–134.8) | — | 4 | Review | Review |
| London Bridge Is Falling Down / pc-98 | `Lemmings_(NEC_PC-9801)/16 London Bridge Is Falling Down.m4a` | 133.0 (132.6–133.0) | — | 4 | Stable | Stable |
| London Bridge Is Falling Down / nes | `Lemmings_(NES)/08 Tim 9.m4a` | 298.1 (241.2–301.9) | — | — | Review | Review |
| London Bridge Is Falling Down / game-boy | `Lemmings_(Nintendo_Game_Boy)/03 London Bridge is Falling Down.m4a` | 149.5 (148.6–150.5) | — | 4 | Stable | Review |
| London Bridge Is Falling Down / x68000 | `Lemmings_(Sharp_X68000)/17 London Bridge Is Falling Down.m4a` | 135.6 (135.6–136.0) | — | 4 | Stable | Stable |
| London Bridge Is Falling Down / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/17 Tim 9 - London Bridge Is Falling Down.m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Stable |
| London Bridge Is Falling Down / tandy | `Lemmings_Series_(Tandy_1000)/16 London Bridge Is Falling Down (Traditional).m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Stable |
| London Bridge Is Falling Down / dos-opl2 | `Remixes/orig_music_mandelsoft/orig_16.m4a` | 120.0 (120.0–120.3) | — | 4 | Stable | Review |
| London Bridge Is Falling Down / amiga | `lemmings_music_mod/tim9.mod` | 122.1 (121.8–122.1) | 122.0 | 4 | Stable | Stable |

### demo

| Track / port | Source file | Estimated BPM (p10–p90) | Four-row clock | Beats/bar | BPM | Bars |
| --- | --- | ---: | ---: | ---: | --- | --- |
| Addamsfamily / amiga | `lemmings_demo_music_mod/addamsfamily.mod` | 129.4 (128.7–129.7) | 97.0 | 4 | Review | Review |
| Ateam / amiga | `lemmings_demo_music_mod/ateam.mod` | 122.1 (121.8–162.7) | 122.0 | 4 | Review | Review |
| Batman / amiga | `lemmings_demo_music_mod/batman.mod` | 158.9 (158.9–159.5) | 159.0 | 4 | Stable | Stable |
| Birdie / amiga | `lemmings_demo_music_mod/birdie.mod` | 145.9 (145.9–150.1) | 146.0 | 4 | Stable | Review |
| Can-Can / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/31 Can-Can.m4a` | 111.1 (107.4–114.8) | — | — | Review | Review |
| Cancan / amiga | `lemmings_demo_music_mod/cancan.mod` | 175.2 (164.7–175.2) | 175.0 | 2 | Review | Review |
| Daysnight / amiga | `lemmings_demo_music_mod/daysnight.mod` | 219.2 (175.3–300.0) | 159.0 | 4 | Review | Review |
| Doggie / amiga | `lemmings_demo_music_mod/doggie.mod` | 155.8 (152.9–156.4) | 195.0 | 4 | Review | Review |
| Entertainer / amiga | `lemmings_demo_music_mod/entertainer.mod` | 158.9 (158.9–159.5) | 159.0 | 4 | Stable | Stable |
| Hogan / amiga | `lemmings_demo_music_mod/hogan.mod` | 126.0 (125.7–126.0) | 252.0 | 4 | Stable | Stable |
| Matchespana / amiga | `lemmings_demo_music_mod/matchespana.mod` | 164.4 (155.8–183.9) | 195.0 | — | Review | Review |
| Missionimpos / amiga | `lemmings_demo_music_mod/missionimpos.mod` | 175.2 (174.5–175.8) | 175.0 | — | Stable | Review |
| Mountain / amiga | `lemmings_demo_music_mod/mountain.mod` | 100.8 (100.6–140.4) | 252.0 | 2 | Review | Review |
| Oblasuper / amiga | `lemmings_demo_music_mod/oblasuper.mod` | 125.7 (109.8–146.9) | 220.0 | 4 | Review | Review |
| Panther / amiga | `lemmings_demo_music_mod/panther.mod` | 134.1 (133.7–147.8) | 134.0 | 4 | Review | Review |
| Petergunn / amiga | `lemmings_demo_music_mod/petergunn.mod` | 122.1 (121.8–146.5) | 122.0 | 4 | Review | Review |
| Raindrops / amiga | `lemmings_demo_music_mod/raindrops.mod` | 130.8 (107.5–169.6) | 159.0 | — | Review | Review |
| Richman / amiga | `lemmings_demo_music_mod/richman.mod` | 175.2 (174.5–175.2) | 175.0 | 4 | Review | Review |
| Scoobydoo / amiga | `lemmings_demo_music_mod/scoobydoo.mod` | 146.8 (146.3–147.2) | 220.0 | 2 | Review | Review |
| Tenlemmings / amiga | `lemmings_demo_music_mod/tenlemmings.mod` | 165.5 (164.9–165.5) | 124.0 | 4 | Review | Review |
| Twist / amiga | `lemmings_demo_music_mod/twist.mod` | 175.2 (140.4–200.0) | 175.0 | 4 | Review | Review |

### holiday

| Track / port | Source file | Estimated BPM (p10–p90) | Four-row clock | Beats/bar | BPM | Bars |
| --- | --- | ---: | ---: | ---: | --- | --- |
| Jingle Bells / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/29 Jingle Bells.m4a` | 171.4 (145.5–182.5) | — | 4 | Review | Review |
| Jingle Bells / tandy | `Lemmings_Series_(Tandy_1000)/28 Jingle Bells (Pierpont).m4a` | 91.1 (90.9–116.5) | — | 2 | Review | Review |
| Jingle Bells / amiga | `holiday_lemmings_music_mod/jb.mod` | 134.1 (133.7–134.1) | 134.0 | 2 | Stable | Review |
| Good King Wenceslas / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/30 Good King Wenceslas.m4a` | 91.1 (90.9–91.1) | — | 2 | Stable | Review |
| Good King Wenceslas / tandy | `Lemmings_Series_(Tandy_1000)/29 Good King Wenceslas (Traditional).m4a` | 91.1 (90.9–91.1) | — | 4 | Stable | Review |
| Good King Wenceslas / amiga | `holiday_lemmings_music_mod/kw.mod` | 158.9 (158.4–159.5) | 159.0 | — | Stable | Review |
| Rudolph the Red-Nosed Reindeer / amiga | `holiday_lemmings_music_mod/rudi.mod` | 175.2 (174.5–200.0) | 175.0 | 4 | Review | Review |

### lemmings2

| Track / port | Source file | Estimated BPM (p10–p90) | Four-row clock | Beats/bar | BPM | Bars |
| --- | --- | ---: | ---: | ---: | --- | --- |
| Beach Tribe / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/07 Beach Tribe.m4a` | 159.5 (158.9–160.5) | — | 4 | Review | Review |
| Beach Tribe / amiga | `lemmings_2_music_mod_tsyu/beach.mod` | 157.9 (157.4–157.9) | 157.7 | 4 | Stable | Review |
| Cavelem Tribe / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/08 Cavelem Tribe.m4a` | 106.7 (106.7–106.9) | — | 4 | Stable | Stable |
| Cavelem Tribe / amiga | `lemmings_2_music_mod_tsyu/cavelem.mod` | 105.5 (105.3–134.8) | 105.4 | 4 | Review | Review |
| Circus Tribe / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/09 Circus Tribe.m4a` | 98.6 (83.0–131.5) | — | — | Review | Review |
| Circus Tribe / amiga | `lemmings_2_music_mod_tsyu/circus.mod` | 131.1 (82.1–131.5) | 97.5–262.5 | 2 | Review | Review |
| Classic Tribe / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/10 Classic Tribe.m4a` | 128.7 (127.3–140.4) | — | 4 | Review | Review |
| Classic Tribe / amiga | `lemmings_2_music_mod_tsyu/classic.mod` | 126.3 (126.0–132.2) | 126.0–252.0 | 4 | Review | Review |
| Bronze Medal / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/05 Bronze Medal.m4a` | — | — | — | Review | Review |
| Gold Medal / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/03 Gold Medal.m4a` | — | — | 3 | Review | Review |
| Let's Go! / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/02 Let's Go!.m4a` | — | — | — | Review | Review |
| Silver Medal / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/04 Silver Medal.m4a` | — | — | — | Review | Review |
| Tribe Complete / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/06 Tribe Complete.m4a` | — | — | — | Review | Review |
| Egyptian Tribe / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/11 Egyptian Tribe.m4a` | 110.9 (108.8–111.1) | — | 4 | Stable | Review |
| Egyptian Tribe / amiga | `lemmings_2_music_mod_tsyu/egyptian.mod` | 108.8 (108.1–108.8) | 108.9–217.7 | 4 | Review | Review |
| Ending / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/19 Ending.m4a` | 129.0 (112.9–153.8) | — | 4 | Review | Review |
| Ending / amiga | `lemmings_2_music_mod_tsyu/endtune.mod` | 161.3 (126.6–191.3) | 225.0 | 4 | Review | Review |
| Beach Tribe / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/04 Beach Tribe.m4a` | 132.2 (110.9–166.6) | — | — | Review | Review |
| Cavelem Tribe / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/11 Cavelem Tribe.m4a` | 372.1 (317.9–432.4) | — | — | Review | Review |
| Circus Tribe / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/08 Circus Tribe.m4a` | 366.4 (315.8–417.4) | — | — | Review | Review |
| Classic Tribe / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/07 Classic Tribe.m4a` | 268.2 (226.4–347.8) | — | — | Review | Review |
| Highland Tribe / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/09 Highland Tribe.m4a` | 126.6 (126.3–162.4) | — | 2 | Review | Review |
| Level Pane / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/03 Level Pane.m4a` | 184.6 (183.9–184.6) | — | 4 | Stable | Stable |
| Medieval Tribe / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/06 Medieval Tribe.m4a` | 112.4 (112.4–112.7) | — | 4 | Stable | Stable |
| Menu / Credits / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/02 Menu, Credits.m4a` | 108.4 (95.4–134.5) | — | — | Review | Review |
| Outdoors Tribe / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/05 Outdoors Tribe.m4a` | 260.9 (218.2–342.1) | — | — | Review | Review |
| Shadow Tribe / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/12 Shadow Tribe.m4a` | 129.7 (108.4–162.2) | — | — | Review | Review |
| Space Tribe / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/10 Space Tribe.m4a` | 176.5 (175.8–176.5) | — | 3 | Stable | Review |
| Sports Tribe / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/13 Sports Tribe.m4a` | 129.4 (129.0–152.9) | — | 4 | Review | Review |
| Story / Ending / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/01 Story, Ending.m4a` | 225.4 (224.3–226.4) | — | 3 | Stable | Review |
| Unknown 1 / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/14 Unknown 1.m4a` | 112.4 (112.4–124.1) | — | 4 | Review | Review |
| Unknown 2 / game-boy | `Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy)/15 Unknown 2.m4a` | 166.7 (141.2–205.1) | — | 4 | Review | Review |
| Highland Tribe / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/12 Highland Tribe.m4a` | 241.2 (194.3–246.2) | — | — | Review | Review |
| Highland Tribe / amiga | `lemmings_2_music_mod_tsyu/highland.mod` | 120.0 (120.0–137.1) | 120.0–240.0 | 4 | Review | Review |
| Main Theme / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/01 Main Theme.m4a` | 118.5 (118.2–118.8) | — | 4 | Stable | Stable |
| Main Theme / amiga | `lemmings_2_music_mod_tsyu/Maintune.mod` | 118.2 (117.9–134.8) | 472.0 | 4 | Review | Review |
| Medieval Tribe / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/13 Medieval Tribe.m4a` | 121.2 (120.9–121.2) | — | 4 | Stable | Stable |
| Medieval Tribe / amiga | `Remixes/amigamer_-_lemmingstribes_-_medieval_lemmings_remix_-_amigaremix_01812.mp3` | 120.0 (119.7–136.8) | — | 4 | Review | Review |
| Medieval Tribe / amiga | `lemmings_2_music_mod_tsyu/medieval.mod` | 120.6 (120.3–120.6) | 241.0 | 4 | Stable | Stable |
| Beach / Ending Theme / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/04 - Beach, Ending Theme.m4a` | 187.5 (186.8–188.2) | — | 4 | Stable | Review |
| Cavelem / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/05 - Cavelem.m4a` | 125.0 (124.7–125.3) | — | 4 | Stable | Review |
| Circus / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/06 - Circus.m4a` | 200.0 (200.0–200.0) | — | 4 | Stable | Stable |
| Classic / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/03 - Classic.m4a` | 200.0 (178.4–200.0) | — | 4 | Review | Review |
| Egyptian / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/07 - Egyptian.m4a` | 150.0 (149.5–166.8) | — | 4 | Review | Review |
| Highland / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/08 - Highland.m4a` | 125.0 (125.0–125.0) | — | 4 | Stable | Stable |
| Medieval / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/09 - Medieval.m4a` | 150.0 (150.0–150.0) | — | 4 | Stable | Stable |
| Opening Theme / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/01 - Opening Theme.m4a` | 125.0 (124.7–125.3) | — | — | Stable | Review |
| Outdoor / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/10 - Outdoor.m4a` | 200.0 (199.2–200.8) | — | 4 | Stable | Stable |
| Polar / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/11 - Polar.m4a` | 125.0 (124.7–126.0) | — | 2 | Review | Review |
| Shadow / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/12 - Shadow.m4a` | 100.0 (100.0–100.0) | — | 4 | Stable | Stable |
| Space / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/13 - Space.m4a` | 106.9 (85.7–124.8) | — | 3 | Review | Review |
| Sports / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/14 - Sports.m4a` | 150.5 (149.5–184.6) | — | 4 | Review | Review |
| Stage Clear / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/15 - Stage Clear.m4a` | 127.7 (111.7–133.4) | — | 4 | Review | Review |
| Title Theme / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/02 - Title Theme.m4a` | 125.0 (124.7–125.3) | — | — | Stable | Review |
| Unknown Track / mega-drive | `Lemmings 2 - The Tribes (Mega Drive, Genesis)/16 - Unknown Track.m4a` | 166.7 (166.7–166.7) | — | 2 | Review | Review |
| Outdoor Tribe / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/14 Outdoor Tribe.m4a` | 149.5 (149.1–150.0) | — | 4 | Stable | Stable |
| Outdoor Tribe / amiga | `lemmings_2_music_mod_tsyu/outdoor.mod` | 150.0 (149.1–150.9) | 300.0 | 4 | Review | Review |
| Polar Tribe / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/15 Polar Tribe.m4a` | 168.4 (167.8–168.4) | — | 4 | Stable | Review |
| Polar Tribe / amiga | `lemmings_2_music_mod_tsyu/polar.mod` | 169.0 (168.4–169.0) | 337.5 | 4 | Stable | Review |
| Shadow Tribe / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/16 Shadow Tribe.m4a` | 112.9 (112.7–123.9) | — | — | Review | Review |
| Shadow Tribe / amiga | `lemmings_2_music_mod_tsyu/shadow.mod` | 124.0 (112.4–150.0) | 225.0 | — | Review | Review |
| Space Tribe / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/17 Space Tribe.m4a` | 148.1 (142.9–202.5) | — | 3 | Review | Review |
| Space Tribe / amiga | `lemmings_2_music_mod_tsyu/space.mod` | 143.3 (136.8–169.6) | 114.0–288.0 | 4 | Review | Review |
| Sports Tribe / dos-opl2 | `Lemmings_2_-_The_Tribes_(IBM_PC_AT)/18 Sports Tribe.m4a` | 110.9 (110.9–125.1) | — | 4 | Review | Review |
| Sports Tribe / amiga | `lemmings_2_music_mod_tsyu/sports.mod` | 128.3 (112.4–156.9) | 112.5 | 4 | Review | Review |

### lemmings3

| Track / port | Source file | Estimated BPM (p10–p90) | Four-row clock | Beats/bar | BPM | Bars |
| --- | --- | ---: | ---: | ---: | --- | --- |
| Classic 1 / dos-opl2 | `All_New_World_of_Lemmings_(IBM_PC_AT)/03 Classic 1.m4a` | 131.5 (131.1–131.5) | — | 4 | Stable | Stable |
| Classic 1 / amiga | `lemmings_3_music_mod_tsyu/CLASSIC1.mod` | 129.4 (129.0–129.4) | 129.3 | 4 | Stable | Stable |
| Classic 2 / dos-opl2 | `All_New_World_of_Lemmings_(IBM_PC_AT)/04 Classic 2.m4a` | 131.5 (131.1–131.5) | — | 4 | Stable | Review |
| Classic 2 / amiga | `lemmings_3_music_mod_tsyu/CLASSIC2.mod` | 135.6 (135.2–135.6) | 135.4 | 4 | Stable | Stable |
| Classic 3 / dos-opl2 | `All_New_World_of_Lemmings_(IBM_PC_AT)/05 Classic 3.m4a` | 134.5 (134.1–134.5) | — | 4 | Stable | Stable |
| Classic 3 / amiga | `lemmings_3_music_mod_tsyu/CLASSIC3.mod` | 127.7 (127.7–128.0) | 127.7 | 4 | Stable | Stable |
| Egyptian 1 / dos-opl2 | `All_New_World_of_Lemmings_(IBM_PC_AT)/08 Egyptian 1.m4a` | 73.1 (72.9–73.1) | — | 4 | Review | Review |
| Egyptian 1 / amiga | `lemmings_3_music_mod_tsyu/EGYPT1.mod` | 80.3 (80.2–88.6) | 80.2 | 4 | Review | Review |
| Egyptian 2 / dos-opl2 | `All_New_World_of_Lemmings_(IBM_PC_AT)/09 Egyptian 2.m4a` | 122.8 (122.4–122.8) | — | 4 | Stable | Review |
| Egyptian 2 / amiga | `lemmings_3_music_mod_tsyu/EGYPT2.mod` | 123.4 (123.4–123.7) | 123.4 | 4 | Stable | Review |
| Frontend / dos-opl2 | `All_New_World_of_Lemmings_(IBM_PC_AT)/02 Frontend.m4a` | 110.1 (93.7–126.6) | — | — | Review | Review |
| Frontend / amiga | `lemmings_3_music_mod_tsyu/FRONTEND.mod` | 150.0 (126.6–150.0) | 337.5 | 4 | Review | Review |
| Intro / dos-opl2 | `All_New_World_of_Lemmings_(IBM_PC_AT)/01 Intro.m4a` | 115.7 (95.6–150.0) | — | 4 | Review | Review |
| Shadow 1 / dos-opl2 | `All_New_World_of_Lemmings_(IBM_PC_AT)/06 Shadow 1.m4a` | 99.4 (99.2–117.9) | — | 4 | Review | Review |
| Shadow 1 / amiga | `lemmings_3_music_mod_tsyu/SHADOW1.mod` | 123.4 (116.5–133.0) | 116.6 | 4 | Review | Review |
| Shadow 2 / dos-opl2 | `All_New_World_of_Lemmings_(IBM_PC_AT)/07 Shadow 2.m4a` | 116.8 (114.6–121.2) | — | — | Review | Review |
| Shadow 2 / amiga | `lemmings_3_music_mod_tsyu/SHADOW2.mod` | 120.0 (105.4–120.3) | 105.4–120.0 | 4 | Review | Review |

### lemmings3d

| Track / port | Source file | Estimated BPM (p10–p90) | Four-row clock | Beats/bar | BPM | Bars |
| --- | --- | ---: | ---: | ---: | --- | --- |
| Alien 1 / dos-opl3 | `Lemmings_3D_(PC)/09 Alien 1.m4a` | 93.9 (93.8–93.9) | — | 4 | Stable | Stable |
| Alien 2 / dos-opl3 | `Lemmings_3D_(PC)/14 Alien 2.m4a` | 95.8 (89.9–119.7) | — | 4 | Review | Review |
| Alien 3 / dos-opl3 | `Lemmings_3D_(PC)/29 Alien 3.m4a` | 219.2 (218.2–220.2) | — | 6 | Stable | Stable |
| Army 1 / dos-opl3 | `Lemmings_3D_(PC)/03 Army 1.m4a` | 104.8 (104.8–105.0) | — | 4 | Stable | Stable |
| Army 2 / dos-opl3 | `Lemmings_3D_(PC)/19 Army 2.m4a` | 104.8 (104.8–105.0) | — | 4 | Stable | Stable |
| Army 3 / dos-opl3 | `Lemmings_3D_(PC)/31 Army 3.m4a` | 114.8 (114.6–115.1) | — | 4 | Stable | Stable |
| Circus 1 / dos-opl3 | `Lemmings_3D_(PC)/05 Circus 1.m4a` | 99.8 (99.8–100.0) | — | 4 | Stable | Stable |
| Circus 2 / dos-opl3 | `Lemmings_3D_(PC)/24 Circus 2.m4a` | 109.8 (109.6–109.8) | — | 4 | Stable | Stable |
| Circus 3 / dos-opl3 | `Lemmings_3D_(PC)/32 Circus 3.m4a` | 104.8 (104.8–105.0) | — | 4 | Stable | Stable |
| Computer Zone 1 / dos-opl3 | `Lemmings_3D_(PC)/06 Computer Zone 1.m4a` | 124.7 (124.7–153.4) | — | 4 | Review | Review |
| Computer Zone 2 / dos-opl3 | `Lemmings_3D_(PC)/18 Computer Zone 2.m4a` | 119.7 (119.7–127.7) | — | 4 | Review | Review |
| Computer Zone 3 / dos-opl3 | `Lemmings_3D_(PC)/36 Computer Zone 3.m4a` | 114.8 (114.8–139.2) | — | 4 | Review | Review |
| Egypt 1 / dos-opl3 | `Lemmings_3D_(PC)/07 Egypt 1.m4a` | 99.8 (99.6–106.7) | — | 4 | Review | Review |
| Egypt 2 / dos-opl3 | `Lemmings_3D_(PC)/21 Egypt 2.m4a` | 106.9 (106.7–106.9) | — | 4 | Stable | Stable |
| Egypt 3 / dos-opl3 | `Lemmings_3D_(PC)/35 Egypt 3.m4a` | 123.7 (115.7–151.4) | — | 4 | Review | Review |
| Ending and Main Menu / dos-opl3 | `Lemmings_3D_(PC)/38 Ending and Main Menu.m4a` | 99.8 (99.8–100.0) | — | 4 | Stable | Stable |
| Failed / dos-opl3 | `Lemmings_3D_(PC)/20 Failed.m4a` | 118.8 (117.6–140.2) | — | 2 | Review | Review |
| Fun Rating Jingle / dos-opl3 | `Lemmings_3D_(PC)/02 Fun Rating Jingle.m4a` | 109.1 (109.1–110.1) | — | 4 | Review | Review |
| Garden 1 / dos-opl3 | `Lemmings_3D_(PC)/04 Garden 1.m4a` | 200.0 (199.2–200.8) | — | 6 | Stable | Review |
| Garden 2 / dos-opl3 | `Lemmings_3D_(PC)/16 Garden 2.m4a` | 114.8 (114.6–114.8) | — | 4 | Stable | Stable |
| Garden 3 / dos-opl3 | `Lemmings_3D_(PC)/26 Garden 3.m4a` | 124.7 (124.7–125.0) | — | 4 | Stable | Stable |
| Golf 1 / dos-opl3 | `Lemmings_3D_(PC)/10 Golf 1.m4a` | 94.9 (94.7–115.0) | — | 4 | Review | Review |
| Golf 2 / dos-opl3 | `Lemmings_3D_(PC)/25 Golf 2.m4a` | 109.8 (109.6–109.8) | — | 4 | Stable | Stable |
| Golf 3 / dos-opl3 | `Lemmings_3D_(PC)/34 Golf 3.m4a` | 124.7 (124.7–125.0) | — | 4 | Stable | Stable |
| Lego 1 / dos-opl3 | `Lemmings_3D_(PC)/12 Lego 1.m4a` | 99.8 (99.8–100.0) | — | 4 | Stable | Review |
| Lego 2 / dos-opl3 | `Lemmings_3D_(PC)/15 Lego 2.m4a` | 104.8 (104.8–105.0) | — | 4 | Stable | Stable |
| Lego 3 / dos-opl3 | `Lemmings_3D_(PC)/27 Lego 3.m4a` | 129.7 (129.7–130.1) | — | 6 | Stable | Review |
| Mayhem Rating Jingle / dos-opl3 | `Lemmings_3D_(PC)/28 Mayhem Rating Jingle.m4a` | 217.2 (174.8–284.0) | — | 4 | Review | Review |
| Medieval 1 / dos-opl3 | `Lemmings_3D_(PC)/11 Medieval 1.m4a` | 98.0 (94.7–126.6) | — | 3 | Review | Review |
| Medieval 2 / dos-opl3 | `Lemmings_3D_(PC)/23 Medieval 2.m4a` | 96.0 (95.8–127.7) | — | 3 | Review | Review |
| Medieval 3 / dos-opl3 | `Lemmings_3D_(PC)/33 Medieval 3.m4a` | 111.9 (111.6–124.0) | — | 4 | Review | Review |
| Opening Title / dos-opl3 | `Lemmings_3D_(PC)/01 Opening Title.m4a` | 99.8 (99.8–100.0) | — | 4 | Stable | Stable |
| Success / dos-opl3 | `Lemmings_3D_(PC)/37 Success.m4a` | 100.0 (96.8–101.4) | — | 2 | Review | Review |
| Sweet Land 1 / dos-opl3 | `Lemmings_3D_(PC)/13 Sweet Land 1.m4a` | 243.7 (215.2–243.7) | — | 4 | Review | Review |
| Sweet Land 2 / dos-opl3 | `Lemmings_3D_(PC)/22 Sweet Land 2.m4a` | 121.8 (121.5–122.1) | — | 4 | Review | Review |
| Sweet Land 3 / dos-opl3 | `Lemmings_3D_(PC)/30 Sweet Land 3.m4a` | 117.9 (117.6–125.7) | — | 4 | Review | Review |
| Taxing Rating Jingle / dos-opl3 | `Lemmings_3D_(PC)/17 Taxing Rating Jingle.m4a` | 139.5 (139.5–154.0) | — | — | Review | Review |
| Tricky Rating Jingle / dos-opl3 | `Lemmings_3D_(PC)/08 Tricky Rating Jingle.m4a` | 278.4 (254.7–305.8) | — | 5 | Review | Review |

### ohno

| Track / port | Source file | Estimated BPM (p10–p90) | Four-row clock | Beats/bar | BPM | Bars |
| --- | --- | ---: | ---: | ---: | --- | --- |
| ohno_01 / dos-opl2 | `Remixes/ohno_music_mandelsoft/ohno_01.m4a` | 131.9 (131.9–132.2) | — | 4 | Stable | Stable |
| ohno_02 / dos-opl2 | `Remixes/ohno_music_mandelsoft/ohno_02.m4a` | 126.0 (126.0–126.3) | — | 4 | Stable | Stable |
| ohno_03 / dos-opl2 | `Remixes/ohno_music_mandelsoft/ohno_03.m4a` | 131.9 (131.9–132.2) | — | 4 | Stable | Stable |
| ohno_04 / dos-opl2 | `Remixes/ohno_music_mandelsoft/ohno_04.m4a` | 110.1 (109.8–110.1) | — | 4 | Stable | Stable |
| ohno_05 / dos-opl2 | `Remixes/ohno_music_mandelsoft/ohno_05.m4a` | 150.0 (149.5–150.5) | — | 4 | Stable | Stable |
| ohno_06 / dos-opl2 | `Remixes/ohno_music_mandelsoft/ohno_06.m4a` | 142.0 (141.6–142.0) | — | 4 | Stable | Stable |
| Very Cute / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/23 Very Cute.m4a` | 136.4 (136.4–136.8) | — | 4 | Stable | Stable |
| Very Cute / tandy | `Lemmings_Series_(Tandy_1000)/22 Very Cute.m4a` | 136.4 (136.4–136.8) | — | 4 | Stable | Stable |
| Very Cute / amiga | `oh_no_more_lemmings_music_mod/tune1.mod` | 134.8 (134.8–135.2) | 270.0 | 4 | Stable | Stable |
| Wacky / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/24 Wacky.m4a` | 121.5 (121.2–129.4) | — | 4 | Review | Review |
| Wacky / tandy | `Lemmings_Series_(Tandy_1000)/23 Wacky.m4a` | 121.5 (121.2–121.5) | — | 4 | Stable | Stable |
| Wacky / amiga | `oh_no_more_lemmings_music_mod/tune2.mod` | 218.7 (166.7–265.9) | 190.0 | — | Review | Review |
| Patronizingly Happy / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/25 Patronizingly Happy.m4a` | 136.8 (136.4–145.5) | — | 4 | Review | Review |
| Patronizingly Happy / tandy | `Lemmings_Series_(Tandy_1000)/24 Patronizingly Happy.m4a` | 136.8 (132.2–145.9) | — | 4 | Review | Review |
| Patronizingly Happy / amiga | `oh_no_more_lemmings_music_mod/tune3.mod` | 137.1 (136.8–141.8) | 137.0 | 4 | Review | Review |
| Much Joviality / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/27 Much Joviality.m4a` | 155.8 (155.8–156.4) | — | 4 | Stable | Stable |
| Much Joviality / tandy | `Lemmings_Series_(Tandy_1000)/26 Much Joviality.m4a` | 155.8 (147.2–156.4) | — | 4 | Review | Review |
| Much Joviality / amiga | `oh_no_more_lemmings_music_mod/tune4.mod` | 103.4 (103.4–103.7) | 207.0 | 4 | Stable | Stable |
| Not At All Serious / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/28 Not At All Serious.m4a` | 155.8 (155.8–156.4) | — | 4 | Stable | Stable |
| Not At All Serious / tandy | `Lemmings_Series_(Tandy_1000)/27 Not At All Serious.m4a` | 100.6 (90.9–126.3) | — | — | Review | Review |
| Not At All Serious / amiga | `oh_no_more_lemmings_music_mod/tune5.mod` | 162.7 (162.7–163.3) | 163.0 | 4 | Stable | Stable |
| The Smiling Blues / dos-opl2 | `Lemmings_Series_(IBM_PC_AT)/26 The Smiling Blues.m4a` | 109.3 (109.1–109.3) | — | 4 | Stable | Stable |
| The Smiling Blues / tandy | `Lemmings_Series_(Tandy_1000)/25 The Smiling Blues.m4a` | 91.1 (90.9–91.1) | — | 4 | Stable | Stable |
| The Smiling Blues / amiga | `oh_no_more_lemmings_music_mod/tune6.mod` | 154.8 (154.8–155.3) | 155.0 | 4 | Stable | Stable |

### paintball

| Track / port | Source file | Estimated BPM (p10–p90) | Four-row clock | Beats/bar | BPM | Bars |
| --- | --- | ---: | ---: | ---: | --- | --- |
| Paintball 01 (MandelSoft) / windows | `Remixes/paintball_music_mandelsoft/lpb_01.m4a` | 96.0 (95.8–96.2) | — | 4 | Stable | Stable |
| Paintball 02 (MandelSoft) / windows | `Remixes/paintball_music_mandelsoft/lpb_02.m4a` | 132.6 (132.2–132.6) | — | 4 | Stable | Stable |
| Paintball 03 (MandelSoft) / windows | `Remixes/paintball_music_mandelsoft/lpb_03.m4a` | 130.1 (129.7–130.1) | — | 4 | Stable | Stable |
| Paintball 04 (MandelSoft) / windows | `Remixes/paintball_music_mandelsoft/lpb_04.m4a` | 140.4 (139.9–181.1) | — | — | Review | Review |
| Paintball 05 (MandelSoft) / windows | `Remixes/paintball_music_mandelsoft/lpb_05.m4a` | 105.0 (104.8–105.0) | — | 4 | Stable | Stable |
