# Lemmings Local

Lemmings Local is an unofficial native macOS port of Lemmings. Commercial game
data is not committed to the source repository. Local builds embed the game
assets already provided under `Sources/Ports` and `Sources/Music`.

The project is not affiliated with, endorsed by, or licensed by Sony
Interactive Entertainment, which holds the Lemmings rights today. Psygnosis no
longer exists. Sony bought it in 1993, renamed it Studio Liverpool in 1999, and
closed it in 2012. Read `THIRD_PARTY_NOTICES.md` before you distribute anything.

## Current result

The app is a native macOS build. It runs no emulator and interprets no DOS
code. It loads embedded original game data, puts recognised releases in
canon order, and lets the player start at any installed release or level.
Completing one installed release continues into the next. The original DOS
Lemmings campaign is complete: all 120 levels across Fun, Tricky, Taxing, and
Mayhem are present.

The app runs the DOS-accurate engine, `ClassicDOSSimulation`. The engine steps
in fixed 17 Hz logic ticks through an accumulator, so the logic rate does not
follow the display rate. The engine reads entrances, exits, and hazards from
each level's own trigger zones.

A smoke harness runs all 120 official levels. Every level builds a simulation,
releases lemmings, and moves them. Every level decodes an exit trigger.

The engine completes real levels. A search over single skill assignments finds
the known solution to three levels with three different skills. Fun 1 needs a
digger. Fun 2 needs a floater. Fun 9 needs a basher. Replays of those runs
reproduce exactly.

The app also opens unofficial NeoLemmix `.nxlv` levels. The player chooses a
NeoLemmix styles directory once. The app then resolves style assets, renders
the level, and plays it under the NeoLemmix ruleset. Missing style data is
reported rather than ignored.

| Area | Current support |
| --- | --- |
| Original DOS campaign data | All 120 campaign slots, 80 physical records, and 40 repeat overrides validated |
| DOS terrain graphics | All five ground sets and all four `VGASPEC` backgrounds decoded and golden-tested |
| DOS object graphics | Frames, palettes, upside-down objects, animation, `NoOverwrite`, and `OnlyOnTerrain` supported |
| Classic gameplay | The DOS engine drives the app at a fixed 17 Hz tick with the eight DOS skills |
| Campaign coverage | All 120 levels build, spawn, and run |
| Verified solutions | Three official levels solved and replayed. The rest need multi-skill replays |
| Replays | Deterministic format with an initial state hash and an outcome hash |
| Interface | Scrolling viewport, zoom, control panel, live skill counts, minimap, and cursor |
| Lemming sprites | Decoded from `MAIN.DAT` and drawn per pose and direction |
| NeoLemmix `.nxlv` data | Parsed, style-resolved, rendered, and played through the NeoLemmix engine |
| NeoLemmix verification | Verified against synthetic content only. No fan pack has been tested |
| NeoLemmix lemming sprites | Not loaded. NeoLemmix levels borrow the imported DOS sprites |
| FM synthesis | Native YM3812 implemented and tested. Frequency tracks the hardware formula |
| Original tunes | Not playable. The Sound Images sequencer format is undecoded |
| Music playback | Amiga ProTracker modules play. A folder of audio files the player supplies also plays |
| SNES and Genesis music | Not playable. `SNESAudioPlayer` and `GenesisFMPlayer` hold track lists and render silence |
| Macintosh MIDI | Not playable. No MIDI player exists, so the source is not offered |
| Sound effects | Macintosh `snd` resources, and the Amiga banks. `basicfx` and `fullfx` are IFF 8SVX, decoded and selectable |
| Amiga sound names | Eleven of twenty-one sounds carry a name and are bound. Nine have an empty name and stay unbound rather than guessed |
| Port-exclusive levels | "Oh Yes! More Lemmings!" gathers the 30 Amiga versus levels. Loaded and tested. Not yet in the game library |
| SNES and Genesis levels | Not extracted. `SNESLevelDecoder` returns a fixed list whatever ROM it is given, and `GenesisLevelDecoder` builds entries from a formula. Neither carries terrain |
| Adaptive DJ | Plays. Mixes between the soundtracks the player supplied, cued by what the game does. Offered only when a soundtrack is installed |
| Lemmings 3 movies | Decoded. All 3333 frames of the five `.FLI` files read, and match a decoder written separately. Not yet shown in the game |
| Graphics sources | DOS VGA, Amiga OCS, and Macintosh artwork all decode and can be chosen |
| DOS CGA | Not available. The DOS data holds CGA sets, and no decoder reads them. There are no EGA sets |
| Distribution | Beta 9 universal build for macOS 13+. The packaging script supports Developer ID signing and Apple notarization. See [beta testing](Documentation/BetaTesting.md) |

