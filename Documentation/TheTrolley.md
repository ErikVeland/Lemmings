# THE TROLLEY

THE TROLLEY asks how many Lemmings a completed attempt saved compared with what
is known to be saveable. It runs after the engine has ended an attempt, on both
success and failure. It does not take part in physics, rescue rules, medals,
scoring, campaign saves, or progression.

The existing result page hosts it inside the game window. On a clear, **Next
level** is the primary button. **Enter**, keypad Enter, and **Space** take that
action. At a campaign or pack boundary, the label follows the existing Continue
or level-selection route. Additional stars never delay progression. **R** and
the secondary Retry button use the existing fresh-start path.
On failure, the primary button and Enter retry. **Escape** returns to the game.
**V** opens the run movie. **B**, **A**, and **D** open records, awards, and details.
Left/right arrows change award pages. Returning from these pages does not advance
the level. Holding a result action key does not repeat it.

All five Arcade pages, replay controls and confirmation pages use the shipped Macintosh bitmap
fonts for every label, heading and paragraph. They share the briefing's stone
edging, moss cap, black panels, silver menu selection and Lemming sprites.
Result pages show the outcome, rescued count, three visible star thresholds,
new level and career awards, personal records, near misses and leaderboard links.
See [Results and rewards](ResultRewards.md) for the current presentation. Play style names open a native
popover explaining the philosopher and the matching play style. New awards have
a separate link. Records use aligned columns and a Rewinds filter with explicit
Unused and Used selections. Awards wrap across four entries per page. Rescue stars and achievement
marks share one pixel drawing. Worldwide rankings use Apple Game Center when configured. The worldwide page
explains when service is unavailable. Local records remain usable offline.

## Stored rescue rating

The stored star rating remains compatible with existing attempts. The result
shows the current run rating, level best, and exact goals. Stars rate rescue goals for this attempt. They do not rate the player or replace
the six philosophical dimensions, native medals, unlocks, or campaign saves.

- **One star:** meet the original rescue requirement and pass the engine's checks.
  This is enough to continue.
- **Two stars:** save at least one more than required.
- **Three stars:** match a verified maximum or a bundled best-known rescue target, or actually rescue the entire finite
  population, including all possible finite clones. This does not promote an
  observed maximum to verified or grant verified-only achievements.

When the requirement already equals a verified maximum or the full finite
population, a full rescue earns all three stars together. No impossible extra
rescue is required. Failed attempts earn zero stars, even if a rescue threshold
was reached. Unused cloners prevent an unverified full-cohort award; unlimited
cloners need a verified maximum for three stars.

The result shows **Maximum unknown** until evidence supports a rescue target.
An observed local record alone never becomes the three-star target. Goals are
optional, and unknown maximums do not produce a claim that all starting Lemmings
can be saved. A verified target reads **Best possible**. A replay record reads
**Best known**, since it does not establish an upper bound.

`TrolleyRescueGoals` model version 1 is saved with new attempts. Older Trolley
attempts derive the same goals from their immutable run and maximum snapshot.
Current results and leaderboards reassess those runs against the current target without changing stored snapshots or awards. Legacy compact Arcade records
can show a rescue rating without inventing philosophical history.

## Evidence and populations

Each compatible configuration has separate maximum metadata:

- `UNKNOWN`: no completed observation or accepted verification.
- `OBSERVED`: the largest locally recorded rescue, labelled **Local best**.
- `REPLAY_RECORD`: a best-known rescue target backed by a completed native replay; it is not an upper-bound proof.
- `VERIFIED`: a maximum explicitly accepted with a source, date, and build.

Even an observed rescue of the entire population remains `OBSERVED`. Verification
is an explicit metadata operation, `ArcadeStore.acceptMaximum`. The bundled
[rescue audit](TrolleyVerification/README.md) now supplies certificates for native
replays that rescue the full finite population. The app accepts them at level
start only when engine sources, level data and all play conditions match.
Unknown maxima stay unknown. Medal targets and losses in completion fixtures do
not establish unavoidable sacrifices.

Each certificate includes a replay hash. Missing or changed replay data prevents
the catalogue from loading. A changed engine stamp retires its bundled evidence
from current targets without changing historical attempts. No solver or causal
proof is inferred from ordinary gameplay.

An observation above a supplied maximum retires that evidence and returns the
current maximum to `OBSERVED`. The superseded evidence remains in the metadata.
Historical attempts retain the values and interpretations they had at completion.
They do not gain verified achievements retrospectively. Rescue leaderboards reassess compatible attempts using the current target. For best-known records, the zero-loss board is labelled **Record matched**. Records do not unlock proof-only awards.

