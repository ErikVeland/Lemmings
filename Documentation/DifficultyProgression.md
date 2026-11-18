# Difficulty and progression

## Meaning and scope

The golden path has 297 unique puzzles in 13 authored teaching chapters. The full order
is pinned in `Artifacts/LearningJourney/course-plan.json` and `seasonal-plan.json`, with exact sources,
winning replays, chapter goals, learning roles and placement reasons. Course
positions are editorial ordinals. They are not measured human difficulty scores.
Original measured replay scores remain unchanged.

Learning-30 preserves the complete first 80 learning-29 lesson records after
Erik and Uva reported a good curve through approximately 80 completed lessons.
It adds 70 seasonal sources to the later course. All 72 official 1991–1994
Xmas/Holiday entries are represented. Two exact-state equivalents already form
the closing pair. See the [later-curve review](JourneyCurveReview-2026-10-26.md).

The opening has 30 beginner lessons: the original skill tutorials, Cellbash,
simple native practice and all 20 Tame levels. Fifteen lessons then combine
familiar skills before tighter budgets. The course continues through generous
route planning, tool budgets, longer routes, small budgets, worker skill chains,
timed assignments, hatch coordination, strict combinations, clocks, advanced
routes and final challenges. Practice and recovery lessons sit between challenges.
`teaching-plan.json` keeps the stricter evidence checks for the opening lessons.

Simple practice requires at most two used skill types, no job changes or measured
narrow timing, spare used skills and a rescue margin. Tame supplies 20 of every
skill, release rate 1 and a 50% rescue target. Elaborate stored replays must not
push these lessons behind constrained puzzles. We all fall down supplies slow,
single-skill full-rescue practice at lesson 33. This should be a doddle! and
A ladder would be handy provide generous construction practice at 46 and 47.

The course review uses rescue fraction, available skill types and quantities,
used-tool reserves, minimum release rate, hatch count, assignments per tick and
second, distinct worker demand, worker skill chains and timing evidence. Available
tool scarcity is separate from the amount consumed by one witness. Native source
export records all hatch counts and release limits. Classic cannot reduce release
below the authored starting rate. Hatches share one global spawn clock, so extra
hatches increase coordination demand without multiplying spawn frequency.
Same-tick assignments can use Pause. They do not establish physically simultaneous
clicks or prove that the recorded execution is necessary.

All 297 native replay records include the first tick that reaches the rescue quota
and the tools remaining at that tick. Successful tool consumption must match the
recorded commands before quota. Later commands do not inflate useful workload.
Deadline pressure uses the quota tick rather than replay shutdown. This corrects
false deadline pressure in routes that had already won before running to timeout.

`course-review.json` records all 297 transitions across eight pressure axes:
rescue, available tool scarcity, minimum release rate, hatches, command density,
worker skill chains, precision and deadline. After the foundations, a transition
cannot raise more than two axes by over 30 points. A lesson cannot introduce more
than two peaks over the pressure already encountered twice. Earlier examples
share skills and comparable pressures. They indicate preparation, but do not
prove that a player has learned a puzzle's hidden trick. These gates catch
compound jumps. They do not certify novice discovery or special pacing.

Player-reported walls have explicit `tooHardForEarlyJourney` verdicts and later
placement floors in `route-safety.json`. They remain in the Journey, with easier
practice before them. `difficulty-walls.json` records their current positions,
warning signs and preparation gaps. Watson follows small-budget practice at 97.
PoP YoR ToP!!! follows group coordination at 165. Just A Quicky follows strict
combinations after worker routing, containment and skill-chain practice.
Time waits for no Lemming and This Corrosion remain the closing pair.

Redux provides comparison evidence. A retail rank alone must not hide useful
easy practice. Fan bridges need an exact human solution review, comparable
reference bounds and a real gap between official lessons. Machine estimates
alone cannot admit fan or NeoLemmix puzzles. Simple artwork and short replays
can conceal difficult discovery. The owner requested all unique Xmas/Holiday
puzzles on 26 October 2026. Their authored placements retain exact native routes
and explicitly await human difficulty review. All Hail and Blizzard entries
remain in advanced practice or final challenges. A short replay or a seasonal
rank name does not establish easy discovery. The owner-confirmed Cellbash practice and official
Macintosh port counterpart remain explicit exceptions.

Older built-in saved journeys restore the authored order of all unvisited lessons,
including a current puzzle that moved later. They remove unvisited retired levels
while keeping past visits, completed records, run identity and player or Hot Seat
ownership. Custom playlists and newer saved versions retain their order. The path
uses Classic mechanics. Lemmings 2 and Lemmings 3 retain their own campaigns and
queues. Mac, iOS and tvOS bundle the same current Journey data.