## Unified game library

All eight releases now appear in one game library and share one window.
Click a game to start, or use the arrow keys and Enter. Press Command-Shift-L
at any time to return to the library. Full Quest resumes unfinished campaigns
and continues between engines. Single-game mode returns to the library.

Oh No! now has its five retail ratings and authored level order. Both Xmas
demos and both retail Holiday campaigns are included, for 292 classic-family
levels. Holiday 1993/1994 use the supplied Macintosh level records and DOS
festive graphics. The build extracts the existing installer with `unar`.
The finished app needs no external assets or extraction tools.

L2 is a native beta with all 120 levels, all twelve tribes and four practice maps. Full campaign solution
verification is still in progress. L3 remains a native preview. See [integration details](Documentation/UnifiedGame.md).

## Build and run

Requires macOS 13 or later, the Apple Command Line Tools, and `unar` for the supplied Holiday installer.

```sh
zsh Scripts/build-local-app.sh
```

```sh
open ".build/local/Ultimate Lemmings.app"
```

The build embeds the available game assets and music in `Contents/Resources`.
Normal launches need no data-folder selection and do not depend on the source
checkout or working directory. Additional custom data can still be imported.
Macintosh resource forks are preserved as ordinary `.rsrc` files under
`Ports/MacResourceForks`, so code signing does not discard their graphics or levels.
Choose **Play Lemmings 2…** (Command-Shift-2) for its native player.
Both standalone sequel builds also embed their data. Copying the app does not
require copying separate data folders. These local bundles contain the supplied
commercial assets; they are not data-free source releases.

Click a skill button to arm a skill. Click a lemming to assign it. Press `N`
for the next level, `R` to retry, and `X` to nuke or undo the active nuke.
The nuke button requires a double-click. Once activated, a single click or
double-click restores the game to just before the nuke, including terrain and
timers. The same mouse controls apply in Lemmings 2. Bomb pops in the classic
playfield flash briefly, then disappear without shrinking or fading.
On EDR-capable displays, their cores briefly reach up to 4× SDR white, limited
by the screen's current headroom. This works in flat and CRT modes. Terrain
and UI stay at SDR brightness, and the boost expires even while paused.
SDR displays retain the ordinary flash.

Passing levels in campaign order unlocks persistent achievements for each
release. Completing the festive games, the original trilogy, and the full
canon unlocks additional achievements. Choose **Achievements** from the app
menu, or press Command-Shift-A, to see them.

The build script compiles the Swift targets directly. This also works around a
`PackageDescription` binary mismatch in some Command Line Tools installations.
On a healthy SwiftPM installation, `swift test` remains available.

## Verification

Run every suite:

```sh
for s in portable-tests classic-dos-simulation-regressions classic-dos-campaign-smoke classic-dos-replay-tests neolemmix-simulation-tests neolemmix-end-to-end nxlv-renderer-tests nxlv-style-resolver-tests opl2-tests; do zsh Scripts/run-$s.sh; done
```

Render a frame of the real views to a PNG, which needs no screen-capture
permission:

```sh
zsh Scripts/render-shot.sh --level 1 --ticks 260 --out shot.png
```

Measure how far the engine gets on every official level:

```sh
zsh Scripts/run-classic-dos-solvability-probe.sh
```

Inspect the imported audio driver, and hear the synthesizer:

```sh
zsh Scripts/probe-audio.sh
```

```sh
zsh Scripts/render-opl2-demo.sh opl2.wav
```

The suites verify:

- bounds-checked DAT decompression and malformed-input rejection;
- checksums and sizes for all 80 physical level records;
- the exact 120-level campaign order and all 40 `ODDTABLE` overrides;
- all ground sets, special backgrounds, objects, steel, entrances, and exits;
- full rendered-map, mask, terrain-piece, and object-frame SHA-256 goldens;
- DOS release intervals, hatch order, safe fall distance, destruction masks,
  blocker fields, trap cooldowns, and deterministic continuation;
