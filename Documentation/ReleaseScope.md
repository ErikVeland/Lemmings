# Release scope

The beta 24 release boundary. Automated checks support the recorded routes;
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
| Oh No! More Lemmings | 100 | 66 | Playable |
| Holiday Lemmings 1994 | 32 | 16 | Playable |
| Holiday Lemmings 1993 | 32 | 14 | Playable |
| Xmas Lemmings 1992 | 4 | 3 | Playable |
| **Classic total** | **292** | **223** | |

The original campaign is the claim that matters most, and it is complete. All 120
levels replay to a win, 103 of them rescuing every lemming. The engine also
applies the original steel-probe rules, so destructive skills behave as the
original does rather than as an approximation.

Oh Yes! More Lemmings converts levels that already appear above. Its 60 levels
load and render. Conversion is not a solution, so it is counted with the release
it converts, never twice.

## Fan levels and conversions

Fan levels are part of the Classic validation boundary. The 6,043 bundled fan
levels are not all certified playable: the earlier full-corpus audit recorded
94 load/start failures and many levels without a winning route. Its results do
not certify later builds. See the beta 23 readiness report for this build’s checks.
Oh Yes! conversions also need their own replay and progression validation.

## Sequels

| Release | Levels | Proven routes | Claim |
| --- | ---: | ---: | --- |
| Lemmings 2: The Tribes | 120 | 64 | **Preview** |
| Lemmings 3: The Chronicles | 90 | 16 | **Preview** |

Both play through their campaigns with original artwork, music and interfaces.
Lemmings 3 keeps provisional rules in several areas, and its environmental
effects, movie soundtracks and story transitions are incomplete.

## Not in this release

iPhone, iPad and consoles. The repository has no working app target for them. A
Mac release does not imply them.

## Open before 1.0

- 69 official Classic levels have no recorded winning route. Fan levels and
  conversions also have unresolved coverage and compatibility gaps.
- L2 and L3 retain preview status; their 130 missing routes are tracked separately
  from the Classic 1.0 milestone.
- Physical Intel, minimum macOS, HDR, multiple displays and high refresh rates
  are untested. Sustained 10x play is not established.
- Scalable text and VoiceOver navigation are incomplete.
- Game Center is newly testable and unproven against network loss and account
  changes.
- Distribution rights for the original game data are not settled. No engineering
  work closes that, and it governs any public release.
