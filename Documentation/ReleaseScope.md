# Release scope

Classic 1.0 is the historical macOS release baseline, confirmed on 13 September 2026.
The current public tester release is macOS 1.5 build 50. L2 and L3 remain
previews. Updated 25 September 2026 for the 1.5 release scope.
Automated checks support the recorded routes;
remaining compatibility and hardware claims still need validation. See the [gate register](ReleaseReadiness/gates.json)
and the current [Classic validation](ReleaseReadiness/ClassicValidation-current.md).

## Wording

Three words carry the claims, and they mean different things.

**Complete.** Every level has a preserved winning replay that the native engine
reproduces. The gate fails if a replay is missing, altered, or stops winning.

**Playable.** Every level loads, renders and runs. Some levels have a preserved
winning replay and some do not. A level without one is not a broken level. It is
a level nobody has recorded a win for yet.

**Preview.** The game runs and is enjoyable, and its rules are not yet proven
against the original engine. Expect differences.

## macOS 1.5 public scope

The 1.5 release targets Intel and Apple silicon Macs running macOS 12.3 or
later. The completed 352-level Classic campaign is the primary release claim.
Lemmings 2 and Lemmings 3 remain Preview. NeoLemmix import remains Beta or
Preview until the real-pack, runnable, replay and behaviour gates pass.

The 1.5 crash, startup, input and gameplay-cursor fixes are release changes.
Fresh source, app, signing, notarisation, Gatekeeper and live-update evidence
must still describe the same final commit.
See [1.5 public release readiness](ReleaseReadiness/1.5PublicRelease.md) for the
current gate state.

## Classic

| Release | Levels | Proven routes | Claim |
| --- | ---: | ---: | --- |
| Lemmings | 120 | 120 | **Complete** |
| Xmas Lemmings 1991 | 4 | 4 | **Complete** |
| Oh No! More Lemmings | 100 | 100 | **Complete** |
| Holiday Lemmings 1994 | 32 | 32 | **Complete** |
| Holiday Lemmings 1993 | 32 | 32 | **Complete** |
| Xmas Lemmings 1992 | 4 | 4 | **Complete** |
| **Official Classic total** | **292** | **292** | **Complete** |
| Oh Yes! conversions | 60 | 60 | **Complete** |
| **Classic release total** | **352** | **352** | **Complete** |

The original campaign is the claim that matters most, and it is complete. All 120
levels replay to a win, 103 of them rescuing every lemming. The engine also
applies the original steel-probe rules, so destructive skills behave as the
original does rather than as an approximation.

The official-only quest passes all 292 wins through the app session, with 876
saved-run restores, 292 progress resumes and the final quest result. Run
`zsh Scripts/verify-official-classic.sh` to reproduce it. This isolates the six
official Classic releases; it does not certify the full installed library.

Oh Yes! More Lemmings contains 60 port-exclusive conversions: Amiga versus
levels and Mega Drive Sunsoft levels. These are separate from the 292 official
DOS campaign levels. All 60 now have strictly verified winning evidence.

## Fan levels and conversions

Fan levels must load and start for Classic 1.0. The owner removed the winning-route
requirement for community content on 22 September 2026. The 6,020 retained bundled fan
levels all load and render in the 22 September full-corpus check. There are 344
current fan winning witnesses. A smoke check does not establish a playthrough.
See [current Classic validation](ReleaseReadiness/ClassicValidation-current.md)
for corpus evidence and the change in shared replay coverage.
The expanded Classic quest passes all 352 levels, including conversions, through
the app session and recovery code. It checks 1,056 run restores, 352 progress
resumes, six release transitions and the final quest result. Reproduce it with
`zsh Scripts/verify-official-classic.sh --include-conversions`.
See [combined quest evidence](ReleaseReadiness/ClassicConversionQuest.json).

The removed records are listed in [the pruning manifest](FanLevelPruning.json).
Surviving DAT slots retain their original identities for saved attempts.
See [the current campaign closure evidence](ReleaseReadiness/CampaignClosure-2026-09-22.md) for the retained baseline.

## Sequels

| Release | Levels | Proven routes | Claim |
| --- | ---: | ---: | --- |
| Lemmings 2: The Tribes | 120 | 73 | **Preview** |
| Lemmings 3: The Chronicles | 90 | 41 | **Preview** |

Both play through their campaigns with original artwork, music and interfaces.
Lemmings 3 keeps provisional rules in several areas, and its environmental
effects, movie soundtracks and story transitions are incomplete.

The 1.2 roadmap makes completion verification the exit gate for both sequels.
They remain Preview until all advertised levels have winning-route evidence,
engine-fidelity comparisons, continuous progression, recovery checks, media
closure and verified endings.

## iPhone and iPad 1.3

The repository contains an iOS 16 UIKit/Metal application target. Its first
player-facing slice imports a player-owned Classic DOS folder. It uses the same
deterministic Classic simulation as the Mac application and adds direct touch,
pan, zoom, safe-area controls, interruption recovery and thermal presentation
budgets.

This is a development source claim. It is not a tested iPhone/iPad release.
Lemmings 2 and Lemmings 3 have shared mobile session and checkpoint adapters,
but no player-facing mobile import or renderer. Simulator, physical-device,
accessibility, signing and distribution gates remain open. See the
[1.3 roadmap](1.3Roadmap.md).

## Not in this release

The macOS 1.5 release does not include iPhone, iPad or consoles. Mobile 1.3 is a
separate target and release gate. Consoles have no application target. A Mac
release does not imply support for either platform group.

## Open before 1.0

- The `Oh My! ALL Lemmings!` run across the sequel previews remains outside the
  completed 352-level Classic campaign gate.
- L2 and L3 retain preview status; their 96 missing routes are tracked separately
  from the Classic 1.0 milestone.
- Physical Intel, minimum macOS, HDR, multiple displays and high refresh rates
  are untested. Sustained 10x play is not established.
- Scalable menus and VoiceOver navigation are implemented. Full VoiceOver
  listening journeys and physical controller journeys remain unverified.
- Game Center is newly testable and unproven against network loss and account
  changes.
- The owner confirmed asset-distribution approval on 15 September. The final
  1.0 candidate still needs its own source freeze, validation, signing and notarisation.

See [22 September campaign closure](ReleaseReadiness/CampaignClosure-2026-09-22.md)
for the recovered routes and current validation limits.
