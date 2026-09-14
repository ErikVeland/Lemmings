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

All 120 Classic levels have saved winning replays on the native engine.
`zsh Scripts/verify-classic-completion.sh` checks every recorded assignment and
reproduces every win from a fresh simulation. Missing or invalid replays fail
the check. See [the completion evidence](Documentation/ClassicCompletion/README.md).
A winning rescue count is not an optimality proof; maximum-rescue targets remain
separate from the original pass requirements.

Lemmings 2 has a matching gate. `zsh Scripts/verify-lemmings2-completion.sh`
replays each recorded route twice and checks a committed manifest. It verifies
64 of 120 levels. No tribe chains all ten levels under population carry-over.
See [the Lemmings 2 evidence](Documentation/Lemmings2Completion/README.md).

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
| Campaign coverage | All 120 levels have repeatable winning native-engine replays |
| Completion evidence | All 120 original levels have verified winning replays. Additional Classic campaigns have 118 winning routes. Full coverage remains open |
| Replays | End-of-run playback from 0.25× to 8× and MP4 movie export; separate deterministic DOS replay tools |
| Arcade records | Local player profiles, sprite portraits, per-level rescue and skill boards, achievements and retry challenges |
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
| Port-exclusive levels | "Oh Yes! More Lemmings!" is in the library with 60 bundled converted levels. All render and release lemmings; full winning-route coverage remains open |
| SNES and Genesis levels | Not extracted. `SNESLevelDecoder` returns a fixed list whatever ROM it is given, and `GenesisLevelDecoder` builds entries from a formula. Neither carries terrain |
| Adaptive DJ | Plays. Mixes between the soundtracks the player supplied, cued by what the game does. Offered only when a soundtrack is installed |
| Lemmings 3 movies | All five original `.FLI` movies are available from the in-game movie gallery. Streaming playback supports pause and return; story triggers and movie soundtracks remain unconnected |
| Graphics sources | DOS VGA, Amiga OCS, and Macintosh artwork all decode and can be chosen |
| DOS CGA | Not available. The DOS data holds CGA sets, and no decoder reads them. There are no EGA sets |
| Distribution | Beta 32 (0.1, build 32): standard and Game Center for macOS 13+, plus a Monterey compatibility build for macOS 12.3+. See [release notes](Documentation/ReleaseNotes-beta32.md) and [archive verification](Documentation/Beta32Readiness.md). Full Classic and fan-pack coverage, hardware checks and accessibility remain open before 1.0. See [release scope](Documentation/ReleaseScope.md). |

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

Requires macOS 12.3 or later, the Apple Command Line Tools, and `unar` for the supplied Holiday installer.

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

## Release readiness

The [1.0 gap review](Documentation/ReleaseReadiness-1.0.md) records this hardening pass, test evidence and the remaining release blockers.

The [modern release plan](Documentation/ModernReleasePlan.md) records verified features, open gaps and the path from the Mac reference build to iOS and consoles. The [partner evaluation brief](Documentation/PartnerEvaluation.md) describes the proposed demonstration and collaboration scope.

Run `python3 Tools/ReleaseReadiness/audit.py --app` for fresh regression logs, input hashes and campaign checks. A green regression run does not close hardware, complete-campaign or platform delivery gates.

Arcade records now retain a validated backup and recover it when the primary file is unreadable. Failed profile saves remain open for retry. Legacy campaign saves and preferences migrate into the current app without replacing current choices. See [save recovery and migration](Documentation/SaveRecovery.md).

**Settings → Accessibility** provides independent **Reduce added motion** and **Reduce added flashes** controls. Motion reduction disables speed trails and cinematic explosions. Flash reduction disables added bright explosion cores, HDR flashes and cinematic explosions. Original game sprites remain. These settings preserve gameplay speed and controller support, survive relaunch, and remain set when changing presets.

**Settings → Gameplay → Pause** enables automatic pause on focus loss or an active controller disconnect. Return to the game and resume explicitly. Hints, help and replay windows preserve an interruption pause when closed. The modern preset enables this option; the OG preset turns it off.

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

Classic 1.0 is the active release target. See [the closure work](Documentation/ClassicOneZero.md).
Sequel completion remains outside this milestone; shared regression checks still apply.

1. Broaden sequel fidelity and complete-level validation. L2 is a native beta
   with all twelve tribes, 120 campaign levels, 51 skills, interactive objects,
   four practice maps, original audio, introduction and ending scripts.
   All campaign starts and exits pass checks; 64 levels have recorded solutions.
   Full walkthrough coverage and original-engine equivalence remain unverified.
   L3 remains a native preview with 90 campaign levels, separate tribe progress,
   and 17 fixed-input winning replays. Its tribe module music, six named original
   voice samples and five original movies are connected. Environmental effects,
   movie soundtracks, story triggers and remaining mechanics need further work.
   See [Sequel interpreters](Documentation/SequelInterpreters.md).
2. Complete solution coverage for Oh No!, Xmas and Holiday. The
   [campaign gate](Documentation/CampaignCompletion/README.md) verifies 118 winning
   replays: Oh No! 72/100, Xmas 1991 4/4, Xmas 1992 4/4, Holiday 1993 22/32 and
   Holiday 1994 16/32. All 292 classic-family levels pass rendering and release checks.
3. Keep the strict original DOS completion gate green. All 120 levels have
   winning replays, including 103 full rescues. Extend this gate to the other
   campaigns. See [completion evidence](Documentation/ClassicCompletion/README.md).
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

### Modern defaults and OG settings

New players start with HD effects, variable speed and modern keyboard controls.
The first launch offers **Play with modern defaults** and **Old school**.
**Settings → Gameplay → Use OG settings** switches the added conveniences off
in one action. The selected machine, volumes and saves stay as set.

