# Ultimate Lemmings roadmap through 3.0

Updated 26 October 2026. Earlier milestone dates below retain their original context.

The [release schedule](ReleaseSchedule.md) now sets delivery priority: Mac first,
then iOS, then tvOS, then sideloading stores. Ship Mac quickly and skip tests
unless the candidate changes an engine. Lower-priority channels follow separately.

The owner has prioritised the [2.2 Duo launch plan](2.2Roadmap.md) for existing
TestFlight groups by Friday, 23 October. On 22 October the owner moved the Duo
launch from 2.4 to 2.2. Device work now proceeds ahead of the first-play (2.3)
and campaign (2.4) milestones. Duo acceptance uses the Simulator until hardware is available.

Ultimate Lemmings has become an edition with its own character, judgement and
generosity. The next stage is to make that experience dependable from a player's
first assignment to a completed campaign, across the devices the edition supports.

This roadmap turns the milestone evaluation into a delivery sequence. The history
records delivered foundations. Versions 2.2 onward are proposed milestones with
completion criteria, without calendar promises. The current
[2.1.2 checklist](ReleaseReadiness/2.1.2Checklist.md) remains the immediate plan.
[Release scope](ReleaseScope.md) governs published claims, and the
[gate register](ReleaseReadiness/gates.json) retains actual acceptance status.

## iOS store coverage

On 25 October 2026, the owner required distribution across iOS sideloading stores.
The [distribution register](IOSDistribution.md) tracks sources, catalogues,
installers and notarised marketplaces with separate delivery and device checks.
AltStore Classic 2.2.2 build 33 is live. Source compatibility alone does not close
SideStore or Feather acceptance. PAL and the other marketplace submissions remain
open until their actual listing and package evidence is recorded.

Update every accepted channel for each release. Record eligibility limits,
closed stores and new stores explicitly. Keep downloads in the canonical repository.

## The character to preserve

The puzzles should invite curiosity, audacity and another attempt. Preserve the
original rules and artwork while making controls forgiving and recovery easy.
Original presentation must remain compatible with modern conveniences.

Carry these strengths through every milestone:

- **Comfortable experimentation.** Keep pause, precise targeting, free basic
  zoom, flexible speed, instant retry, supported rewind and deliberate hint tiers.
- **Playful controls.** Keep the musical wind-up, sprite echoes and optional
  Ridiculous speed, with mute, reduced-motion and reduced-flash choices respected.
- **A curated soundtrack.** Preserve composition identities, special themes,
  credits, stable retry choices and rescue celebrations. Tune the existing
  [soundtrack journey](SoundtrackJourney.md) before adding more music systems.
- **Shared play with clear ownership.** Keep Hot Seat records, saved campaigns
  and previous-player ghosts with the correct player. Every handover waits for Ready.
- **Humour grounded in evidence.** Keep THE TROLLEY optional. Distinguish a local
  best, a best-known route and a proven maximum, and let players exceed our knowledge.
- **Optional affection.** Keep individual names, wants and histories within
  paused inspection or chosen review. Add no needs to tend or duties to perform.
- **Respect for the artwork.** Reuse bitmap lettering, stone controls and original
  panels. Credit original work and identify reconstructed artwork as an interpretation.

An original clear earns progression. Extra rescue earns celebration. Continue and
Retry stay immediately available. New features must earn their place through play.
The [2.1 design priorities](2.1Roadmap.md) and [UI principles](UIPrinciples.md)
define the detailed interaction rules.

## Historical foundations

Version numbers below describe different kinds of milestones. In particular,
mobile source delivery and a published Mac release are separate achievements.
Historical route counts do not certify later engine revisions.