Winning a Golden Path lesson also completes that level in its source category.
Classic, Oh No!, Oh Yes!, festive and fan levels share these completions with
their normal level lists and cloud progress. Existing saved Journey wins receive
the same credit without replaying. Deferred lessons do not count. Repeated wins
count once, and solo profiles and Hot Seat sessions retain separate progress.
Imported Classic sources retain their exact source identity. Legacy sequel
Journey wins count as source completions without changing campaign populations,
medals or endings.

Current selection and evidence are in `Artifacts/LearningJourney`. Regenerate
with `python3 Tools/DifficultyDiagnostics/human_journey.py`. Its `--check` option
checks the manifest, curriculum, transition review and supporting outputs against
the authored inputs. Native replay checks require bundled assets. A native win
proves one route. Human insight, the easiest solution and the experience of a
novice still require playtesting.

The complete Classic replacement playlist and its per-level audit are in
`Artifacts/ClassicProgression`. This later audit includes the compressed Classic
fan archives, all official Classic campaigns, and the port-exclusive campaign.
It preserves all official anchors instead of applying the earlier 100-level cap.
The report distinguishes estimated fan placements from validated replay evidence
and lists remaining gaps.

Reproduce it with:

```sh
zsh Scripts/run-classic-progression-audit.sh \
  '.build/local/Ultimate Lemmings.app/Contents/Resources' \
  Resources/Hints/solutions.json Artifacts/ClassicProgression
```

An optional fourth argument installs the playlist for that existing player ID
through `LevelPlaylistStore`. This preserves other playlists, saved runs and
campaign progress. The script uses the existing Lemmix importer for archived fan
recordings, then requires native winning playback before treating them as evidence.

Difficulty estimates the burden of an observed solution. It is not an objective
measurement of human puzzle insight. A winning replay demonstrates one route,
not the only route or the easiest route. Human deduction cannot be perfectly
inferred mechanically.

Scores retain floating-point precision from 0 to 1000. Each 100-point interval
maps to Beginner, Easy, Moderate, Tricky, Challenging, Hard, Very Hard, Expert,
Extreme or Master. The final interval includes 1000. Grade names describe an
estimate, not a guarantee of what a player will find difficult.

This implementation provides a working analysis core and catalogue integration.
It does **not yet fulfil the entire production brief**. In particular, direct
NeoLemmix files are opened through the existing standalone loader, which has no
playlist catalogue route. The offline corpus tool analyses those files, but does
not silently convert them into Classic playlist entries in the app. Extending
that route needs sequence, recovery and Hot Seat tests before it can ship.

## Human calibration priority — 19 October 2026

