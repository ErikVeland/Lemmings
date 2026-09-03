# Lemmings Local

Lemmings Local is an unofficial native macOS port of Lemmings. It contains no
commercial game data. Players import data that they lawfully possess.

The project is not affiliated with, endorsed by, or licensed by Sony
Interactive Entertainment, which holds the Lemmings rights today. Psygnosis no
longer exists. Sony bought it in 1993, renamed it Studio Liverpool in 1999, and
closed it in 2012. Read `THIRD_PARTY_NOTICES.md` before you distribute anything.

## Current result

The app is a native macOS build. It runs no emulator and interprets no DOS
code. It imports an original DOS Lemmings data directory, then lists and plays
the complete 120-level campaign across Fun, Tricky, Taxing, and Mayhem.

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
| Sound and music | Not implemented |
| Distribution | Local ad-hoc signed universal build for macOS 13+. Developer ID signing and notarization are not configured |

## Build and run

Requires macOS 13 or later and the Apple Command Line Tools.

```sh
zsh Scripts/build-local-app.sh
```

```sh
open ".build/local/Lemmings Local.app"
```

In the app, select **Import original DOS data**. Choose the directory that
contains files such as `LEVEL000.DAT`, `GROUND0O.DAT`, `VGAGR0.DAT`,
`ODDTABLE.DAT`, and `MAIN.DAT`. The app remembers the directory for later
launches.

Click a skill button to arm a skill. Click a lemming to assign it. Press `N`
for the next level, `R` to retry, and `X` to nuke.

The build script compiles the Swift targets directly. This also works around a
`PackageDescription` binary mismatch in some Command Line Tools installations.
On a healthy SwiftPM installation, `swift test` remains available.

## Verification

Run every suite:

```sh
for s in portable-tests classic-dos-simulation-regressions classic-dos-campaign-smoke classic-dos-replay-tests neolemmix-simulation-tests neolemmix-end-to-end nxlv-renderer-tests nxlv-style-resolver-tests; do zsh Scripts/run-$s.sh; done
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
  scans.

## Remaining work

1. Record replays for every official level, then gate physics changes on them.
   Three levels are covered. The other 117 need multi-skill replays.
2. Decode and play the audio that the player imports. Do not bundle commercial
   assets.
3. Load NeoLemmix lemming sprites from style packs.
4. Test against real NeoLemmix packs, including missing-dependency and
   malformed content.
5. Produce hardened, Developer ID signed, and notarized macOS builds. This
   needs an Apple Developer account.

## Source layout

- `Sources/NxlvKit/ClassicDATArchive.swift`: classic DAT decompression.
- `Sources/NxlvKit/ClassicLevel.swift`: 2,048-byte DOS level records.
- `Sources/NxlvKit/ClassicCampaign.swift`: campaign and `ODDTABLE` handling.
- `Sources/NxlvKit/ClassicGraphics.swift`: ground, object, special-graphic, and
  level rendering.
- `Sources/NxlvKit/ClassicMainDAT.swift`: `MAIN.DAT` sprites, palettes, and
  destruction masks.
- `Sources/NxlvKit/ClassicDOSSimulation.swift`: the DOS-accurate engine.
- `Sources/NxlvKit/NxlvDocument.swift`: ordered NeoLemmix document parser.
- `Sources/NxlvKit/NxlvLevel.swift`: typed NeoLemmix level model.
- `Sources/LemmingsLocal/main.swift`: the native AppKit app and run loop.
- `Tests/PortableTests/main.swift`: portable integration and golden tests.
- `Tests/ClassicDOSCampaignSmoke/main.swift`: all-120-level engine harness.

See `THIRD_PARTY_NOTICES.md` for research sources and licensing notes.