| Statistic | Definition |
| --- | --- |
| Rescue requirement | The original engine's minimum rescue count |
| Saved | Rescued by the engine, including a failed attempt |
| Lost | Released minus saved |
| Requirement surplus | Saved minus requirement, including negative values |
| Moral surplus | Maximum of zero and requirement surplus |
| Rescue potential | Saved / maximum, when maximum is positive |
| Avoidable losses | Maximum of zero and verified maximum minus saved |
| Unavoidable losses | Released minus verified maximum, for a fully released comparable cohort |

An attempt can end before all Lemmings are released. Unreleased Lemmings and L3
reserves are recorded separately. They are not reported as deaths. Unavoidable
losses remain unknown for a partial cohort. Avoidable losses measure the gap to
the level's verified rescue opportunity; that gap can include unreleased Lemmings.
Details show separate Rescued and Lost rows. Still in hatch appears only when
nonzero; L3 uses In reserve. A nuke stops further hatching, and a timeout can end
a run before all lemmings have appeared. A zero maximum has no percentage.

NeoLemmix preplaced Lemmings and clones count as released individuals. The starting
population remains part of the comparison identity. Clone counts extend the
attempt's actual population; finite cloner supplies bound the possible population.
Unlimited cloners do not create a fabricated finite ceiling.

L2's native engine passes an ended attempt with at least one rescue. Its gold
medal requirement remains in `additionalStatistics` and comparison modifiers.
THE TROLLEY uses one as the formal requirement, without changing medal awards or
carry-over progression. L3's preview has the same minimum; its reserves are not
rescues. Unsupported level formats remain subject to the existing engine's
loading restrictions.

## Classification

`TrolleyAnalyser` is a pure, deterministic service. Its immutable output stores
the model version, all six normalised dimensions, available evidence, all eligible
affinity scores, the primary and optional secondary ID, titles, and explanations.
A dimension value is a feature of this attempt, not a statement about the player.

Version 1 uses these observable proxies:

- **Preservation:** rescue potential against a verified or bundled best-known target, or saved / population ceiling as
  a conservative lower bound when the true maximum is unknown. A weak first
  observation never becomes perfect preservation just because it is best known.
- **Sacrifice:** avoidable losses / verified maximum. It is unavailable without
  verification. The stored zero then has no classification weight.
- **Utility:** preservation multiplied by rescue per action and, where known,
  the fraction of finite supplies left. Unlimited supplies have no scarcity cost.
- **Duty:** preservation and surplus, reduced by destructive skill assignments
  and nuke usage. It is an outcome proxy and does not establish intent.
- **Pragmatism:** proximity to the formal requirement where extra rescue exists.
- **Intervention:** accepted assignments relative to rescue, destructive
  assignments, and nuke use. Rejected clicks never count.

Each archetype declares minimum/maximum feature gates and weighted target values.
Eligible archetypes receive a weighted mean of `1 - abs(feature - target)`.
The highest score wins. Equal scores use the stable archetype ID. A low-weight
Fellow Traveller fallback gives every completed attempt an interpretation.
Definitions are data, separate from UI rendering. See
`Sources/NxlvKit/TrolleyPhilosophy.swift` for exact weights and thresholds.

The initial catalogue includes Bentham, Mill, Kant, Singer, Aristotle, Epicurus,
Hobbes, Sartre, the Absurdist, the Humanist, the Bureaucrat, and the Trolley Operator.
Bentham and the Trolley Operator require explicit causal evidence. Sartre requires
documented unconventional play. Current engine adapters supply neither, so they
cannot award these affinities by guesswork. Kant also requires verified preservation,
actual intervention, high duty, no destructive assignments, and no nuke. A 100%
rescue alone does not select Kant. Destructive terrain work is recorded as
intervention, never as proof of an individual's sacrifice.

The Absolutist, Last Lemming, Pyrrhic Victor, and Trolley Operator are independent
special titles. Popover explanations describe the matching play style without repeating result stats.
Stored prose from older attempts is not used for visible popover copy. No external
language model is involved. The existing awards page includes eight philosophical
achievements with explicit thresholds, including cumulative surplus and verified
maximums on ten distinct levels. Unprovable causal and unconventional-route objectives are hidden unless already earned.
The current bundle also hides the unavoidable-sacrifice objective, for which no
accepted partial-population upper-bound proof exists.

