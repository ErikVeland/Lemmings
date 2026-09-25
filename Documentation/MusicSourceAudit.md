# Downloaded soundtrack source audit

Snapshot: 25 September 2026. Counts exclude the `By Track` symlink view. Package notes are evidence from the downloaded releases; historical and completeness claims below are attributed to those notes, not independent listening verification.

## Files and provenance

The folder contains **304 VGZ, 22 files named VGM, 23 OGG, 73 MOD, 12 WAV, 51 MP3 and 350 M4A files**. Converted counterparts are not additional compositions. There are **486 directly playable files**. The current [track catalogue](MusicTrackCatalogue.md) now groups all 486 files into 226 identities. Identity counts depend on classification and are not a verified count of unique compositions.

The conversion report records 349 conversions and 0 failures. See [conversion details](MusicConversion.md) for decoder validation and the finite-loop limitation.

| Source folder | Original formats | M4A counterparts/source | Package provenance |
| --- | --- | ---: | --- |
| All_New_World_of_Lemmings_(IBM_PC_AT) | 9 VGZ | 9 | MrKsoft; v1.10; [notes](../Sources/Music/All_New_World_of_Lemmings_%28IBM_PC_AT%29/All%20New%20World%20of%20Lemmings.txt) |
| CoLD SToRAGE - Lemmings - the original AMIGA game audio | 12 WAV | 0 | No package readme |
| Lemmings (Mega Drive, Genesis) | 25 VGZ | 25 | 2ch-N; v1.06; [notes](../Sources/Music/Lemmings%20%28Mega%20Drive%2C%20Genesis%29/Lemmings.txt) |
| Lemmings 2 - The Tribes (Mega Drive, Genesis) | 16 VGZ | 16 | 2ch-N; v1.00; [notes](../Sources/Music/Lemmings%202%20-%20The%20Tribes%20%28Mega%20Drive%2C%20Genesis%29/Lemmings%202%20-%20The%20Tribes.txt) |
| Lemmings_(Arcade) | 18 VGZ | 18 | Paul999; v1.01; [notes](../Sources/Music/Lemmings_%28Arcade%29/Lemmings.txt) |
| Lemmings_(Atari_Lynx) | 19 VGZ | 19 | GTheGuardian; v1.00; [notes](../Sources/Music/Lemmings_%28Atari_Lynx%29/Lemmings.txt) |
| Lemmings_(FM_Towns) | 22 VGZ | 22 | GTheGuardian; v1.00; [notes](../Sources/Music/Lemmings_%28FM_Towns%29/Lemmings.txt) |
| Lemmings_(NEC_PC-9801) | 21 VGZ | 21 | GTheGuardian; v1.00; [notes](../Sources/Music/Lemmings_%28NEC_PC-9801%29/Lemmings.txt) |
| Lemmings_(NES) | 10 VGZ | 10 | Sonic of 8!; v1.00; [notes](../Sources/Music/Lemmings_%28NES%29/Lemmings.txt) |
| Lemmings_(Nintendo_Game_Boy) | 9 VGZ | 9 | The789Guy; v1.00; [notes](../Sources/Music/Lemmings_%28Nintendo_Game_Boy%29/Lemmings.txt) |
| Lemmings_(Sharp_X68000) | 22 VGZ | 22 | GTheGuardian; v1.01; [notes](../Sources/Music/Lemmings_%28Sharp_X68000%29/Lemmings.txt) |
| Lemmings_(ZX_Spectrum_128) | 1 VGZ | 1 | Sonic of 8!; v1.00; [notes](../Sources/Music/Lemmings_%28ZX_Spectrum_128%29/Lemmings.txt) |
| Lemmings_2_-_The_Tribes_(IBM_PC_AT) | 19 VGZ | 19 | MrKsoft; v1.00; [notes](../Sources/Music/Lemmings_2_-_The_Tribes_%28IBM_PC_AT%29/Lemmings%202%20-%20The%20Tribes.txt) |
| Lemmings_2_-_The_Tribes_(Nintendo_Game_Boy) | 15 VGZ | 15 | The789Guy; v1.00; [notes](../Sources/Music/Lemmings_2_-_The_Tribes_%28Nintendo_Game_Boy%29/Lemmings%202%20-%20The%20Tribes.txt) |
| Lemmings_3D_(PC) | 38 VGZ | 38 | Valley Bell; v1.00; [notes](../Sources/Music/Lemmings_3D_%28PC%29/Lemmings%203D.txt) |
| Lemmings_Series_(IBM_PC_AT) | 31 VGZ | 31 | Valley Bell; v1.10; [notes](../Sources/Music/Lemmings_Series_%28IBM_PC_AT%29/Lemmings%20Series.txt) |
| Lemmings_Series_(Tandy_1000) | 29 VGZ | 29 | NewRisingSun; v1.02; [notes](../Sources/Music/Lemmings_Series_%28Tandy_1000%29/Lemmings%20Series.txt) |
| Remixes | 23 OGG, 1 MP3 | 24 | No package readme |
| holiday_lemmings_music_mod | 3 MOD | 0 | No package readme |
| lemmings_2_music_mod_tsyu | 14 MOD | 0 | No package readme |
| lemmings_3_music_mod_tsyu | 8 MOD | 0 | No package readme |
| lemmings_demo_music_mod | 20 MOD | 0 | No package readme |
| lemmings_music_mod | 22 MOD | 0 | No package readme |
| oh_no_more_lemmings_music_mod | 6 MOD | 0 | No package readme |

