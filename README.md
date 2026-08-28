# Lemmings Local

Lemmings Local is an unofficial native macOS port of Lemmings. It contains no
commercial game data. Players import data that they lawfully possess.

The project is not affiliated with, endorsed by, or licensed by Sony
Interactive Entertainment, which holds the Lemmings rights today. Psygnosis no
longer exists. Sony bought it in 1993, renamed it Studio Liverpool in 1999, and
closed it in 2012. Read `THIRD_PARTY_NOTICES.md` before you distribute anything.

## Current result

The app imports an original DOS Lemmings data directory. It validates and lists
the complete 120-level campaign across Fun, Tricky, Taxing, and Mayhem. It
decodes and renders every physical level record. This covers repeat level
parameters from `ODDTABLE.DAT`, all five ground styles, all four special
graphics, steel, animated objects, draw flags, entrances, and trigger zones.

The app runs the DOS-accurate engine, `ClassicDOSSimulation`. The engine steps
in fixed 17 Hz logic ticks through an accumulator, so the logic rate does not
follow the display rate. The engine reads entrances, exits, and hazards from
each level's own trigger zones.

A smoke harness runs all 120 official levels. Every level builds a simulation,
releases lemmings, and moves them. Every level decodes an exit trigger. The
engine still lacks replay validation, so the port does not yet guarantee that
every intended solution works.

The NeoLemmix loader targets NeoLemmix 12.14 and Community Edition 1.1.2. It
parses the level structure and dependencies. The app does not yet load
NeoLemmix style packs or run NeoLemmix physics. Fan `.nxlv` levels are
therefore not playable yet.

| Area | Current support |
| --- | --- |
| Original DOS campaign data | All 120 campaign slots, 80 physical records, and 40 repeat overrides validated |
| DOS terrain graphics | All five ground sets and all four `VGASPEC` backgrounds decoded and golden-tested |
| DOS object graphics | Frames, palettes, upside-down objects, animation, `NoOverwrite`, and `OnlyOnTerrain` supported |
| Official level selection | All 120 levels appear after the player imports original data |
| Classic gameplay | The DOS engine drives the app at a fixed 17 Hz tick with the eight DOS skills |
| Campaign coverage | All 120 levels build, spawn, and run for 30 seconds without failure |
| Exact DOS physics | Rules pass unit regressions. Replay validation is absent |
| Lemming sprites | Decoded from `MAIN.DAT` and drawn per pose and direction |
| NeoLemmix `.nxlv` data | Typed parser covers terrain, groups, gadgets, lemmings, talismans, text, transforms, skills, and dependencies |
| NeoLemmix styles and physics | Not implemented |
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

Run the portable suite:

```sh
zsh Scripts/run-portable-tests.sh
```

Run the DOS rule regressions:

```sh
zsh Scripts/run-classic-dos-simulation-regressions.sh
```

Run the engine against every official level:

```sh
zsh Scripts/run-classic-dos-campaign-smoke.sh
```

The suites verify:

- bounds-checked DAT decompression and malformed-input rejection;
- checksums and sizes for all 80 physical level records;
- the exact 120-level campaign order and all 40 `ODDTABLE` overrides;
- all ground sets, special backgrounds, objects, steel, entrances, and exits;
- full rendered-map, mask, terrain-piece, and object-frame SHA-256 goldens from
  independent decoders;
- DOS release intervals, hatch order, safe fall distance, destruction masks,
  blocker fields, trap cooldowns, and deterministic continuation;
- every official level builds a simulation, releases lemmings, and moves them;
- extended NeoLemmix parsing, full-width IDs, hexadecimal values, infinite
  quantities, typed sections, diagnostics, and dependency scans.

Use the data inspection tool for a detailed campaign listing:

```sh
zsh Scripts/verify-classic-data.sh
```

## Remaining work

The port is complete only when both rulesets pass deterministic replay tests.
The remaining work is:

1. Build a replay format that records skill assignments per tick. Add state
   hashes so each level's known-good solution becomes a regression test.
2. Validate every official level against those replays.
3. Decode and play the audio that the player imports. Do not bundle commercial
   assets.
4. Add the classic control panel, cursor, minimap, and scrolling viewport.
5. Load NeoLemmix style metadata and graphics. Implement the NeoLemmix 12.14
   ruleset and replay format.
6. Validate a broad fan-level corpus, including missing-dependency and
   malformed content cases.
7. Produce hardened, Developer ID signed, and notarized macOS builds.

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