- every official level builds a simulation, releases lemmings, and moves them;
- replay determinism, the initial state hash guard, and a JSON round trip;
- a NeoLemmix level from text through styles, rendering, and simulation to a
  win;
- extended NeoLemmix parsing, typed sections, diagnostics, and dependency
  scans;
- OPL2 frequency against the hardware formula, envelope stages, a nine-channel
  mix, and patch loading on every channel.

## Remaining work

1. Broaden sequel fidelity and complete-level validation. L2 is a native beta
   with all twelve tribes, 120 campaign levels, 51 skills, interactive objects,
   four practice maps, original audio, introduction and ending scripts.
   All campaign starts and exits pass checks; 64 levels have recorded solutions.
   Full walkthrough coverage and original-engine equivalence remain unverified.
   L3 remains a native preview with 90 campaign levels, separate tribe progress,
   and completed-run checks for Classic 1–3, Egyptian 1 and Shadow 1. Its audio,
   movies and remaining mechanics need further work.
   See [Sequel interpreters](Documentation/SequelInterpreters.md).
2. Record full solution replays for Oh No!, Xmas 1991–1992, and Holiday
   1993–1994. Their retail ratings and campaign order now load in the shared
   library. All 292 classic-family levels pass rendering and release checks.
3. Record replays for every official level, then gate physics changes on them.
   Three levels are covered. The other 117 need multi-skill replays.
4. Decode the Sound Images sequencer format so the driver's own tunes feed the
   synthesizer. See `Documentation/AdlibDriver.md`.
5. Load NeoLemmix lemming sprites from style packs.
6. Test against real NeoLemmix packs, including missing-dependency and
   malformed content.
7. Extend live checks to Tahoe and physical Intel Macs. The beta packaging
   script already creates hardened, Developer ID signed and notarized builds.

## Source layout

- `Sources/NxlvKit/ClassicDATArchive.swift`: classic DAT decompression.
- `Sources/NxlvKit/ClassicLevel.swift`: 2,048-byte DOS level records.
- `Sources/NxlvKit/ClassicCampaign.swift`: campaign and `ODDTABLE` handling.
- `Sources/NxlvKit/ClassicGraphics.swift`: ground, object, special-graphic, and
  level rendering.
- `Sources/NxlvKit/ClassicMainDAT.swift`: `MAIN.DAT` sprites, palettes, and
  destruction masks.
- `Sources/NxlvKit/ClassicDOSSimulation.swift`: the DOS-accurate engine.
- `Sources/NxlvKit/OPL2.swift`: the native YM3812 FM synthesizer.
- `Sources/NxlvKit/NxlvDocument.swift`: ordered NeoLemmix document parser.
- `Sources/NxlvKit/NxlvLevel.swift`: typed NeoLemmix level model.
- `Sources/LemmingsLocal/main.swift`: the native AppKit app and run loop.
- `Tests/PortableTests/main.swift`: portable integration and golden tests.
- `Tests/ClassicDOSCampaignSmoke/main.swift`: all-120-level engine harness.

See `THIRD_PARTY_NOTICES.md` for research sources and licensing notes.

### Macintosh artwork

The combined app now prefers the supplied Mac artwork for Lemmings, Oh No,
Xmas, and Holiday: 2× terrain and objects, Mac lemmings, logos, and menu fonts.
The simulation and saves remain compatible. See
[the asset sources and fallback details](Documentation/UnifiedGame.md#display-and-navigation).
Builds also require Python 3 and ImageMagick (`magick`); the packaged app does not.

Classic artwork can be changed in **Options → Graphics → Artwork**: Macintosh
(default), Amiga, or DOS (VGA). Selections persist between launches. The Mac and
Amiga skill buttons have shaded stone frames and a pressed selection state.

Lemmings 2 and 3 have a separate optional **Macintosh-style 2× artwork** setting
under **Options → Graphics → Lemmings 2 + 3**. L2 Preferences and the L3 artwork
button use the same saved choice. It reconstructs discrete pixels from measured
Macintosh reference rules and retains the original gameplay geometry. The
default is Macintosh-style artwork, including L2 menus and loading/briefing screens.
You can switch back to the original PC artwork. See [the reference study, conversion and
visual checks](Documentation/SequelMacArtwork.md).
