# Audio coverage

The level owns its assigned track. The Adaptive DJ keeps it for active play and
uses the catalogue for deterministic versions of that tune and completed result cues. It does not rotate on
a timer or react to rescue quota, danger, release rate or nuke.

See [Music inventory](MusicInventory.md) for every included track, platform
gaps and remix candidates. Module transitions use tracker beat timing and EQ.
Recordings without a beat grid use an EQ crossfade.

The library searches the bundled `Music` directory and the optional
`~/Library/Application Support/Ultimate Lemmings/Soundtracks` directory,
including nested folders.

The DJ supports these decoded file formats:

| Format | Status | Import location |
| --- | --- | --- |
| Amiga ProTracker `.mod` | Playable by the native module player | Bundle `Music` or Application Support |
| WAV, AIFF, AIFF-C, MP3, M4A, CAF, FLAC | Playable by the decoded audio deck | `Sources/Music/<platform>/` or Application Support |

Put a port in its own folder, for example:

```text
Sources/Music/
  nes/
    title.wav
  snes/
    level-theme.m4a
  master_system/
    level-theme.aiff
  genesis_megadrive/
    cancan.flac
  dos/
    adlib-render.wav
  macintosh/
    midi-render.m4a
```

The bundle script preserves supported files and converts source WAV files to
Apple Lossless M4A for the application bundle. Lemmings 2 and Lemmings 3
module folders are also included when their corresponding game data is built.

## Formats still missing a native playback path

The app has no native playback path for the raw formats below. Several ports
now have converted recordings in the local library:

| Port | Raw format | Current position | Practical input now |
| --- | --- | --- | --- |
| NES / Famicom | NSF / NSFe | No NES APU player | Supply a rendered WAV, AIFF, M4A or FLAC |
| SNES | SPC / RSN | No SPC700 and BRR decoder | Supply a rendered WAV, AIFF, M4A or FLAC |
| Sega Master System | VGM / VGZ | No SN76489 or VGM player | Supply a rendered WAV, AIFF, M4A or FLAC |
| Genesis / Mega Drive | VGM / GYM | No YM2612 or VGM player | Supply a rendered WAV, AIFF, M4A or FLAC |
| DOS | `ADLIB.DAT` / OPL2 sequence | OPL2 synthesis exists, but the Lemmings sequence driver is not decoded | Supply a rendered WAV, AIFF, M4A or FLAC |
| Macintosh | MIDI and Sound Manager resources | Resources can be audited, but there is no MIDI or Sound Manager music player | Supply a rendered WAV, AIFF, M4A or FLAC |

This checkout now includes NES, SNES, Master System, Genesis/Mega Drive, DOS
and Archimedes recordings, among other ports. Macintosh recordings remain
unavailable. See the current source audit for coverage and provenance. The
catalogue offers 495 playable versions and preserves special, seasonal and
port-specific identities. Conversion does not provide native raw-format playback.

Do not add downloaded game rips or user-sequenced arrangements to the
repository unless their redistribution rights are clear. If you provide
licensed renders locally, the library can discover them. Assigned level playback also needs a
matching tune name. Raw NSF, SPC, RSN, VGM, VGZ, GYM, MIDI and `ADLIB.DAT` files are not
silently added to the pool because the current audio deck cannot decode them.

## Source and rights notes

External projects can help identify formats and guide future decoder work, but
they do not automatically grant redistribution rights. A future import tool
can render raw formats into the supported lossless formats after the required
permissions and source-engine fidelity have been confirmed.

## NeoLemmix gameplay effects

The development build routes NeoLemmix hatch, successful skill assignment,
rescue, death and nuke events through the selected Classic sound bank and
spatial sound player. This fixes the empty sound output in 1.7.9. Assignment
cues play between ticks. Queued nuke cues play when the simulation processes
the command. Undo and saved-run restoration clear pending presentation cues.

Death sounds play at the start of their animation, without repeating when the
lemming is removed. Immediate trap deaths and falls out of the level retain
the lemming's position. The existing bottom-fall preference still applies.

The 7 October development source adds the remaining three documented SFX paths:

- Builder and Platformer warnings play on frame 10 of the final three bricks.
  Stacker warnings play after decrementing the final three brick counts.
- Digger, Basher, Fencer and Miner steel contacts request the selected bank's
  steel effect. One-way terrain does not request a steel sound. Lookahead
  probes cannot play effects.
- Trap, teleporter, button and triggered-animation events use their resolved
  object `SOUND` name. A custom trap sound replaces the generic death cue.
  Disarming a trap does not play its killing sound.

Preparation includes the nine stock WAV samples named by the bundled DMA
objects. The manifest records their pinned CE source hashes. Packaging rejects
missing or changed stock samples. All nine prepared WAV files pass decoding
without audio output. NeoLemmix replay regression tests also pass. Other samples
remain player-supplied in `sound/`, beside the imported `styles/` directory.
The loader accepts Ogg, WAV, AIFF, AIF, MP3 and M4A when AVFoundation can decode
them. Player files override stock samples. It rejects paths outside the sound
folder and bounds compressed size and decoded frame count. Samples load when
a level opens, then use the existing spatial voices, mute, volume and movie
capture paths. Loading another level replaces the named sample cache.

This closes those three adapter omissions. It does not establish complete CE
audio parity. Pickup, exit-unlock, swimming, disarmer-work, portal, state-change
and other CE-specific feedback remain separate coverage work. Imported codec
support on older macOS versions and an audible listening check remain unverified.
Gameplay rules remain unchanged. The event stream adds warning and steel-contact
cases and sound-bearing animation triggers. Those events round-trip through
existing simulation recovery encoding.

Twelve muted audio regression tests pass, including all constructive warnings,
all four destructive steel contacts, one-way silence, named sample playback,
trap replacement, disarm silence, metadata identity, mute, cache replacement
and recovery continuation. The 29-group NeoLemmix simulation suite passes.
The full package run passes 76 core and 13 mobile tests. Its 38 app tests have
one failure outside audio: the learning journey has no usable hint replay for
`Mienrs <--- lol, typo`. All 12 audio tests pass in that full run.
No audible playback test was run.

## Music after a nuke

The development build separates funeral tempo from the failed-run visual
transition. Classic, NeoLemmix and Lemmings 2 restore normal music speed over
0.9 seconds after their final pop, including when the run ends in failure.
The return continues without simulation ticks on the result screen. The nuke
filter keeps its existing shorter return. A normal loss still keeps the dirge,
and rewinding into an unfinished nuke can restore it. This tempo recovery also
works with HD Effects disabled.

Lemmings 3 has no mass nuke. Its ordinary funeral transition is unchanged.
Regression checks for tempo recovery run with audio muted; audible playback
was not tested.