## Identity, records and ordering

`TrolleyConditions` hashes canonical sorted JSON with SHA-256. It includes game,
pack, stable level ID, content fingerprint, starting population, original requirement,
available skills, time limit, simulation version, physics mode, modifiers, and
rewind policy. Assisted attempts have separate board keys. Content fingerprints
include loaded classic masks and triggers, NeoLemmix terrain and configuration,
and sequel data assets. Asset caches invalidate when file size or modification
time changes. Moving identical sequel data does not alter relative asset identities.
Display, audio, pause, and fast-forward settings do not enter this key. Each run
retains the conditions captured at its start. Completion cannot replace them with
newly selected or modified level data.

There is one best entry per profile on each compatible local board:

| Board | Eligibility and primary ordering |
| --- | --- |
| Most saved | All completed attempts, most saved |
| Rescue potential | Current verified maximum, highest potential |
| Zero avoidable losses | Current verified maximum matched, most saved |
| Least skills | Engine-successful attempts, fewest assigned skills |
| Most used skill | Highest assignment count for a single skill |
| Moral surplus | Highest moral surplus |
| Clean rescue | Current verified maximum, most saved |

After each board's primary ordering, ties use more saved, fewer avoidable losses
when both values are known, fewer skills, less simulation time, earlier completion
timestamp, then lexicographically earlier UUID. Most-used skill ties within an
attempt use the canonical skill ID. This board measures usage, not merit. Clean
rescue prioritises preservation before efficiency, so using no skills to save less
cannot beat a stronger rescue.

Personal records derive from immutable history. They include best saved, verified
potential, avoidable losses, surplus, successful skill/time records, verified perfect
counts, affinity distribution, common and rare affinities, totals, skill history,
awards, and attempt counts. Rarity means the least frequent affinity in that
profile's recorded history. Retry starts are saved immediately, including retries
after successful clears that have not yet ended. Fresh loads and mid-run restarts
have distinct start kinds and parent attempt references.

## Persistence, migration and replay

The feature extends the existing `ArcadeRecords` file to schema 2 and adds a
versioned `TrolleyHistory`. The file stays at the existing arcade storage path.
Existing initials, portraits, campaign preference keys, achievements, and compact
legacy record summaries are retained. Version 1 migration creates an empty history;
it does not reconstruct unknown attempts or philosopher assignments.

The legacy compact `runs` cache still serves old boards. Trolley attempts and starts
are append-only and are never pruned by that cache. All completion callbacks use the
same attempt UUID for idempotency. Files are written atomically. Unreadable or
unsupported files are preserved and the existing in-game save error is displayed.
The current JSON implementation favours inspectable, portable records. Very large
histories may later need indexed storage through the same service boundary.

Record-setting attempts retain an available movie under `Replays/<attempt-id>.mp4`
beside the records file. The hash and relative path are separate evidence attachments,
so asynchronous movie completion never rewrites the attempt. An immediate retry
allows record movie encoding to finish. Movie failure does not invalidate local
statistics. Rendered movie hashes are `LOCAL` evidence, not deterministic replay
verification. `REPLAY_VERIFIED` and `SERVER_VERIFIED` are reserved model states.

`TrolleySubmission` is a serialisable export model containing profile identity,
optional public initials and sprite portrait, attempt metrics, conditions, affinity,
versions, optional replay evidence, and a submission timestamp. It contains no
transport implementation and makes no online claims. The export service derives an
anonymous ID from a persistent installation namespace and profile ID, so the
legacy `player-one` identifier does not collide across Macs.

## Validation

Run `Scripts/run-trolley-tests.sh` for metric examples, evidence transitions,
classification, history, compatibility, profiles, migration, submission serialisation,
clones, record movies, mouse/keyboard controls, and screenshots at four sizes.
Screenshots are written to `.build/trolley` for visual review. The existing arcade,
app integration, replay, sequel-view, simulation, game-flow and campaign suites
remain independent regression checks.

The initial implementation validation on 9 September 2026 passed the Trolley suite, all 17 broader suites
listed in `.build/trolley-regression-results.txt`, app integration, and sequel
artwork/view integration. Final app and sequel checks were repeated against the
final Trolley module. The screenshots include real L2/L3 result callbacks and
labelled model fixtures for verified rescue examples. No original test assertions
were removed or weakened.

