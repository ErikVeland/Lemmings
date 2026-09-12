# Classic scope closure before L2/L3 focus

12 September 2026. This scope follows the user's direction: validate everything
before Lemmings 2, including fan levels, before treating Classic as complete.
This supersedes the proposal to freeze Classic on the original 120 levels alone.
L2 and L3 remain the next main development phase. They are outside this gate.

## Required scope

| Collection | Current evidence | Required closure |
| --- | --- | --- |
| Original Lemmings | 120/120 preserved winning routes | Keep every route passing, retain original constraints, and investigate reported physics differences. |
| Oh No! More Lemmings | 66/100 preserved winning routes | Preserve and reproduce wins for the remaining 34 levels. |
| Xmas 1991 and 1992 | 4/4 and 3/4 | Preserve and reproduce the remaining Xmas 1992 win. |
| Holiday 1993 and 1994 | 14/32 and 16/32 | Preserve and reproduce the remaining 18 and 16 wins. |
| Oh Yes! and other advertised conversions/port-exclusive levels | Completion coverage remains incomplete | Inventory every shipped level and source ruleset. Validate conversions, assets, constraints, mechanics and winning routes. |
| Bundled classic-format fan packs | Discovery/import checks exist; whole-library completion is not established | Freeze the shipped corpus. Report each level's decoding, assets, supported mechanics and completion evidence. Preserve winning routes for levels presented as validated. Unverified levels keep the gate open. |
| NeoLemmix fan imports | Partial engine support and explicit unsupported-feature diagnostics | Inventory the imported corpus and its required mechanics. Resolve supported-scope compatibility gaps and preserve representative reference replays for each supported mechanic and combination. Do not count rejection as successful playability. |

The official Classic-family gap is 69 of 292 levels. This excludes converted and
fan collections. Campaign counts come from the committed completion manifests,
read on 12 September 2026. The dated audit reports below keep the counts of their
own run. The corpus audit in this document reports 61 Oh No! routes, because it
measured build 20.6.

## What validation means

1. Freeze source, assets and the bundled fan-pack index. Record pack, level and
   asset hashes so additions cannot inherit a previous validation result.
2. Check every bundled level for decoding, assets, original constraints and
   required mechanics. Track unsupported, unverified and verified separately.
3. Replay a winning witness from a fresh session and check accepted inputs,
   required rescues and deterministic outcomes. Loading, rendering and smoke
   simulation are separate checks and do not prove a solution.
4. Validate campaign and pack progression, retry, result actions and endings.
   Independent winning routes do not prove continuous progression.
5. Exercise solo and Hot Seat ownership, interrupted attempts, checkpoints,
   relaunch, upgrade and recovery across official, converted and fan sources.
6. Validate shared QoL: modern/OG controls, pause, speed, Escape, keyboard overlay,
   help, scaling, artwork and soundtrack selection. Preserve the Classic regression
   gate during subsequent L2/L3 work.

For newly downloaded and user-supplied packs, support must be defined by format
and mechanics, with explicit diagnostics. An arbitrary future pack cannot inherit
a claim that its individual levels were playtested. This does not exempt the
bundled fan library from the per-level inventory and validation above.

NeoLemmix support is not equivalent to Classic DOS compatibility. Current code
rejects Fencer, Laserer and several object effects, including locked exits,
buttons, pickups, teleporters and updrafts. These are real compatibility limits,
not merely missing solution records. The scope review must account for them
before broad fan-compatibility claims are made.

## Ownership and release boundary

Claude retains campaign solver and route-fixture work. Codex owns the combined
coverage review, fan compatibility inventory, shared app regression checks and
release integration, without duplicating that solver work.

Beta 21 remains a consolidation and validation beta. Do not mark Classic complete
or move exclusively to L2/L3 until this gate closes. Record any changed scope
explicitly rather than silently excluding an inconvenient pack or mechanic.

## Beta validation run

The [full corpus audit](ClassicBetaValidation.md) accounts for all 6,395 indexed
levels and reports each result. Build 20.6 fixes fan graphics selection and stale
failed-level briefings. Ninety-four fan levels still fail to load or start, and
5,886 levels lack verified winning evidence. The completion gate remains open.