Tap **F** or click **Speed** for 2× → 3× → 5× → 10× → 1×. Hold **F** or **Shift**
to ramp up, then release to ease back to the selected speed. Double-tap **F**,
double-click **Speed**, or press **Escape** to return to 1× immediately.

Variable speed can be disabled independently in **Settings → Gameplay**.
HD effects have their own switch in **Settings → Video → Effects**.
See [speed controls and effects](Documentation/SuperSpeed.md).

### Optional level hints

Choose **Help → Level hints**, press **F1**, or choose hints from the controls help.
Reveal a gentle nudge, then the approach, then opening moves with marked locations.
The game pauses while you read. Each tier needs a separate click.
All 120 original levels have hints drawn from checked winning routes.
Other levels offer clearly labelled general coaching. See [level hints](Documentation/LevelHints.md).

### Pointer capture

During play, the pointer stays inside the game so edge scrolling continues beside
another monitor. Hold **Option**, pause, or open a menu to release it. The setting
is under **Settings → Video → Pointer**. See [pointer capture](Documentation/PointerCapture.md).

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

### THE TROLLEY

Completed attempts now have a persistent philosophical rescue analysis, including
failed attempts. The existing game result page shows saved versus best known or
verified maximum, an affinity for the solution, and an adaptive Retry challenge.
See [THE TROLLEY](Documentation/TheTrolley.md) for evidence rules, seven local
boards, profile history, migration, and validation. Run
`Scripts/run-trolley-tests.sh` for its model, persistence, replay, and UI tests.

Speed controls: **F**, the **Speed** button and controller **RT** toggle fast-forward. Hold **Shift**, **Speed** or **RT** for a temporary boost. Use the speed arrows, **Shift+[ / Shift+]**, or **LT + D-pad left/right** to choose a fast tier. **Escape** or controller **B** immediately returns to 1×. See [speed controls](Documentation/SuperSpeed.md).

### Skill keyboard shortcuts

During play, number keys select skills in panel order (1–9, then 0 for the tenth slot). Letter keys also select skills. Initials take priority; skills with a duplicate or reserved initial use the next available letter in their name. The bindings follow the current level’s skill list. Hover over the skill panel to see its shortcuts.

For the classic eight skills: **1/C** Climber, **2/L** Floater, **3/B** Bomber, **4/O** Blocker, **5/U** Builder, **6/A** Basher, **7/M** Miner, **8/D** Digger. F remains fast-forward.

Lemmings 3 uses **1/W** Walker, **2/B** Blocker, **3/J** Jumper, **4/U** Use tool, and **5/D** Drop tool.

During play, **Tab / Shift-Tab** cycles through available skills and skips empty supplies. **Hold Shift** for temporary fast-forward; release it to restore the previous speed. **Home / End** centres the camera on the first entrance / exit. **− / +** changes the release rate in classic and NeoLemmix levels. The sequels use fixed release timing.

**Escape** cancels a pending Lemmings 3 direction choice or Lemmings 2 fan selection, then opens the pause menu on the next press. In classic play, it opens a pause menu with Resume and Retry. **?** pauses play and shows the current level’s shortcuts; closing help restores the previous pause state.

**] / [** snaps to the next / previous active lemming that has never received a successful skill assignment, in release order. **\** snaps to the last successfully assigned lemming. A yellow ring marks the camera target for two seconds. **Return / Enter** applies the last successfully assigned skill to that highlighted target, or to the lemming under the pointer when no highlight is active. Moving the pointer clears the highlight. These keys never assign on key repeat, and normal skill eligibility and supply limits still apply. Lemmings 3 tools still ask for a direction when needed.

### Controller controls

Connected extended gamepads (including supported Xbox and PlayStation controllers) use the same gameplay actions as the keyboard. Button names below follow the Xbox layout; PlayStation uses the corresponding button positions.

| Controller | Action |
| --- | --- |
| Left stick / right stick | Aim / pan camera |
| A / B | Assign selected skill / return to 1×, then cancel or open pause menu |
| X / Y | Repeat last successful skill / focus last assignment |
| LB / RB | Previous / next available skill |
| D-pad left / right | Previous / next unassigned lemming |
| D-pad up / down | Increase / decrease release rate where supported |
| Tap RT | Toggle fast-forward; optional in Controller settings |
| Hold RT | Ramp up; release immediately restores the previous speed |
| Menu | Pause / resume |
| Left / right stick click | Centre on entrance / exit |
| View / Options | Show keyboard and controller help |
| LT + Y | Open tiered level hints |
| LT + D-pad left / right | Decrease / increase selected speed |
| LT + D-pad up / down | Centre on entrance / exit |
| LT + X | Reset speed to 1× |
| LT + LB / RB | Step back / forward where supported |
| LT + B | Rewind two seconds where supported |
| LT + Menu | Retry the level |
| LT + A | Confirm ending the run, or undo a nuke where supported |
| LT + View / Options | Open Settings |

**Settings → Controller** has gamepad support, tap-to-change-speed and stick-swap switches, plus the full binding list.
The modern preset enables controller QoL. **Use OG settings** disables gamepad support along with the other added conveniences.

In game menus, the D-pad navigates, A confirms, and B returns. The same controls work on hint pages and help sheets.
In Settings, use LB / RB to change tabs, D-pad up / down to choose a control, left / right to adjust values, and A to toggle or activate.
The right stick scrolls long help pages. Hint tiers require separate presses. Held buttons do not carry into a new page.

In Lemmings 3, aim at a direction-picker cell and press A to confirm a tool direction. Skill selection cycles through the current level’s available skills, so every skill remains reachable without a dedicated button. Assignments fire once per press. Reconnecting a controller or returning to the game does not replay held buttons. Disconnecting or leaving the game window cancels speed input.
