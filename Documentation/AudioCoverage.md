# Audio coverage

The level owns its assigned track. The Adaptive DJ keeps it for active play and
only uses the shared library for completed result cues. It does not rotate on
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

The repository does not currently contain these soundtrack files or a native
decoder for their raw source formats:

| Port | Raw format | Current position | Practical input now |
| --- | --- | --- | --- |
| NES / Famicom | NSF / NSFe | No NES APU player | Supply a rendered WAV, AIFF, M4A or FLAC |
| SNES | SPC / RSN | No SPC700 and BRR decoder | Supply a rendered WAV, AIFF, M4A or FLAC |
| Sega Master System | VGM / VGZ | No SN76489 or VGM player | Supply a rendered WAV, AIFF, M4A or FLAC |
| Genesis / Mega Drive | VGM / GYM | No YM2612 or VGM player | Supply a rendered WAV, AIFF, M4A or FLAC |
| DOS | `ADLIB.DAT` / OPL2 sequence | OPL2 synthesis exists, but the Lemmings sequence driver is not decoded | Supply a rendered WAV, AIFF, M4A or FLAC |
| Macintosh | MIDI and Sound Manager resources | Resources can be audited, but there is no MIDI or Sound Manager music player | Supply a rendered WAV, AIFF, M4A or FLAC |

This checkout currently has no supplied NES, SNES, Master System,
Genesis/Mega Drive, DOS or Macintosh soundtrack renders. It has the inventory
and audit scaffolding, but that is not the same as playable audio.

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
