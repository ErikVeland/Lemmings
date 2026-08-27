# Lemmings Local

Lemmings Local is an unofficial macOS compatibility project for the original
DOS Lemmings data and NeoLemmix text levels. It does not include commercial
game data. Players import data that they lawfully possess.

## Current result

The macOS app now imports an original DOS Lemmings data directory. It validates
and lists the complete 120-level campaign across Fun, Tricky, Taxing, and
Mayhem. It decodes and renders every physical level record, including repeat
level parameters from `ODDTABLE.DAT`, all five ground styles, all four special
graphics, steel, animated objects, draw flags, entrances, and trigger zones.

The app can launch all 120 official levels. Gameplay is still a compatibility
prototype. Its movement, skills, traps, hazards, lemming graphics, sound, and
music do not yet match DOS closely enough to guarantee that every intended
solution works.

The NeoLemmix loader targets NeoLemmix 12.14 and Community Edition 1.1.2. It
parses the level structure and dependencies, but the app does not yet load
NeoLemmix style packs or run NeoLemmix physics. Fan `.nxlv` levels are therefore
not playable yet.

| Area | Current support |
| --- | --- |
| Original DOS campaign data | All 120 campaign slots, 80 physical records, and 40 repeat overrides validated |
| DOS terrain graphics | All five ground sets and all four `VGASPEC` backgrounds decoded and golden-tested |
| DOS object graphics | Frames, palettes, upside-down objects, animation, `NoOverwrite`, and `OnlyOnTerrain` supported |
| Official level selection | All 120 levels appear after the player imports original data |
| Classic gameplay | Playable prototype with eight skills, steel-aware destruction, scrolling, pause, speed, retry, and next-level flow |
| Exact DOS physics | Not implemented or replay-validated |
| NeoLemmix `.nxlv` data | Typed parser covers terrain, groups, gadgets, lemmings, talismans, text, transforms, skills, and dependencies |
| NeoLemmix styles and physics | Not implemented |
| Original sprites, sound, and music | Not implemented |
| Distribution | Local ad-hoc signed universal build for macOS 13+. Developer ID signing and notarization are not configured |

## Build and run

Requires macOS 13 or later and the Apple Command Line Tools.

```sh
zsh Scripts/run-portable-tests.sh
zsh Scripts/run-js-tests.sh
zsh Scripts/build-local-app.sh
open ".build/local/Lemmings Local.app"
```

In the app, select **Import original DOS data**. Choose the directory that
contains files such as `LEVEL000.DAT`, `GROUND0O.DAT`, `VGAGR0.DAT`, and
`ODDTABLE.DAT`. The app stores a security-scoped bookmark for later launches.

The build script compiles the Swift targets directly. This also works around a
`PackageDescription` binary mismatch in some Command Line Tools installations.
On a healthy SwiftPM installation, `swift test` remains available.

## Verification

Run the portable suite:

```sh
zsh Scripts/run-portable-tests.sh
zsh Scripts/run-js-tests.sh
```

It verifies:

- bounds-checked DAT decompression and malformed-input rejection;
- checksums and sizes for all 80 physical level records;
- the exact 120-level campaign order and all 40 `ODDTABLE` overrides;
- all ground sets, special backgrounds, objects, steel, entrances, and exits;
- full rendered-map, mask, terrain-piece, and object-frame SHA-256 goldens from
  independent decoders;
- extended NeoLemmix parsing, full-width IDs, hexadecimal values, infinite
  quantities, typed sections, diagnostics, and dependency scans.
- deterministic browser-loop rules, classic viewport and release calculations,
  hatch order, object ordering and animation timing, half-open triggers, camera
  bounds, and lemming selection.

Use the data inspection tool for a detailed campaign listing:

```sh
zsh Scripts/verify-classic-data.sh
```

## 10/10 acceptance target

The project is complete only when both rulesets pass deterministic replay
tests. The remaining work is:

1. Replace the prototype physics with a deterministic simulation
   that matches original DOS frame behavior for all eight skills, hazards,
   triggers, steel, blockers, release timing, and edge cases.
2. Decode the player graphics and audio that the player imports from original
   data. Do not bundle commercial assets.
3. Validate every official level with known-good replay traces and regression
   hashes.
4. Load NeoLemmix style metadata and graphics, then implement the NeoLemmix
   12.14 ruleset and replay format.
5. Validate a broad fan-level corpus, including missing-dependency and malformed
   content cases.
6. Produce hardened, Developer ID signed, and notarized macOS builds.

## Source layout

- `Sources/NxlvKit/ClassicDATArchive.swift`: classic DAT decompression.
- `Sources/NxlvKit/ClassicLevel.swift`: 2,048-byte DOS level records.
- `Sources/NxlvKit/ClassicCampaign.swift`: campaign and `ODDTABLE` handling.
- `Sources/NxlvKit/ClassicGraphics.swift`: ground, object, special-graphic, and
  level rendering.
- `Sources/NxlvKit/NxlvDocument.swift`: ordered NeoLemmix document parser.
- `Sources/NxlvKit/NxlvLevel.swift`: typed NeoLemmix level model.
- `Sources/LemmingsLocal/main.swift`: native AppKit level browser and renderer.
- `Tests/PortableTests/main.swift`: portable integration and golden tests.

See `THIRD_PARTY_NOTICES.md` for research sources and licensing notes.
