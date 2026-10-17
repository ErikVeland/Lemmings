# Ultimate Lemmings content roadmap

This document defines how Ultimate Lemmings expands beyond the current macOS
release without showing unfinished work as completed content.

## Bundled and imported scope

The owner set this boundary on 15 October 2026:

- **Bundled content is a finite commitment.** Freeze its exact levels, engine
  versions, styles, artwork, audio and other required data in a hashed release
  manifest. Every bundled engine must pass source-behaviour checks for its
  advertised rules. Every bundled level must load, render, run and have a
  verified winning replay. Campaign transitions, endings, saves and media that
  the release presents must also pass their gates.
- **Imported content remains open-ended.** The project does not promise support
  for every existing or future pack. Each import must identify its source engine
  and version, then report the highest gate it passes. Unknown or unsupported
  features must not become a universal-compatibility claim.
- A bundled item with an open gate remains a closure task. A content item does
  not meet this policy because it only loads, renders or starts.
- Distribution rights and complete source data are release gates. A required
  style, asset or dependency that is not available in the bundle leaves that
  content outside the ready set.

The compatibility vocabulary below still applies to imported content. Bundled
content must pass every gate through **Complete** before the release can claim
full support for it.

## User-facing content rule

The main game library shows content with a clear status and its known limits.
Bundled content must pass the full closure rule above. Imported content can
remain Playable, Preview or Beta when the app states what it supports.

- **Complete** content has a verified winning route for every advertised level.
- **Playable** imported content loads, renders and runs, but does not claim full
  route coverage. Its limits must be clear.
- **Preview** content carries an explicit early-development label.
- **Beta** content carries its testing label in the library and records its
  remaining compatibility and campaign limits. L3 uses Beta in 1.9.
- **Unverified** content does not appear in the normal library. It can remain
  available through an explicit import or developer test path.

The application must not present an unverified imported engine as a completed
release. It must show the source engine, content status and known limits before
play.

For imported NeoLemmix packs, keep every indexed level visible in the library.
Show the existing style-resolution error when a level cannot load because its
required style is missing. Count a level as runnable only when its style
dependencies resolve; do not treat visibility as compatibility.

## Release goals

### 1.1 — Mac three-engine reference release

Keep Classic, Lemmings 2 and Lemmings 3 in one macOS application.

- Classic remains the completed reference engine.
- Lemmings 2 and Lemmings 3 remain clearly labelled Preview engines.
- All three engines share targeting, input, pause, retry, recovery and save
  behaviour where their rules allow it.
- The first 1.1 beta gets a new readiness record. It must not reuse 1.0
  evidence as proof of the new build.

### 1.2 — Content atlas and import boundary

Create a machine-readable catalogue for every supported or investigated pack.
Each record should include:

- source engine and version;
- file format and pack structure;
- level, graphics, audio and replay dependencies;
- licence and redistribution status;
- import, render, run, replay and completion evidence;
- known conversion loss or rule differences.

The catalogue must distinguish Classic fan levels from NeoLemmix levels. A
level format alone must not decide which physics engine runs the level.

Add the player-facing content browser in the same milestone:

- Use a CoverFlow-style carousel with the selected pack or level in the centre,
  shipped pixel artwork, a clear focus state and one primary start action.
- Keep the browser usable with mouse, keyboard, controller and VoiceOver. Add a
  list or grid path when reduced motion is enabled.
- Add `Shuffle all` for eligible fan levels. Do not mix unverified content into
  the normal library, and do not repeat a level until the selected pool is
  exhausted unless the player starts a new shuffle.
- Let the player create a playlist from ten random eligible levels or from a
  manually selected and ordered set of levels.
- Store the source engine, pack identity, level identity and catalogue revision
  in each playlist entry. Reject or repair entries that no longer resolve.
- Keep playlist progress separate from campaign progress, Hot Seat ownership,
  saved attempts, replays and verified completion records.
- Check for new compatible fan packs in the background at launch. Rate-limit
  sequential requests, validate each archive and readable level before install,
  and never replace an installed pack or change a running game.
- Show the update result in the fan-pack browser. Keep installed packs and
  progress available offline, and retry an unavailable check on a later launch.
- Limit automatic updates to supported releases in the Lemmings Level Database.
  Do not fetch forum attachments or install engine and graphics dependencies.
- Add automated application updates for supported macOS builds. Check a signed
  release feed in the background, verify the package and platform before install,
  and show release notes before the player accepts an update.
- Let the player defer an update and never interrupt a running game. Keep a
  manual download path for offline use or when an update check is unavailable.

