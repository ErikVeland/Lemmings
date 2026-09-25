# Soundtrack organisation and journey

All 495 playable versions are catalogued under 210 track identities. Browse `Sources/Music/By Track` or [the track catalogue](MusicTrackCatalogue.md).

The hierarchy is **game → role → track → port → source quality → original/remix**. The browsing folders contain relative symlinks to the original asset layout. They do not consume another copy of the audio or invalidate conversion hashes. The original compressed logs and OGG files are linked beside their playable counterparts. Players and converters skip this view to prevent duplicates.

`Resources/Music/catalogue.json` is the tracked catalogue. `Sources/Music/catalogue.json` is its local runtime copy. Each version records its source path, port, source quality, arrangement, identity evidence and available credits. The game never equates tunes by file number or substring alone when a catalogue entry exists.

## Default DJ journey

- The first occurrence of each tune uses its Amiga module, when installed. DJ modules use faithful playback. The existing shared mix and crossfade processing still applies; this is not a claim of bit-perfect hardware output.
- Later occurrences introduce another original port, a composer recording and a remix when available, then visit the remaining versions. This lets remixes appear within a campaign instead of waiting behind every hardware port. Each chapter uses the fixed port and source-fidelity order; unavailable chapters are skipped.
- Classic counts previous occurrences of the assigned tune in the campaign score, including special-level overrides. A first special level therefore uses its original even when it occurs late in the campaign.
- Lemmings 2 advances the tribe's version with its level index. Lemmings 3 advances each tribe tune after its local tune rotation repeats. These are score cycles within a campaign, not a counter of completed playthroughs.
- Selection depends on the campaign position and installed catalogue. Retries, direct level selection, saved-level reopening and Hot Seat handovers choose the same version. Attempts and wall-clock time do not advance the journey. Adding or removing versions can change future selections.
- Turning off other soundtracks retains the first version of the assigned tune in all three engines. Missing variants fall back within the same identity; missing catalogue data uses the assigned module.
- Active gameplay, a rescue quota, danger and nuking do not replace a tune. Paused handovers keep the pending selection silent until playback resumes.

The existing Amiga composition rotation remains the Classic score policy. Artwork selection does not imply a new platform's historical tune order. Exact native port sequencing remains a separate audit.

## Preserve special music

Special-level themes retain separate identities. Beast I cannot become Beast II, and neither enters the ordinary rotation. Seasonal and prototype/demo material remain separate from released ordinary music. Menus, start cues, medals, milestones, endings, bonus remixes and unknown tracks have their own roles.

A completed result can use only an explicitly classified generic win/loss cue from the current game and port. No such cue means the current track continues. Generic wins never select a medal, an ending or a finale from another game. Medals and campaign-ending music require their own explicit event routing; this change does not add those events.

## Source fidelity and uncertain identities

Quality describes provenance: native module, chip render, composer recording or lossy source. Converting OGG/MP3 to a lossless container does not improve its source fidelity. These labels are not a subjective ranking of musical quality.

GD3 tags and the included package notes establish most named port matches. The composer album uses the established Tim aliases. MandelSoft explicitly documents DOS ordering and identifies several numbered tracks in [the release discussion](https://www.lemmingsforums.net/index.php?topic=3921.0). Its `orig_12` is Doggie; treating its filenames like the VGM package numbering would swap tunes. Oh No's Amiga/DOS numbering differs for tracks 4–6; [the numbering discussion](https://www.lemmingsforums.net/index.php?topic=4534.0) records the correspondence.

Nine identities remain excluded from automatic journeys: six numbered Oh No MandelSoft remixes, two unknown Game Boy Lemmings 2 tracks and one unknown Mega Drive Lemmings 2 track. The remix numbers need listening verification before linking them to the Amiga composition IDs. They remain browsable and playable assets. March of the Greentops stays a standalone bonus remix until its constituent themes are verified.

Mega Drive's numbered Classic stage themes retain their own identities. Lemmings 2 Game Boy and Mega Drive tribe pieces also retain port-specific identities: matching tribe labels and differing composer credits are insufficient evidence that they are the same composition. They are organised and packaged but are not silently substituted for the Amiga tribe tune.

## Regenerate and validate

```sh
python3 Tools/MusicCatalogue/build.py --links
zsh Scripts/run-music-catalogue-tests.sh
zsh Scripts/run-adaptive-dj-director-tests.sh
zsh Scripts/run-adaptive-dj-playback-tests.sh Sources/Music
```

The generator checks conflicting roles and rebuilds only links to known assets. The tests check complete asset coverage, link targets, numbering exceptions, source fidelity, deterministic selection, unavailable files, protected cues, sequel journeys and suspended playback.

Full-game packaging copies the catalogue after WAV-to-M4A encoding and rewrites those catalogue paths. Standalone Lemmings 2 and Lemmings 3 builds now copy their own catalogue entries and all available versions for that game. Browsing links and archive originals are not needed inside the app bundle.

Validation on 25 September 2026: catalogue and packaging checks passed for all 414 versions. Director checks and real audio playback checks passed, including both sequel journeys, retries and paused crossfades. The full desktop app passed Swift type-checking; existing unrelated deprecation/unused-result warnings remain. No release app was rebuilt or installed.

Converted VGZ recordings still contain two loops and a fade. The recording deck repeats the whole file, including the intro and fade. Seamless native loop points, loudness matching and listening checks against original hardware remain unverified. No new visual controls were added.

The four MandelSoft special remixes participate only in their matching special-theme journeys. Five numbered Paintball remixes are catalogued and packaged as separate bonus material, with no inferred Classic level or result assignment.