The optional-star and visual refinement passed the Trolley suite, app integration,
classic campaign flow, briefing/panel drawing, replay export and controls, and real L2/L3 one-star progression
checks. The Trolley suite covers mouse, Enter and Space routing, failure retries,
immutable star targets, migration, unknown evidence, finite and unlimited clones,
and all five pages at the small window size. Result screenshots also cover four
aspect ratios. The original Arcade test's final OS key-window assertion fails in
this desktop session because its accessory test app is inactive. The previous
build fails at the same assertion. Its record, profile, nested-page and callback
checks pass before that assertion; it has not been removed or weakened.

The native menu revision replaces all system text in these pages with the
shipped bitmap fonts, including paragraphs and replay controls. The shared
confirmation page uses the same lettering, edging and silver action button.
The Trolley, app integration, playfield, replay and sequel suites cover the
revised rendering, input, wrapping, page navigation and one-star progression.

All 120 Classic DOS levels have bundled rescue targets: 103 full-population proofs and 17 best-known records. The latter show the losses in the best-known solution and the shortfall from its rescue count. They do not label those losses unavoidable. Matching either target earns three optional stars; clearing the original requirement still makes Next Level the default.

## Karl Popper — The Falsifier

A successful, legitimate run that exceeds an established rescue target earns this special philosopher title. It applies to both best-known records and accepted maximum proofs. Matching a target or improving an ordinary local best does not qualify. The comparison uses the target before the run updates the record, under the same level and assistance conditions.

The result names Karl Popper and shows the old estimate beside the new rescue count. The achievement is awarded once per profile; each qualifying discovery retains its title and prior evidence. Reloading history or reassessing a leaderboard against a newer target does not erase the discovery. Existing attempts without this evidence do not receive it retrospectively.

## Optional achievement collections

The Trolley now has 39 achievements, including 30 new rewards. Every philosophical affinity and all seven level leaderboards link to an achievement. The six existing Arcade level awards remain in the Rescue collection. All rewards are optional: clearing the game's original requirement still makes Next Level the default action.

The native achievement screen has four collections, Bronze through Legendary tiers, and profile-specific progress. Use 1–4 or Up/Down to change collection, and Left/Right to change page. Leaderboards open their related reward; results announce new unlocks and open the featured reward.

| Collection | Examples and requirements |
| --- | --- |
| Rescue | Existing rescue, surplus and maximum-save awards. |
| Philosophy | Kant Touch This, A Mill-ion Reasons and Form 27B/6 reward their corresponding affinity on a clear. Karl Popper — The Falsifier remains a Legendary reward for exceeding an established target. |
| Rivalries | Occam's Razor rewards fewer skills without fewer rescues. The Legendary Triple Crown requires taking Most Saved, Least Skills and Clean Rescue from other local players in one clear. |
| Mastery | The Grand Thesis requires matching targets on 30 distinct levels. The Philosopher King requires 10 different affinities. An Unbroken Argument requires matching targets on five distinct levels in consecutive unassisted attempts. |

Rival trophies require a real performance improvement over another player's leading clear; an empty board or a timestamp tie does not count. Distinct-level milestones cannot be farmed by repeating one level or changing assistance settings. Retry awards require a linked attempt and the specified improvement. Evidence-dependent philosophical titles retain their existing evidence requirements.

Awards persist once earned for each profile. Existing qualifying history contributes to collection progress and is claimed on the next qualifying clear, without rewriting old attempts. Rescue-target milestones use the target recorded with each attempt.

## Achievement scope and play style help

Achievements span all levels for the selected player. Original level awards are
aggregated from existing per-level history without changing saved records. A
level with mandatory skills no longer advertises Hands Off as a local objective.
Hands Off appears once a completed zero-skill clear demonstrates it is attainable.
Unavailable evidence objectives are excluded from counts and pagination. Existing
earned awards remain visible.

The play style popovers use short descriptions of the philosopher's ideas and a
separate explanation of the run's play style. These are playful classifications
of recorded play, not complete representations of a philosophical position.
See [Affinity notes](AffinityNotes.md) for source references.

For Worra lorra lemmings, the bundled [80-rescue replay](../Resources/Trolley/witnesses/lemmings-28.json)
uses a blocker at tick 67. Mining removes the supporting ground and releases
that blocker at tick 219. The blocker is rescued at tick 2647; the completed
replay saves all 80 at tick 2714. This was replayed against the current engine
while revising these screens.

The UI labels philosophical affinity as “Play style”. Names open their popovers without a question-mark suffix. Hovering underlines the name and uses the link cursor.