Follow the [newcomer playtest protocol](BetaTesting.md#newcomer-and-veteran-playtests)
before another broad reorder or expansion. Keep hard original puzzles and free
Try later. Observe the first assignment, direction, pause, free magnification,
recovery, hint discovery and next-day resume. Teach through existing playable
lessons instead of adding mandatory text or technology choices before play.
Human-author exact-level hint reasoning at observed walls, and clearly separate
general coaching when no checked hint exists. L2/L3 teaching sequences need
native route and carry-over evidence; the Classic course is not sequel acceptance.
No new human calibration is claimed by this plan.

## Components and evidence

`DifficultyProfile` is Codable. It contains the precise score, confidence,
components, source rank, observed concepts, prerequisite hints, critical action
identifiers, probe outcomes and explanations.

| Component | Weight | Current evidence |
| --- | ---: | --- |
| Technique burden | 25% | Successfully assigned skills and supported observed interactions |
| Solution complexity | 22% | Distinct used skills, changes in a worker's assigned skill, distinct worker skill chains, logarithmically discounted repetition |
| Execution precision | 20% | Timing failures, sampled tolerance, nonlinear penalty for multiple narrow actions; nearby target probes where available |
| Concurrency | 13% | Spatially separated groups of overlapping skilled workers and rapid assignments in distant regions |
| Constraints | 13% | Remaining instances of used skills, rescue ratio and time slack |
| Deduction proxy | 7% | Same-worker skill chains, unused choices and object systems |

Weights and calibration terms live in `DifficultyModel`, `DifficultyCalibration`
and `ProgressionWeights`. The model deliberately gives repeated actions little
weight. Multiple narrow actions and simultaneous new advanced concepts incur
nonlinear penalties. No distribution target is used to tune these constants.

The deduction proxy has weaker evidence than measured execution. Profile
confidence does not turn this proxy into a measurement of human insight.

## Technique detection

`DifficultyTechniques.definitions` is an extensible catalogue with explicit
evidence requirements and prerequisite hints. All 21 currently supported
NeoLemmix assignment skills have basic definitions. Advanced observations include
skill cancellation, simultaneous skilled workers, release interval changes,
pickup events, unlock button events, trap disarming and teleportation.

The trace records **use**, not necessity. Pickup and button interactions do not
claim a proven dependency. A nearby terrain mask does not establish pixel-perfect
execution. Spearer, grenader and timebomber are not implemented by this NeoLemmix
simulator and are not reported as supported skills.

Worker isolation/recovery, staircase interception/extension, modification
ownership, destructive intersections, route branching, fall/landing plans,
necessary sacrifice, blocker causality and crowd dependencies still need
reliable trace detectors. The current same-worker skill-change count is a
complexity proxy, not a causal dependency graph. Terrain modifications and
meaningful action transitions are not yet traced into a causal solution graph.
The blocker-turnaround definition is reserved; no adapter emits it without
causal evidence.

## Replay validation and probes

NeoLemmix analysis first verifies the level ID/version and replays the solution
with `NxrpReplayPlayback`. Complete source state checks use strict playback.
Older compatible replays retain medium confidence. Classic uses
`ClassicDOSReplayPlayer`, including its initial-state and final-outcome checks.
An optional observer exposes simulation states without changing command timing.

Timing probes test -1/+1, -2/+2, -4/+4, -8/+8 and -16/+16 frames. A round-robin
budget visits actions before spending more probes on the same action. The
default ceiling is 160 simulations per solution. NeoLemmix runs stop at 30,600
frames and use the source checker's five-minute tail after the last action or
recorded finish frame. Two inconclusive runs stop further timing work. Classic
retains the replay player's existing ceiling. Cancellation is
checked between probes and during simulation.

Classic probes only skill inputs that succeeded in the baseline playback.
Rejected legacy assignments and commands after completion do not consume the
probe budget. Rate changes are detected for both legacy and live input timing.
These corrections use analyser version `difficulty-3`. Older stored corpus
profiles remain historical evidence until reanalysed.

A perturbation may finish earlier or later than its reference solution. Its
recorded completion frame is therefore removed; baseline validation remains
strict. Invalid target assignments can fail. A simulation timeout is unknown,
not a demonstrated timing failure, and does not discard a validated baseline.

The reported tolerance is a **sampled usable tolerance on either side**, not a proven
continuous assignment window. A broad one-sided window is forgiving even if the recorded click is at its
boundary. The median and narrowest values retain this meaning. Untested offsets never become failures. Several narrow actions add a
superlinear burden. Where NeoLemmix offers nearby eligible targets, a bounded
part of the run budget tests them. Coordinate sensitivity remains unavailable:
these replay APIs assign skills to identifiers, not to arbitrary pointer pixels.
Assignment ordering experiments are not implemented yet.

## Confidence and no-replay levels

- **High:** exact validated replay, with complete scheduled timing probes.
- **Medium:** winning replay with partial probes or compatible source checks.
- **Low:** resource and object metadata only.

Low-confidence levels remain eligible. Available skills never become detected
required concepts. Their scores are weak priors and can substantially understate
hard puzzles. An unknown execution component is not evidence of forgiving play;
the Low Precision policy adds an uncertainty penalty.

Classic and NeoLemmix have replay adapters. Lemmings 2 and Lemmings 3 use their
native metadata loaders only. L2 metadata assumes a full 60-lemming tribe and
uses the gold rescue target. L3 metadata assumes the campaign's 20-lemming start
and one-survivor completion rule. Carryover populations, tool dependencies and
sequel replay precision are not calibrated. No controls, handover rules or
saved-run formats are changed.

## Corpus evidence

`DifficultyCorpusStatistics` stores concept frequency, co-occurrence, pack/rank
occurrence and prerequisite-like edges. Edges require at least five joint
observations, at least 90% conditional occurrence and at least twice as many
occurrences of the prerequisite. Strict frequency growth prevents cycles.
These are correlations, not logical requirements. Rarity alone never adds
score. Pack ranks are preserved. An adapter may supply a small numeric metadata
prior, but rank names are not parsed into difficulty scores.

## Playlist graph and policies

`ProgressionGenerator` traverses an implicit directed graph over cached profiles.
Edge cost includes score jumps, component jumps, new concepts, missing
prerequisites, repetition, pack diversity and the uncertainty of both analyses. The cumulative concept set affects
each choice. At most two initial exposures justify a plateau or regression;
otherwise the curriculum must advance rather than exhaust hundreds of identical
metadata estimates.

Candidate order is canonical by engine, pack and level identity. Cost ties use
that identity. Near-best choices prefer confidence, then a bounded official
bonus. The bonus is capped at five cost units and the near-best band at ten.
Neither can buy a materially worse transition. The selected order and diagnostic
reasons are deterministic. Saved playlist UUIDs and creation dates retain the
existing persistence behaviour.

- **Smooth Progression:** advances while introducing and reinforcing concepts.
- **Original+ Progression:** preserves the official anchor order and considers
  community levels that bridge a substantial score or concept gap to the next
  anchor, without overshooting it.
- **Low Precision:** penalises measured precision, concurrency and unknown precision.
- **Execution Challenge:** permits demanding execution with a bounded preference.
- **Technique Curriculum:** filters demonstrated concepts and their prerequisites.

Official provenance comes from `ClassicDataSet` and the native sequel campaign
routes. It is never guessed from a level filename. Imported NXLV diagnostics
without authoritative provenance remain community/unverified.

Generated playlists use `LevelPlaylist` and the existing editor and run flow.
Current unlock and availability rules still apply. The app explicitly analyses
available catalogue entries, including resolved fan packs, in a utility task.
Back cancels analysis. Opening the playlist screen does not run simulations.
The policy menu reuses game bitmap controls. Low-confidence badges say Estimate.
Technique Curriculum reports when no validated local solution demonstrates the
chosen concept.

Each selected level has a diagnostic reason, score, transition cost and introduced
concepts. These stay out of the normal player UI. The current greedy traversal
is bounded to 100 levels by default. It does not guarantee coverage through
Master when the corpus lacks suitable evidence or intermediate steps.

## Persistence and invalidation

Analysis files are separate from campaign saves and playlist documents:
`Application Support/Ultimate Lemmings/Difficulty/` contains `profiles.json`,
`concepts.json`, `analysis-failures.json` and per-policy selection diagnostics.
Writes are atomic. Profiles use full level identity/revision, replay revision,
asset revision, analyser version and simulation version. Pack source revisions
come from the existing catalogue. Classic replay assets include the initial
simulation fingerprint and bundled engine fingerprint.

Change `DifficultyModel.version` when detectors, scoring or probe policy change.
Change `simulationVersion` when relevant simulation semantics change. External
callers must include style/mask revisions and non-default probe configuration in
their cache keys. Corpus statistics reuse requires the same full profile-key set.
Saved game compatibility never depends on the analyser version.

Multi-process merging of the disposable cache is not provided. A cancelled first
analysis may lose newly computed cache entries, but cannot corrupt a saved run.

## Validation and audit

Run `swift test`. The difficulty tests cover grades, mechanical ordering,
constraints, concurrency, technique combinations, confidence, caching,
determinism, official preference, community bridges, policy filtering and
real-simulator timing sensitivity. `ProgressionMenuTests` renders the policy page
and checks focus and pointer targets. Set `LEMMINGS_PROGRESSION_SCREENSHOT` to
save its render.

The offline corpus command uses the existing parsers, style resolver, renderers
and simulators. It snapshots its compilation inputs and writes a checksum
manifest so concurrent engine work cannot invalidate an in-progress build:

```sh
Scripts/run-difficulty-diagnostics.sh \
  /path/to/levels /path/to/replays /path/to/styles \
  .build/difficulty-corpus 10 \
  Content/lemming1.pc Resources/Hints/solutions.json
```

The last two arguments are optional and add an official Classic campaign audit.
For policy changes, regenerate diagnostics from cached profiles without rerunning
physics:

```sh
Scripts/run-difficulty-playlist-diagnostics.sh \
  .build/difficulty-corpus/combined/profiles.json Content/lemming1.pc \
  .build/difficulty-corpus/combined/playlist-report.json
```

Reports include confidence percentages, grade counts split by provenance,
technique frequencies, scores, largest official score jumps and both progression
orders. `profiles.json` and `concepts.json` retain inspectable evidence. A budget
of ten probes is an audit configuration, not complete precision analysis.

See `DifficultyProgressionAudit.md` for the local results and remaining release
gaps. Passing tests does not establish human difficulty calibration, complete
technique inference or NeoLemmix playlist/Hot Seat support.

## Solo progression eligibility

All generated policies reject competitive Versus and known two-player fan packs
through the same eligibility rule as the teaching Journey. This includes
There can be only one. A winning one-player replay cannot override that rule.
Saved Mac sequence queues and mobile/TV learning queues remove competitive
entries on load. A mixed queue advances to its next solo entry. Run identity,
session ownership and completion records remain intact. An entirely competitive
queue has no resumable solo run. New Mac sequence starts apply the same filter.
Standalone source libraries retain their authored levels.

Low-confidence fan estimates have a placement floor of 300 in generated solo
progression. The measured score stays unchanged. Reviewed teaching lessons keep
their authored placement. This floor is conservative and does not certify that
a fan puzzle is suitable for beginners. Progression generation uses version 5.