Current source status:

- The fresh 16 October current-main strict audit verifies 2,403 of 6,020 bundled
  Classic fan routes across 535 packs. It records 3,599 levels without a matching
  candidate, 18 failed replays, zero load/decode/render failures and no input
  drift. The fingerprinted “the last mohilem” replay passes twice; 3,617 bundled
  routes remain unverified. Imported content stays open-ended. The source base
  and input hashes are retained. A five-minute current-main search on “Mission at
  max-fall 60” found no route after 600,630 expansions; the complete single-skill
  sweep found no win in 7,727 assignments. See the [audit record](ReleaseReadiness/2.0-build83/classic-fan-current-main-audit-reconciled-2026-10-16/audit.json)
  and [targeted search](ReleaseReadiness/2.0-build83/classic-fan-mission-max-fall-60-search-2026-10-16.json).
- The current-main audit adds static fingerprints to all 6,020 level rows and
  identity-pinned replay witnesses for all 2,755 winning routes (352 official,
  2,403 fan). Each witness passed two strict deterministic replays; coverage
  checks its state hash and level fingerprint against the row. It records
  5,461 distinct fan fingerprints, 18 failed fan replays, 3,599 fan levels
  without a candidate, and no input drift. The 3,617 missing fan wins remain
  open. Imported levels remain open-ended. See the [fingerprinted audit](ReleaseReadiness/2.0-build83/classic-fan-fingerprinted-audit-2026-10-16/audit.json)
  and [winning replay witnesses](ReleaseReadiness/2.0-build83/classic-fan-fingerprinted-audit-2026-10-16/fingerprinted-winning-replays.jsonl).
- Current main `b0db98cf` replays all 615 Trolley rescue configurations across
  562 bundled campaign identities. The fresh audit confirms every recorded
  level condition, status, best-save result and witness. It retains 294 exact
  population proofs and 315 rescue records; six configurations remain unknown.
  These records cover campaign rescue evidence. They do not close Classic fan
  routes or prove source-engine fidelity. See the [Trolley audit](TrolleyVerification/audit.json)
  and [current-main reconciliation](ReleaseReadiness/2.0-build83/current-main-sync-reconciliation-2026-10-17.json).
- Current main `b92386eb` fixes Classic rewind replay export to retain the
  starting level fingerprint after terrain edits. The focused rewind suite
  passes, including a digger replay. It used installed 1.9.1 build 76 data; it
  does not certify the prepared build 87 package. See the [current-main
  reconciliation](ReleaseReadiness/2.0-build83/current-main-sync-reconciliation-2026-10-17.json).
- A 17 October 8,192-beam search tried three previously unattempted exact fan
  identities. Two full 60-second searches found no candidate win. The third
  stopped after six candidates and does not support a route conclusion. No
  route status changed. See the [untried-level search record](ReleaseReadiness/2.0-build83/classic-fan-current-main-untried-search-2026-10-17.json).
- Classic level cards follow the active player's progress within each rating.
  Each rating starts with its first level available. A saved Settings option can
  unlock all Classic cards without changing campaign progress.
- The active player profile owns its saved playlists and active sequence.
  Manual playlists preserve their chosen order. `Random 10` asks for one pack
  and saves up to ten distinct eligible levels from that pack.
- A playlist can run in manual order or use a stable seeded shuffle.
  `Shuffle all` shows its fan-level pool before play and stores one
  non-repeating order.
- The active sequence stores its fixed entries and current position for resume.
  Playlist play does not advance campaign or fan-pack progress and does not
  write Hot Seat, recovery, route, replay or verified record state.
- Missing and changed entries keep their saved names and appear as invalid.
  The player can remove or replace them instead of receiving a substitute.

The current source includes the browser, playlist storage, background fan-pack
checks and application update path. Targeted tests cover these features.
The content atlas still needs the complete supported-pack catalogue. A signed
package, physical controller use and a complete VoiceOver journey still need
validation on the release Mac.

### 1.7 — NeoLemmix compatibility

Target NeoLemmix 12.14 data and replay compatibility, plus the current
NeoLemmix Community Edition contract.

The gate requires real packs and reference replays, not synthetic fixtures
only. It includes styles, lemming sprites, all standard skills, terrain masks,
gadgets, special effects, zombies, Superlemming, pack progress and recovery.