## Findings from package notes and track lists

- **DOS Classic / Oh No! / Xmas:** Valley Bell v1.10 has 31 tracks: 22 Classic entries including the start cue, six Oh No! themes, two new seasonal themes and a demo Can-Can. The Xmas playlist also reuses Forest Green. The notes say Holiday 1994 uses Oh No! music. Demo Can-Can is excluded from the supplied playlists. Version 1.10 reripped Tim 1; this is distinct from VGMPF's warning about its older incomplete recording. Logs came from DOSBox 0.65/0.74, with timing and loop repairs described in the readme.
- **Tandy:** NewRisingSun v1.02 has 29 entries: 21 Classic themes, six Oh No! themes and two seasonal themes. It has no separate start cue or demo Can-Can. The notes report a nonfunctional Tandy demo overlay. Version 1.02 corrected tempo and the Tim 1 loop; do not apply AdLib file numbers to Tandy tracks.
- **Lemmings 2 DOS:** 19 entries include 12 tribe themes, main and ending themes, Let's Go, three medal cues and Tribe Complete. Dullstar logged the music with DOSBox-VGM; MrKsoft trimmed, looped and tagged it. These are OPL2 renditions, not MT-32 recordings.
- **Chronicles / All New World DOS:** nine tracks add Intro to Frontend and seven tribe themes. MrKsoft v1.10 restored loops to match the original HMI files. The notes explicitly preserve long gaps before some loops. Do not label these gaps a converter failure without comparing the source. Track names follow Amiga filenames.
- **Lemmings 3D DOS:** 38 entries include rating jingles, Failed, Success, opening and ending/menu music. Each zone has three variants; the notes describe the third as a substantial rearrangement. Valley Bell used DOSBox 0.74 and a Mirsoft MIDI ordering. The readme flags source percussion bugs, including Egypt 3. This soundtrack is separate from Chronicles.
- **Mega Drive Classic:** 25 entries include 21 stage themes, Sunsoft Special, an ending and two opening variants. The package credits Hirohiko Takayama and declares a complete dump. Its history says Stage Theme 2 came from an older set. These numbered themes must not be assumed to match the Amiga rotation.
- **Mega Drive Lemmings 2:** 16 entries, credited to Matt Furniss. Beach doubles as the ending theme; Stage Clear and Unknown Track are separate entries. The readme declares a complete dump, but does not resolve the unknown track's role.
- **Arcade:** 18 YM2151 logs include four Clear cues. Paul999's notes describe slower, apparently unfinished arrangements and changing pitch in the long Mountain track. Version 1.01 removed unused OKIM6295 data. Treat this as a distinct rendition, not a fidelity replacement for Amiga or DOS.
- **Lynx:** 19 Mikey tracks, including Intro and Menace; logged using MAME 0.272 VGM mod. The file set does not contain all four named Amiga special themes.
- **FM Towns:** 22 RF5C68 tracks, including Intro and four special themes. The notes credit Takashi Ohtani for music programming and report MAME 0.244 logging.
- **PC-98:** 21 YM2203 tracks, logged with Neko Project 21/w VGM mod. The credits include Hideya Nagata. The named set lacks Doggie; that is a difference in this downloaded set, not proof of a missing rip.
- **X68000:** 22 YM2151/OKIM6258 tracks, including Intro and four specials. The credits include Akira Suzuki. Logged using XM6 2.05 VGM mod; v1.01 changed screenshot aspect ratio.
- **NES:** ten N2A03 tracks include Title Screen and an alternate Can-Can. The notes credit Jonathan Dunn for the port. Keep the alternate version distinct.
- **Game Boy Classic:** nine DMG tracks. The notes say none of Brian Johnston's pieces appear and reference a YouTube playlist for ordering. The package credits Tim Wright, Keith Tinman and traditional composers; ordering is not verified gameplay sequencing.
- **Game Boy Lemmings 2:** 15 DMG tracks, credited to Mark Cooksey. Includes story/ending, menu/credits, Level Pane, ten named tribes and two unknown tracks. The author could not identify the last two. Do not assign them to Egyptian or Polar by elimination.
- **Spectrum 128:** one AY-3-8912A track, Tim 1. A one-track package does not establish missing tracks without a platform reference.