| Milestone | What it established | Evidence and boundary |
| --- | --- | --- |
| 1.0 Classic baseline | A playable native Mac foundation for the original game. | Historical baseline confirmed on 13 September 2026 in [release scope](ReleaseScope.md). Later official Classic coverage spans 352 routes. |
| 1.1 Mac reference edition | Three native engines in one application, shared targeting, sequel rewind/step, replay controls and adaptive music. | [Retained 1.1 notes within the 1.5 release history](https://github.com/ErikVeland/Lemmings/blob/c75284a6dd23f4cfdd7a6c6f2b7f47f7f048f8b8/Documentation/ReleaseNotes-1.5-build50.md). Sequel inclusion did not establish completion. |
| 1.2 Discovery and delivery | Campaign cards, playlists, signed automatic updates and repaired first-launch behaviour. | [Build 41 distribution record](ReleaseReadiness/1.2Build41Distribution.md) verifies download, upgrade, signatures and relaunch. |
| 1.3 Mobile foundation | Shared mobile sessions and a Classic iPhone/iPad import and play path. | [Source handoff](ReleaseReadiness/1.3MobileHandoff.md). A development milestone, with device and release work still ahead. |
| 1.5 Comfortable play | Shared targeting, hints, retry, controller improvements and the catalogue of 495 versions of 210 tunes. NeoLemmix entered as Preview. | [Published build 50 record](ReleaseReadiness/1.5Build50Distribution.md) and [retained notes](https://github.com/ErikVeland/Lemmings/blob/c75284a6dd23f4cfdd7a6c6f2b7f47f7f048f8b8/Documentation/ReleaseNotes-1.5-build50.md). |
| 1.6 Music and continuity | Adaptive transitions, optional soundtrack libraries, saved Solo/Hot Seat sessions and musical speed feedback. | [Music update](MusicUpdate1.6.md) and [validation record](ReleaseReadiness/1.6LocalValidation.md). The later 2.1 release makes basic zoom free. |
| 1.7 Compatibility and learning | Bundled NeoLemmix content and the learning journey broadened discovery. | [Distribution record](ReleaseReadiness/1.7Build53Distribution.md) and [compatibility roadmap](1.7Roadmap.md). Runnable-corpus checks did not establish complete winning-route or style coverage. |
| 1.8 Pixels and sound | Sharper pixel scaling, NeoLemmix sound effects and music recovery after the nuke sequence. | [Build 64 notes](ReleaseReadiness/1.8-build64/ReleaseNotes-1.8-build64.md). Sequels remained Preview at this point. |
| 1.9 Sequel milestone | The Tribes gained its Complete classification. Chronicles advanced to Beta. | [Sequel milestone](ReleaseReadiness/1.9Milestone.md) and [content roadmap](ContentUniverseRoadmap.md). Gold Ark and source fidelity remained separate work. |
| 2.0 Published Mac edition and shared Apple foundations | Mac 2.0 shipped with the existing engine classifications. Mobile and TV work established shared frontends, sessions and recovery paths. | [Mac release record](ReleaseReadiness/2.0-build83/README.md), [mobile roadmap](2.0Roadmap.md) and [TV parity plan](../Apps/UltimateLemmingsTV/IOSParity.md). Full mobile acceptance remained open. |
| 2.1 An edition with its own character | Free basic zoom, independent presentation and conveniences, honest hints, quieter results, optional inspection, short curated games and safer saved journeys. | [2.1 notes](ReleaseNotes-2.1-build93.md). Hot Seat, THE TROLLEY, music and artwork are cumulative foundations across the release line. |
| 2.1.1 Published baseline | Journey progress recovery, worldwide rankings and the merged runtime/menu work reached Mac build 95. | [Release record](ReleaseReadiness/2.1.1-build95/README.md). iOS build 18 and tvOS build 8 have separate TestFlight states and acceptance limits. |

## Current baseline

As recorded on 21 October, Mac 2.1.1 build 95 is published. The 2.1.2 source
preparation is complete, with final package checks and publication pending.
Classic and The Tribes retain Complete. Chronicles and NeoLemmix remain Beta.
The learning curriculum has 227 Classic lessons. Equivalent sequel curricula
are not yet established.

| Content family | Retained winning routes | Work still open |
| --- | --- | --- |
| Official Classic and conversions | 352/352 | Preserve routes through engine changes and complete remaining source-behaviour evidence. |
| Classic fan packs | 2,404/6,019 playable levels | 3,615 routes, source-rule checks and explicit decisions for malformed content. One excluded source row remains archived. |
| The Tribes | 120/120, plus 70 carry-over variants and 12 chains | Source fidelity and high-survivor endings. Gold Ark remains a separate stretch achievement. |
| Chronicles | 86/90, with 399/416 exact fixtures passing | Levels 107, 206, 213 and 229, carried paths, Mole/source fidelity, transitions and media. |
| NeoLemmix | 158/794 | 636 routes, exact-version behaviour and missing styles. Seventy-five levels need styles whose rights remain unresolved. |

These are mixed-date evidence counts, not a fresh audit of one release package.
The [closure record](ReleaseReadiness/BundledClosureVelocity.md) retains their
source and resource limits. It records 4,255 open playable routes overall and
does not support a reliable completion date. Bounded searches without wins do
not prove impossibility.

## Proposed delivery sequence

| Version | Player outcome | Main dependency |
| --- | --- | --- |
| 2.1.2 | Progress, Resume and recovery behave consistently across Apple frontends. | Current shared checklist and final package acceptance. |
| 2.2 | Each supported Apple device feels deliberately made for its controls. | Stable shared flows and physical acceptance. |
| 2.3 | Newcomers find their footing and returning players resume confidently. | Human observations on a stable candidate. |
| 2.4 | Native campaigns lead reliably through their transitions and endings. | Chronicles routes and source-behaviour repairs. |
| 2.5 | Players can revisit selected attempts and discover more of their stories. | Reliable identity, retention and recovery. |
| 2.6 | The edition has a maintainable, credited and clearly bounded content library. | Continuing content closure, rights work and reproducible handover. |
| 2.9 | One complete candidate meets the proposed 3.0 acceptance criteria. | All required player, content and platform gates. |
| 3.0 | A dependable edition from first play to campaign completion and return. | Acceptance of the exact distributed packages. |

These are planning slots, not a requirement to fill every minor version.
Campaign repairs, device acceptance, content closure and rights work can proceed
alongside usability work. Optional expansion follows the access and reliability
foundations. Patch releases can continue without claiming those broader gates closed.

### 2.1.2 Shared progress and safe return

Finish the [existing checklist](ReleaseReadiness/2.1.2Checklist.md): one Resume
per selected session, exact Journey/playlist checkpoint binding, correct sequel
progress ownership, safe backups and consistent controls.

**Complete when:** final-source checks cover Retry, Continue, Menu, relaunch and
restored checkpoints across Classic, L2 and L3. Verify installed upgrades,
package signatures and platform delivery. Keep physical input, live cloud and
other unresolved checks explicit. Do not treat source preparation as publication.

### 2.2 Comfort on every supported Apple device

Carry the same control, help, turn ownership and recovery rules onto Mac, iPhone,
iPad, Duo and Apple TV. Adapt input and layout to each device through shared controls.

Verify complete physical journeys: start, select, assign, pause, retry, continue,
hand over, interrupt, restore and finish. Cover touch crowds, controllers, remotes,
VoiceOver, text scaling, translated layouts, reduced effects and silent use.
Check live sync, account changes, TV cache eviction and sustained performance.

**Complete when:** every advertised platform and input has a recorded end-to-end
acceptance result on the actual package. Check Classic/L2/L3 parity explicitly and
record engine-specific limits. TestFlight uploads, Simulator runs and SDK builds
remain distinct from physical acceptance. Public store delivery requires its own
package, rights, privacy and review gates.

### 2.3 First play and the next day

**Human acceptance: green, 26 October 2026.** The owner reports that the
first-session and next-day playtests are complete, with players other than the
owner observed on every supported device. See the
[acceptance record](ReleaseReadiness/2.3-human-acceptance-2026-10-26.md).

Observe newcomers, returning players and veterans through the first half-hour
and a next-day return, using the [existing playtest protocol](BetaTesting.md#newcomer-and-veteran-playtests).
Include children with a guardian and people unfamiliar with games where practical.

Keep Start Journey primary. Find where players miss skill direction, targeting,
pause, zoom, recovery or help. Improve hints at observed obstacles before growing
the curriculum. Retain fast access for veterans and the free Try later path.
Include optional setup, soundtrack downloads and privacy choices in observations.

**Complete when:** observed players can make an intentional assignment, recover
from a mistake, choose help, continue after a clear and resume the correct run.
Record confusion, voluntary retry and unwanted spoilers. Repair recurring barriers
and repeat affected tasks. Review important translated instructions with humans.
Observe equivalent basic actions in L2/L3 without claiming a sequel learning journey.

### 2.4 Native campaigns from entrance to ending

Preserve accepted Classic and Tribes routes. Resolve the four Chronicles level
gaps and failed carried schedules with behaviour supported by source evidence.
Verify at least one complete carried path per Chronicles tribe, with valid reserves
and tools. Check transitions, endings, original media, save/reload and recovery.

Keep Gold Ark as a distinct Tribes stretch track. A verified ordinary winning
route meets the route MVP. Do not make maximum rescue a new campaign release gate.

**Complete when:** all 90 Chronicles levels have exact winning witnesses, the
required carried campaigns pass, and advertised native rules and campaign media
have evidence for the candidate. Preserve Classic's 352 routes and L2's 120 routes,
70 carry-over variants and 12 chains. Change Beta classifications only when their
actual completion criteria pass. Replayed routes alone do not establish source fidelity.

### 2.5 Attempts worth revisiting

Let players retain a first clear or an improved rescue and compare available
attempts simply. Extend the existing replay and history flows before adding pages.
Keep comparisons optional and preserve standard versus assisted record eligibility.

Use the existing playlist system for short curated sequences with exact variants,
winning witnesses and honest population carry-over. Extend beyond the current
Classic mobile and Classic/L2 Mac samplers only when their native journeys are ready.
Human-review individual names, wants, THE TROLLEY wording, musical celebration and
failure tone. Ordinary failure should still invite another attempt.

**Complete when:** retained attempts survive upgrade and restore with the correct
owner, level, rules and available observations. Comparisons show only recorded
facts. Older movies remain useful without invented actor histories. Review never
advances a Hot Seat turn or changes its Ready boundary. Optional features add no
required screen or delay to Start, Retry or Continue.

### 2.6 Content closure and long-term stewardship

Continue the [bundled-content commitment](ContentUniverseRoadmap.md#bundled-and-imported-scope)
throughout 2.x. Keep one winning witness per included level, exact manifests,
engine-rule evidence, dependency inventories and reproducible tools. Resolve
missing styles and malformed levels through source investigation and recorded
scope decisions. Removing a level from scope does not count as a solved route.

Complete contextual credits and provenance for original teams, ports, artists,
composers, arrangements and community work. Resolve distribution dependencies for
the intended channels. Keep source, issues, releases and artwork handoffs in
`ErikVeland/Lemmings`, with `main` as the default branch.

**Complete when:** the frozen playable bundle meets its route and source-rule
commitment, required assets have documented distribution status, and a new
maintainer can reproduce the supported build and verification path. Imported
content keeps explicit engine/version limits. Maintain save-format, content and
replay migration documentation alongside the code.

Run a bounded Windows/Linux feasibility track after the Apple foundations:
identify platform dependencies, extract adapters where needed, and prove a small
portable shell against shared deterministic fixtures. No Windows/Linux application
target exists today. A full port is a later release decision, not a proposed 3.0
requirement. Consoles remain outside the current scope. See the
[platform plan](ModernReleasePlan.md#platform-plan).

### 2.9 Candidate acceptance

Freeze the source, fixtures, content, credits and platform claims. Assemble the
results of the earlier milestones into one candidate record. Repeat checks when
engine, content or package changes invalidate their evidence. Inspect rendered
states and input targets, and complete the remaining human and hardware journeys.

**Complete when:** the proposed 3.0 criteria below pass against the exact candidate.
Verify migration from installed earlier releases, failed saves, rollback and
downloaded packages. Keep all automated UI checks offscreen and muted through
`Tools/UITestRunner/run.py`. Foreground, display and audible checks require the
explicit requests specified in `AGENTS.md`.

### 3.0 A dependable edition

The proposed 3.0 promise is a complete player journey: discover a puzzle, try an
idea, recover, finish a campaign, share a turn and return later with progress intact.
Its character comes from the music, humour, artwork and optional discoveries
already established.

Proposed acceptance criteria:

- First-session and next-day observations show usable teaching, help and recovery,
  with recurring barriers repaired and checked again.
- Native campaigns pass their route, carry-over, source-behaviour, transition and
  advertised ending gates. Gold Ark remains a separately identified stretch result.
- The frozen playable bundle meets the existing full-closure policy. Imports retain
  bounded support claims. No inherited Beta or missing-style gap becomes complete
  through a version-number change.
- Every advertised Apple platform has physical input, accessibility, interruption,
  recovery and sustained-performance evidence for its distributed package.
- Saved attempts, progress, assistance and Hot Seat ownership survive upgrades,
  failures and supported sync paths. Handovers remain paused until Ready.
- Credits, content provenance, distribution rights, release instructions and
  maintainer handover cover the exact shipped scope.
- Signed packages, update paths, platform delivery records and release notes agree
  with the accepted source and content manifests.

These proposed criteria do not retroactively change the published 2.x
classifications or close existing gates. If full bundled closure remains distant,
continue useful 2.x releases with honest limits. Any change to the 3.0 content
commitment needs an explicit scope decision, with preserved evidence and migration
behaviour for affected players.

## Next actions and roadmap upkeep

1. Finish 2.1.2 package acceptance against its existing checklist.
2. Prepare the first-half-hour and next-day sessions on a stable candidate.
3. Keep Chronicles repair, bundled route closure and missing-style work active.
4. Record physical-device acceptance against the shared platform matrix.
5. Select optional retention/comparison work after observed access barriers are fixed.

At each milestone, update the outcome, exact evidence, remaining limits and next
dependency here. Keep detailed checks in their existing feature documents and
release records. Preserve historical results as historical, and carry evidence
forward only when the relevant source and resources remain valid.