The pinned 1.7 runnable gate passed for its 794-level corpus. Macintosh 2.0.2
build 85 passes the bundled-resource check for all 794 indexed levels, with all
719 levels supported by the 26 bundled DMA styles resolving. The 75 remaining
levels need 44 community styles, and exact-version winning replay evidence
covers 158 levels. Build 85 includes the staging fix that adds the existing
Xmas group to the Original parent index; its check passes the 794/719 count and
resolves every counted ready level. The published 2.0.3 build 86 records no
non-localisation resource-index differences from build 85 and retains the same
shared engine libraries. Its complete app audit was not rerun. No additional
community styles are distributed, so the 75 style dependencies and their
rights remain open. Keep all 794 levels in bundled closure scope. Obtain
permission for those styles before adding them to the package, then audit all
bundled routes and source rules. See the [2.0.3 release evidence](ReleaseReadiness/2.0.3-build86/README.md),
[build 85 release evidence](ReleaseReadiness/2.0.2-build85/README.md),
[build 84 content inventory](ReleaseReadiness/2.0.1-build84/neo-content.json),
[archive audit](ReleaseReadiness/2.0-build83/neolemmix-bundle-audit.json),
[style rights inventory](ReleaseReadiness/2.0-build83/neolemmix-style-rights-inventory.json)
and [release scope](ReleaseScope.md).

The executable development plan is in the [1.7 NeoLemmix roadmap](1.7Roadmap.md).
The source gate uses NeoLemmix Community Edition 1.2.0 at a pinned commit. It
checks real packs, reference replays, final state, visual captures, recovery and
player-facing progress. See the [1.7 evidence](ReleaseReadiness/1.7NeoLemmixPreparation.md).

### 1.8 — Mac polish

The 1.8 Mac polish work is historical. Its distribution checks do not replace
the bundled engine-closure gates adopted in October 2026.

### 1.9 — The Tribes complete, Chronicles Beta

The owner approved L2 Complete and L3 Beta on 10 October 2026. L2 has all 120
winning routes and twelve continuous tribe chains. The prior L3 engine state
passed all 90 standalone wins and three 50-survivor chains. The 15 October Mole
direction and patrol corrections invalidated affected standalone and carried
witnesses. The strict route gate stops at Shadow 7. Original-engine parity,
route repair, media and release checks remain open. See the
[1.9 milestone evidence](ReleaseReadiness/1.9Milestone.md).

The 16 October current-main L2 replay passes all 120 routes, 70 carry-over
variants, twelve chains and event checks against the exact staged build 83 app
payload. Each tribe still ends with one survivor and a Bronze talisman. The
golden talisman, 30-survivor ark condition and original-engine comparison remain
open. Follow-up searches found no Cavelems Level 6 route from population 10 or
13. They reproduced the current Level 5 route at 10/13 and Classic Level 2 at
13/60. The accepted chains did not change. These bounded searches do not prove
that better routes are impossible. See the [current-main follow-up record](Lemmings2Completion/ark-reconnection-search-2026-10-16-current-main.json).

On 16 October, a current-main unseeded Cavelems Level 2 search at population 59
found no win after 1,033,283 expansions. A wider 16,384-beam continuation from
the accepted 36-of-59 route replayed that same route twice after 1,393,376
expansions. The chain remains unchanged, with one survivor at the ark, so the
30-survivor Gold ending remains open. See the [Cavelems Level 2 search record](Lemmings2Completion/cavelem02-current-main-ark-route-searches-2026-10-16.json).

The L2 solver now offers every triggered lemming at a decision point; a
regression checks six simultaneous actors. A current-main 16,384-beam
continuation still replayed the same 36-of-59 route twice. See the [all-actor
follow-up](Lemmings2Completion/cavelem02-all-actor-followup-search-2026-10-16.json).

A temporary exact-population Cavelems chain replayed improved Level 3–5 routes
twice each and carried ten survivors to Level 6. Two current all-actor
searches at population ten, one seeded from the accepted Level 6 route,
found no win after 747,437 and 876,791 expansions. Two further 600-second
all-actor searches at population 13, one seeded, found no win after
1,291,693 and 1,463,726 expansions. The accepted twelve-chain baseline
remains intact; this alternate path stops at 5/10. These bounded searches
do not prove the level impossible. See the [candidate chain
reconciliation](Lemmings2Completion/cavelem-candidate-chain-reconciliation-2026-10-16.json).

The 15 October L3 Mole direction and patrol corrections match captured starting
directions and no-input patrols. Main `183bc8a8` includes the explicit-steel
contact change in the Mole excavation implementation. Its runtime suite passes.
Production traces match 139/329 left-facing and 140/344 air-gap positions. The source fall after tick
167 and two of four tunnel-edge checks remain unmatched.

