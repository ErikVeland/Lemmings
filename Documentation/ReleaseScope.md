# Release scope

Classic 1.0 is the selected macOS release target, confirmed on 13 September 2026.
L2 and L3 remain previews. This document describes the working source after beta 32.
Automated checks support the recorded routes;
remaining compatibility and hardware claims still need validation. See the [gate register](ReleaseReadiness/gates.json)
and the [1.0 gap evaluation](ReleaseReadiness/OneZeroGapEvaluation.md).

## Wording

Three words carry the claims, and they mean different things.

**Complete.** Every level has a preserved winning replay that the native engine
reproduces. The gate fails if a replay is missing, altered, or stops winning.

**Playable.** Every level loads, renders and runs. Some levels have a preserved
winning replay and some do not. A level without one is not a broken level. It is
a level nobody has recorded a win for yet.

**Preview.** The game runs and is enjoyable, and its rules are not yet proven
against the original engine. Expect differences.

## Classic

| Release | Levels | Proven routes | Claim |
| --- | ---: | ---: | --- |
| Lemmings | 120 | 120 | **Complete** |
| Xmas Lemmings 1991 | 4 | 4 | **Complete** |
| Oh No! More Lemmings | 100 | 72 | Playable |
| Holiday Lemmings 1994 | 32 | 18 | Playable |
| Holiday Lemmings 1993 | 32 | 32 | **Complete** |
| Xmas Lemmings 1992 | 4 | 4 | **Complete** |
| **Classic total** | **292** | **250** | |

The original campaign is the claim that matters most, and it is complete. All 120
levels replay to a win, 103 of them rescuing every lemming. The engine also
applies the original steel-probe rules, so destructive skills behave as the
original does rather than as an approximation.

Oh Yes! More Lemmings contains 60 port-exclusive conversions: Amiga versus
levels and Mega Drive Sunsoft levels. These are separate from the 292 official
DOS campaign levels and need their own winning evidence.

## Fan levels and conversions

Fan levels are part of the Classic validation boundary. The 6,020 retained bundled fan
levels are not all certified playable: the current full-corpus audit recorded
zero load/start failures after the authorised removal of 23 broken records. Its results do not certify later
changes. See [current Classic validation](ReleaseReadiness/ClassicValidation-current.md)
for corpus evidence and [beta 29 readiness](Beta29Readiness.md) for package checks.
Three Oh Yes! conversions now have recorded winning routes. The other 57 and
continuous progression remain unverified.

The removed records are listed in [the pruning manifest](FanLevelPruning.json).
Surviving DAT slots retain their original identities for saved attempts.
See [the Classic 1.0 work record](ClassicOneZero.md) for current closure work.

## Sequels

| Release | Levels | Proven routes | Claim |
| --- | ---: | ---: | --- |
| Lemmings 2: The Tribes | 120 | 73 | **Preview** |
| Lemmings 3: The Chronicles | 90 | 41 | **Preview** |

Both play through their campaigns with original artwork, music and interfaces.
Lemmings 3 keeps provisional rules in several areas, and its environmental
effects, movie soundtracks and story transitions are incomplete.

## Not in this release

iPhone, iPad and consoles. The repository has no working app target for them. A
Mac release does not imply them.

## Open before 1.0

- 56 official Classic levels have no recorded winning route. Fan levels and
  conversions also have unresolved coverage and compatibility gaps.
- L2 and L3 retain preview status; their 129 missing routes are tracked separately
  from the Classic 1.0 milestone.
- Physical Intel, minimum macOS, HDR, multiple displays and high refresh rates
  are untested. Sustained 10x play is not established.
- Scalable menus and VoiceOver navigation are implemented. Full VoiceOver
  listening journeys and physical controller journeys remain unverified.
- Game Center is newly testable and unproven against network loss and account
  changes.
- Distribution rights for the original game data are not settled. No engineering
  work closes that, and it governs any public release.