## Remixes and existing material

The remix folder now contains 17 Original and six Oh No! MandelSoft OGG tracks, their 23 converted M4A files, a CoLD SToRAGE March of the Greentops M4A, and an Amigamer Medieval Lemmings MP3. These are installed source assets, superseding the earlier candidate-only notes. A lossless output container does not restore information lost in OGG/MP3 sources. Filename identity and catalogue grouping are not an independent authorship or permission audit.

The earlier 73 Amiga modules and 12 CoLD SToRAGE WAV recordings remain. Demo/prototype modules stay distinct from released-game music. The composer album remains a selection, not the complete Amiga score.

## Remaining gaps and validation boundaries

- Native Macintosh, Atari ST, C64, Game Gear, PC Engine, Windows MIDI/CD, PlayStation, 3DO and CD-i collections are not present as identified source folders. MT-32 music is also absent. These are collection gaps, not counts of missing unique compositions.
- [VengefulChip recovery](VengefulChipRecovery.md) recovered external download links only. No audio from those links has been added or confirmed available.
- Native Mac Holiday Frosty the Snowman and Archimedes Oh No!/Lemmings 2 collections remain unverified/unavailable here. Archimedes Classic Professor Mariarti is now present as an MP3. DOS seasonal music and Oh No! arrangements are now present, so the old DOS absence claims no longer apply.
- Explicit result cues now exist in the source library. Their presence does not prove that the game routes the correct cue for every engine and state. The old “no failure track” statement applies only to the earlier library.
- Conversion verifies file integrity and decoder compatibility, not original-hardware fidelity, seamless loops, volume matching, beat grids or exact level assignments. The source readmes generally call their ordering approximate.
- Imported assets and a generated catalogue do not establish what shipped in Build 44 or 45. Check a built app's resources before claiming release inclusion. Standalone sequel packaging has separate rules.

## Further additions — 25 September 2026

| Folder | Added files | Evidence and status |
| --- | ---: | --- |
| Archimedes | 21 MP3 | Filename-labelled Archimedes recordings, including Professor Mariarti and four special themes. No package readme is included. This fills the Classic collection gap, not the separate Oh No!/Tribes gaps. |
| Lemmings (MP3) | 29 MP3 | Title Screen tags credit Tomomi Hatakeyama and dumper Dragon Fogel, consistent with the SNES set found earlier. Includes Stage Intro, Stage Clear, Failure, Intermission, Ending, Staff Roll and Trapdoor. The folder name alone does not identify platform or region; no native SPC files or package readme are present. |
| Lemmings-SMS | 22 compressed VGM | Embedded GD3 tags identify Sega Master System and Maxim. Includes Success, Failure, Let's Go! and Oh No!, plus 18 music tracks. All 22 now have verified Apple Lossless M4A counterparts. |

All 50 new MP3 files passed metadata/duration probing. All 22 SMS files passed gzip decompression and VGM/GD3 signature checks. This is not a full decode or listening test.

The SMS files have `.vgm` extensions but gzip payloads. Its readme header says v1.03 while the history includes v2.00 (6 October 2024), described as a 50 Hz rerip with revised credits. Preserve that discrepancy; the header alone cannot establish the downloaded version. The readme declares a complete dump, no FM soundtrack, and no extra prototype music. Embedded notes include level associations, but runtime mapping still needs verification.

The updated conversion report contains 349 verified outputs. All 72 additions are now playable assets and catalogue entries. MP3 recordings do not establish lossless provenance. None of these source checks establishes inclusion in a released build.
