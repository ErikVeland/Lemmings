# Music inventory

Audited 25 September 2026 from `Sources/Music`. These are playable files, not a count of unique compositions.

85 source files: 73 modules and 12 recordings. Build 44 contains 85 playable files. WAV sources are packaged as Apple Lossless M4A.

## Reference

[Music in Lemmings](https://lemmings.fandom.com/wiki/Music_in_Lemmings) is the guiding reference for names and rotation. The original cycle in code follows its 17-track order, with special-level overrides. The file `tenlemmings.mod` corresponds to its `TenLems` name. Tim8 maps to **Dance of the Little Swans**; Tim10 maps to **Forest Green**. The streaming substitute **Lemmings Are Ducks** is not an original game track.

## Included tracks

### CoLD SToRAGE - Lemmings - the original AMIGA game audio (12)

- 01 Lemmings - Awesome
- 02 Lemmings - Shadow of the Beast II
- 03 Lemmings - Rainbow Islands
- 04 Lemmings - Smile if you Love Lemmings
- 05 Lemmings - Lend a Helping Hand
- 06 Lemmings - Postcard from Lemmingland
- 07 Lemmings - Mind the Step
- 08 Lemmings - Dance of the Reed Flutes
- 09 Lemmings - Turkish March
- 10 Lemmings - Forest Green
- 11 Lemmings - London Bridge is Falling Down
- 12 Lemmings - Dance of the Little Swans

### holiday_lemmings_music_mod (3)

- jb
- kw
- rudi

### lemmings_2_music_mod_tsyu (14)

- Maintune
- beach
- cavelem
- circus
- classic
- egyptian
- endtune
- highland
- medieval
- outdoor
- polar
- shadow
- space
- sports

### lemmings_3_music_mod_tsyu (8)

- CLASSIC1
- CLASSIC2
- CLASSIC3
- EGYPT1
- EGYPT2
- FRONTEND
- SHADOW1
- SHADOW2

### lemmings_demo_music_mod (20)

- addamsfamily
- ateam
- batman
- birdie
- cancan
- daysnight
- doggie
- entertainer
- hogan
- matchespana
- missionimpos
- mountain
- oblasuper
- panther
- petergunn
- raindrops
- richman
- scoobydoo
- tenlemmings
- twist

### lemmings_music_mod (22)

- awesome
- beastI
- beastII
- cancan
- doggie
- intro
- lemming1
- lemming2
- lemming3
- menace
- mountain
- tenlemmings
- tim1
- tim10
- tim2
- tim3
- tim4
- tim5
- tim6
- tim7
- tim8
- tim9

### oh_no_more_lemmings_music_mod (6)

- tune1
- tune2
- tune3
- tune4
- tune5
- tune6

## Platform and composition gaps

| Collection | Present | Missing or unverified |
| --- | --- | --- |
| Original Amiga | 17 ordinary themes, four special themes, intro | No missing theme found in this named set |
| Oh No! More Lemmings | Six Amiga tunes | Native DOS, console and other platform arrangements |
| Holiday / Xmas | Three seasonal modules | Platform-specific arrangements and edition ordering need comparison |
| Lemmings 2 | 12 tribe themes, main theme, end theme | Native DOS and console arrangements |
| Lemmings 3 | Three Classic, two Shadow, two Egyptian, frontend | Original platform fidelity and level order need reference playback |
| Demo / prototype | 20 modules | Historical completeness unverified; separate from the released soundtrack |
| CoLD SToRAGE album | 12 recordings | CanCan, Lemming1/2/3, Doggie, TenLems, Mountain, BeastI, Menace and intro |
| DOS | 21 named tunes in source archive; OPL2 synthesis code | No playable AdLib soundtrack in the music library |
| Macintosh | 21 MIDI tunes and 77 sampled instruments in disk image | No playable native Mac soundtrack in the music library |
| NES, SNES, Master System, Game Gear, Mega Drive | No soundtrack recordings | Native renditions and any platform-exclusive tunes |
| Windows, PlayStation, 3DO, CD-i | No identified soundtrack folders | MIDI/rendered arrangements listed by the reference |
| Atari ST, C64, ZX Spectrum, Amstrad, Acorn, Lynx, Game Boy, PC Engine, Japanese computer and CD ports | No identified music folders | Inventory and comparison still required; absence here does not establish how many tunes each port has |

The album is a selection by the original composer, not a complete replacement for the game score. [Composer album and track list](https://coldstorage.bandcamp.com/album/lemmings-the-original-amiga-game-audio).

## Specific missing platform material

- The original Acorn Archimedes edition adds a **Mad Professor Mariarti** theme. No corresponding track is present here. [Game music reference](https://lemmings.fandom.com/wiki/Lemmings).
- Macintosh Holiday includes **Frosty the Snowman**, absent from the three bundled seasonal modules. DOS Holiday uses **Forest Green**, which exists in the original module set but is not a native DOS recording. [Holiday soundtrack reference](https://lemmings.fandom.com/wiki/Holiday_Lemmings_1993).
- Acorn Oh No! has **26 distinct arrangements**, rather than the six Amiga tunes. That collection is missing. DOS Oh No! also uses longer versions with different ordering. [Oh No! soundtrack reference](https://lemmings.fandom.com/wiki/Oh_No%21_More_Lemmings).

These are confirmed gaps from the references. The wider platform table is an audit backlog, not a claim that all ports contain exclusive compositions.

## Remix candidates

- [MandelSoft’s FL Studio arrangements](https://www.lemmingsforums.net/index.php?topic=3921.0): covers the ordinary Original and Oh No! tracks. The author reports that special-level arrangements are unfinished. Downloads are OGG; convert to a supported recording format before import. The author permits use in level packs with credit.
- [CoLD SToRAGE — March of the Greentops](https://coldstorage.bandcamp.com/track/lemmings-march-of-the-greentops): a composer remix to audition. Not installed.

These links are candidates, not newly bundled tracks. No fan recordings were downloaded in this change.

## Playback rules and validation limits

- A level selects its named module, or a matching recording. An incomplete recording album falls back to the module. File sorting and shuffle no longer choose an arbitrary song within the selected album.
- The DJ does not rotate on a timer, rescue quota, release rate, danger or nuke. A completed result can trigger one result cue.
- Retries restart the assigned tune. Repeated refresh calls for the same attempt do not restart it.
- Module transitions use tracker tempo and a four-row beat grid, equal-power gains and a low-shelf bass handover. Tempo matching is limited to nearby tempos (within 8%). This is beat alignment, not automatic phrase or key analysis.
- Recordings have no analysed beat grid. They use the EQ/gain crossfade; do not describe them as beat-matched.
- There is no identified failure track bundled. The DJ retains the level tune when it cannot find an explicit failure cue.
- The reference page describes a completion-driven cycle rather than universal per-level assignments. This app uses a stable campaign-index mapping into that cycle so opening a level directly and retrying are predictable. The Amiga named rotation is the default playback policy, even when another platform supplies artwork. Native platform-specific sequencing is not yet verified.
- Fan level custom song references are not yet a complete import pipeline. Missing external tracks cannot be guaranteed.
