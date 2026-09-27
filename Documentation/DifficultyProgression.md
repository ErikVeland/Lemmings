# Difficulty and progression

## Meaning and scope

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
