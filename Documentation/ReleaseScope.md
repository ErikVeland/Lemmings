# Release scope

Classic 1.0 is the historical macOS release baseline, confirmed on 13 September 2026.
The 1.9 build 75 candidate marks Lemmings 2: The Tribes **Complete** and
Lemmings 3: Chronicles **Beta**, as approved by the owner on 10 October 2026.
The current public release remains 1.8.5 build 74 until the 1.9 packages and
signed update feed are published. See the [1.9 notes](ReleaseNotes-1.9-build75.md).
NeoLemmix remains Beta. The release adds original Macintosh music, release-rate
pitch feedback, optional Macintosh counters, full Hot Seat Resume rosters and
shared saved-run fixes. See [Macintosh fidelity](MacintoshFidelity.md).

Automated evidence supports the recorded native routes. Original-engine
fidelity, high-survivor endings and hardware acceptance retain their recorded
limits. See the [gate register](ReleaseReadiness/gates.json).

## Wording

Three words carry the claims, and they mean different things.

**Complete.** Every level has a preserved winning replay that the native engine
reproduces. The gate fails if a replay is missing, altered, or stops winning.

**Playable.** Every level loads, renders and runs. Some levels have a preserved
winning replay and some do not. A level without one is not a broken level. It is
a level nobody has recorded a win for yet.

**Beta.** The game is available for broader testing, with remaining compatibility,
campaign and fidelity checks stated. Beta does not claim a winning route for
every level.

**Preview.** The game runs and is enjoyable, and its rules are not yet proven
against the original engine. Expect differences.

## Release replay policy

Winning replays and their solvability and difficulty evidence are durable
release evidence. A routine minor release keeps this evidence and does not
replay every level again. It checks the stored fixture manifests and runs the
focused engine regression suites.

Run the full campaign replay gates when a change can alter outcomes across a
campaign. This includes changes to simulation ticks, movement or collision,
terrain or skill rules, replay decoding or execution, level data, or a broad
engine rewrite. Re-run affected routes for local engine changes that do not
meet this threshold. Do not replace a winning route or recalculate a difficulty
score unless the route no longer wins or a full campaign change requires a new
baseline.

The minor audit proves that preserved fixture files match their recorded
hashes. It does not prove that every route still wins on the new engine. The
full audit provides that proof. Record the chosen scope and any affected-route
checks with the release evidence.

## macOS 1.5 public scope

The 1.5 release targets Intel and Apple silicon Macs running macOS 12.3 or
later. The completed 352-level Classic campaign is the primary release claim.
Lemmings 2 and Lemmings 3 remain Preview. NeoLemmix import remains Beta or
Preview until the real-pack, runnable, replay and behaviour gates pass.

The 1.5 crash, startup, input and gameplay-cursor fixes are release changes.
See the [1.5 distribution record](ReleaseReadiness/1.5Build50Distribution.md).
The 1.6 candidate needs signing, notarisation, Gatekeeper and live-update
evidence for its final commit. See the [1.6 validation record](ReleaseReadiness/1.6LocalValidation.md).

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
| Lemmings 2: The Tribes | 120 | 120 | **Complete** |
| Lemmings 3: The Chronicles | 90 | 74 | **Beta** |

The strict native L2 gate passes all 120 standalone routes, 70 carry-over variants
and twelve continuous tribe chains. Every witness reproduces its win twice with
matching saved counts, ticks and state hashes. These chains finish with one
lemming. The ark ending requires a golden talisman and at least 30 survivors
from each tribe, and remains unproved.
See [L2 completion evidence](Lemmings2Completion/README.md).

The current L3 evidence records 74 of 90 standalone wins, 155 carried fixtures
replayed twice and 68 linked campaign results. Sixteen standalone routes remain
missing. The three continuous campaigns with at least 50 survivors, original
DOS parity and verified endings remain open. See the
[sequel verification record](ReleaseReadiness/1.8SequelVerification.md).

Both play through their campaigns with original artwork, music and interfaces.
Lemmings 3 keeps provisional rules in several areas, and its environmental
effects, movie soundtracks and story transitions are incomplete.

The owner approved these 1.9 release classifications on 10 October 2026.
L2 meets the per-level winning-route definition of Complete. Its high-survivor
ark ending and original-engine equivalence remain separate evidence gaps.
L3 Beta keeps its sixteen missing standalone routes and open media, campaign
and fidelity checks visible. The classifications do not close those gates.

## iPhone and iPad 2.0

The repository contains an iOS 16 UIKit/Metal application target. Its first
player-facing slice imports a player-owned Classic DOS folder. It uses the same
deterministic Classic simulation as the Mac application and adds direct touch,
pan, zoom, safe-area controls, interruption recovery and thermal presentation
budgets.

The 1.3 source milestone is development evidence, not a tested iPhone/iPad release.
Lemmings 2 and Lemmings 3 have shared mobile session and checkpoint adapters,
but no player-facing mobile import or renderer. Recorded Simulator checks pass
for the 1.3 source commit. Physical-device, accessibility, signing and
distribution gates remain open. See the
[2.0 roadmap](2.0Roadmap.md).

## Not in this release

The macOS 1.5 release does not include iPhone, iPad or consoles. Mobile 2.0 is a
separate release gate. Consoles have no application target. A Mac
release does not imply support for either platform group.

## Retained validation limits

- The `Oh My! ALL Lemmings!` run across the sequel campaigns remains outside the
  completed 352-level Classic campaign gate.
- L2 is Complete and L3 is Beta for 1.9. L2 has no missing level routes. L3 retains
  16 missing routes, tracked separately from the Classic 1.0 milestone.
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
