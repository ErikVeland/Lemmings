# Difficulty progression audit

The implementation is not yet ready for a production release of the full brief.
The current core and catalogue UI work, but NeoLemmix catalogue launch routing,
causal technique inference and broader replay calibration remain open.

## Validation

The final Swift package run passed 79 tests: 49 shared-core tests, 17 desktop
tests and 13 mobile-core tests. This includes 20 new difficulty tests and one new
render/input-target test. The real simulation fixtures cover a forgiving Floater
window, a broad one-sided window and a narrow Builder bridge window.

The Classic replay regression script passed. The added read-only replay observer
also reproduces the same winning outcome and final state hash as normal playback.

The policy page was rendered to `/tmp/lemmings-progression.png` and inspected.
All five controls fit, accept focus and have pointer targets. The render uses the
existing bitmap menu controls and focus outline. Full user journeys through long
analysis, cancellation, all generated playlist states and Hot Seat have not been
visually exercised.

Engine sources were being edited concurrently by another task. Compilation of
live sources was interrupted twice by those edits. Compatibility gates and the
corpus tool therefore use separate source snapshots with SHA-256 manifests.
Their results do not certify later simulator edits in the shared working tree.

## Corpus scope

The audit uses the largest discovered unpacked local NeoLemmix corpus: 794
levels, the local 160-file Redux replay collection, and the supplied CE styles.
It also analyses the 120-level official DOS campaign using the installed 350-record
solution catalogue. Not every replay record belongs to this campaign.

The combined audit covers 914 levels. This is not an audit of every compressed
fan pack or every installed sequel campaign. Imported NXLV levels retain
community/unverified provenance, even when their filenames resemble retail levels.
Official provenance comes from `ClassicDataSet`.

The bounded audit permits ten timing runs per solution. Most winning replay
profiles consequently have medium confidence. Unknown probes remain unknown;
metadata-only fallback profiles are retained after missing assets or replay failure.

## Recorded results

Analysis version: `difficulty-2`. Final playlist policy version: `progression-3`.
The analysis snapshot fingerprint is
`1846a144d289e19328dd83edd4baac264264f58e007a4fc109edb1bea2ce635e`.

Confidence counts are 1 high (0.1%), 346 medium (37.9%) and 567 low (62.0%).
The minimum, median and maximum scores are 27.3, 101.6 and 695.4.

| Grade | Official DOS | Community/unverified | Total |
| --- | ---: | ---: | ---: |
| Beginner | 6 | 435 | 441 |
| Easy | 22 | 158 | 180 |
| Moderate | 25 | 53 | 78 |
| Tricky | 36 | 45 | 81 |
| Challenging | 20 | 64 | 84 |
| Hard | 11 | 35 | 46 |
| Very Hard | 0 | 4 | 4 |
| Expert | 0 | 0 | 0 |
| Extreme | 0 | 0 | 0 |
| Master | 0 | 0 | 0 |

No score reached Expert, Extreme or Master. Missing advanced causal evidence and
weak metadata priors limit this calibration. This is not evidence that the corpus
contains no difficult human puzzles.

The audit retained 82 NeoLemmix fallbacks: 50 replay non-wins, 25 missing-style
failures and 7 baseline frame-budget limits. All 120 DOS campaign levels had
usable winning replay evidence in this audit. A partial timing budget still
limits their confidence.

The final Smooth Progression contains 37 levels, including 20 official levels.
It starts with official Fun 1. Original+ contains 100 levels at the default cap,
including 52 official levels and 48 community bridges. It retains the first six
official tutorials consecutively. The cap means this is not the full 120-level
campaign. Small score regressions can reinforce a known concept.

The largest recorded official mechanical jump is Mayhem 14 to Mayhem 15:
464.3 points. It is a difference in observed solution burden, not proof of a human
learning gap. Inspect its source replay and component explanations before using
it as a calibration anchor.

The most frequent detected concepts were Builder (282), Basher (228), Digger
(199), multiple-worker coordination (174) and Miner (145). Full frequencies and
selection explanations remain in the generated JSON.

Local evidence files:

- `.build/difficulty-corpus-v2/combined/profiles.json`: analysed profiles.
- `.build/difficulty-corpus-v2/combined/playlist-report.json`: final distributions,
  campaign jumps, failures and both playlist orders.
- `.build/difficulty-corpus-v2/concepts.json`: NeoLemmix corpus statistics.
- `.build/difficulty-diagnostics/source-manifest.sha256`: compilation inputs.
- `.build/difficulty-validation-v2/source-manifest.sha256`: compatibility inputs.

The final source snapshot passed parser, style, rendering, all 26 simulation test
groups, replay import/playback, end-to-end simulation and sprite gates. The
reference CE executable comparison and a gate against later live simulator edits
remain open. The policy-only update was checked by the full Swift test suite and
regenerated directly from cached profiles, without rerunning physics.

## Findings that changed the implementation

An initial audit identified three concrete pathologies:

- A recorded click at the start of a broad usable window was classified as
  precise because earlier clicks failed. Version 2 tests both sides separately
  and requires measured failure boundaries before adding timing burden.
- Routine identical assignments to one crowd were counted as independent
  worker management. Version 2 discounts repeated worker skill chains and
  counts spatial worker regions for concurrency.
- Hundreds of similar weak priors could fill the curriculum before harder
  levels were reached. Smooth Progression now requires score advancement or
  useful concept reinforcement.

The final policy also adds explicit analysis uncertainty to transition cost.
Original+ considers community bridges only for substantial score/concept gaps,
rejects bridges above the next anchor and stops at the final official anchor.
These rules are covered by deterministic tests.

These corrections follow evidence and regression tests. The scoring weights and
grade thresholds were not adjusted to make the corpus distribution uniform.

## Remaining release work

1. Add NeoLemmix level catalogue and playlist launch routes through the existing
   loader, with sequence recovery, retry, continuation and paused Hot Seat tests.
   Offline NeoLemmix profiles are not yet playable app playlist entries.
2. Add causal trace evidence for terrain modification dependencies, worker/crowd
   ownership, route branches and advanced technique combinations. Current
   detectors deliberately avoid claiming these requirements.
3. Compare multiple successful witnesses and test solution simplification.
   A precise or elaborate winning replay can overstate the level's easiest route.
4. Add assignment-order probes and stronger selection/position evidence where
   the input model supports it. Current pixel-position sensitivity is unknown.
5. Integrate sequel replay evidence and native carryover populations. Current
   sequel grades use metadata assumptions and remain low confidence.
6. Validate all generated and unavailable UI states and complete the final
   compatibility gates after concurrent engine work settles.

The current greedy graph is useful for inspection and iteration. It does not yet
establish a complete, calibrated Beginner-to-Master teaching sequence.