The current-main audit at `183bc8a8` checks 416 fixtures: 399 exact double
replays, zero stale-identity wins and 17 schedules that do not win (four standalone, 13
carried). Six level-113 expected state hashes match current source. The strict
gate passes 322 manifest and negative checks, then fails at standalone Shadow 7
and carried fixture 107-1. The Mole mask, built-brick trigger and full rules
remain open. The Mole change does not close these route gaps. Three bounded
Shadow 7 searches before the steel-contact change found no route. They do not
validate current main. See the [historical search record](ReleaseReadiness/L3MoleVerification-2026-10-15/current-head-shadow07-currentmole-search-2026-10-17.json), [current-main fixture audit](ReleaseReadiness/L3MoleVerification-2026-10-15/current-head-fixture-audit-183bc8a8.json), [current-main Mole record](ReleaseReadiness/L3MoleVerification-2026-10-15/current-main-steel-contact-183bc8a8-2026-10-17.json), [left-facing trace](ReleaseReadiness/L3MoleVerification-2026-10-15/current-main-steel-contact-left-facing-trace-2026-10-17.json) and [air-gap trace](ReleaseReadiness/L3MoleVerification-2026-10-15/current-main-steel-contact-air-gap-trace-2026-10-17.json).

Three wider current-main searches used a 4,096 beam and a 4-pixel tool-site
grid. Egyptian 13 expanded 3,889,087 candidates, Egyptian 6 expanded
5,181,833, and seeded Egyptian 29 expanded 3,620,601. None found a route.
The latest `aa21fa0e` commit changes trace evidence and its verifier, not the
runtime. The advertised macOS 2.0.4 build 87 still lacks accepted-package
evidence; the latest retained acceptance record is build 86. Imported content
remains open-ended and is excluded from bundled closure counts. See the
[bundled-scope reconciliation](ReleaseReadiness/bundled-scope-reconciliation-2026-10-17.json)
and [wider route searches](ReleaseReadiness/L3MoleVerification-2026-10-15/current-main-wide-route-searches-2026-10-16.json).
Continue the separate validation work:

- compare native rules, movement, tools, traps and input cadence with the
  original DOS engines;
- prove L2's golden-talisman ark ending with at least 30 survivors per tribe,
  and L3's three complete campaigns with at least 50 final survivors;
- close environmental effects, original movie audio and story transitions;
- keep recovery, replay identity and result records validated against the
  actual release candidate.

Winning-route completion does not close source-engine parity or the L2 ending.
The current release labels do not certify those outstanding claims.

### 2.0 — full iOS release

Ship Classic, Lemmings 2 and Lemmings 3 on iPad, iPhone and iPhone Duo.
Add mobile sequel content loading, original rendering, campaign progression,
audio, controller input, shared QoL and paused Hot Seat handovers. Complete
adaptive UI, physical-device, accessibility, performance, signing, TestFlight
and App Store gates. The 1.3 Classic-only source milestone and Simulator checks
are development evidence, not 2.0 acceptance.
See the [2.0 iOS release roadmap](2.0Roadmap.md).

### Later — wider 2D content

Add separate compatibility lanes for:

- DOS and Lemmix variants not covered by the Classic corpus;
- Lemmini and SuperLemmini content;
- historical Amiga, Macintosh, Genesis and SNES content;
- Lix levels and multiplayer as a separate engine family;
- other documented 2D engines and archives discovered by the content atlas.

The project should preserve each source engine's rules. It must not convert all
content into Classic rules and call the result universal compatibility.

## Compatibility vocabulary

Every engine and pack uses these gates in order:

1. **Recognised** — the application identifies the format.
2. **Imported** — the parser retains the required data.
3. **Rendered** — terrain, objects, sprites and masks are available.
4. **Runnable** — the engine starts and accepts input.
5. **Replay-compatible** — reference replays reproduce the result.
6. **Behaviour-compatible** — rules match the source engine within the agreed
   tolerance.
7. **Complete** — every advertised level has verified completion evidence.

Passing an earlier gate does not imply that a later gate passed.

## External map

The research baseline should include the Lemmings Level Database, the Lemmings
Forums pack and fangame lists, the Lemmings Universe archive, NeoLemmix and
Community Edition source, SuperLemmini tools, Lemmix source, and Lix source.
Use these sources as format and behaviour references. Review their licences
before copying code, assets or content.

## Exclusions

Three-dimensional games, console-only services and unlicensed commercial
content are not silently included in the 2D compatibility claim. The catalogue
can record them as investigated or excluded items with a reason.
