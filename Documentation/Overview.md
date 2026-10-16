# Ultimate Lemmings — status and roadmap

This is a plain-language summary of the project for someone who has not read
the engineering documents. For gate-by-gate detail, see
[release scope](ReleaseScope.md), [the modern release plan](ModernReleasePlan.md)
and the [partner evaluation brief](PartnerEvaluation.md). See the [content
universe roadmap](ContentUniverseRoadmap.md) for the long-term 2D content scope.

Ultimate Lemmings is an unofficial native port of the original Lemmings games.
The release baseline is macOS. Version 1.3 added an iPhone/iPad development
target, and the separate mobile 2.0 release remains in development. Macintosh 2.0 adds original 1-bit artwork and shared control and recovery improvements. It is not affiliated with, endorsed by, or licensed by Sony Interactive
Entertainment, which holds the Lemmings rights today. See
[README.md](../README.md) and `THIRD_PARTY_NOTICES.md` for the full notice.
This document is a status summary, not a product announcement.

Public Macintosh is 2.0.3 build 86. It fixes language selection. See its
[release notes](ReleaseNotes-2.0.3-build86.md) and
[release evidence](ReleaseReadiness/2.0.3-build86/README.md).

## The proposition

The original Lemmings puzzles still work. The friction around them does not.
Imprecise clicks, no rewind, fixed speed, and no in-game help made some
levels harder to reach than to solve. This project keeps the original rules,
levels, artwork and sound, and removes that friction: precise input on
keyboard, mouse and controller, instant retry, flexible speed, and optional
hints a player can ignore.

A player can start with the original 1991 presentation and controls, or turn
on the modern defaults, without changing a single level's rules or layout.
Both paths run the same simulation and produce the same win.

## Content status

The official Classic and conversion routes pass at 352/352. L2 has routes for
all 120 levels. Its current-main replay passes against the staged build 83 app
payload, but the ark ending and original-engine comparisons remain open. The
prior L3 engine state passed all 90 routes and all three linked campaigns. The
15 October Mole direction and patrol corrections invalidated affected route
witnesses. The current audit passes 399/416 fixtures and stops at Shadow 7.
Shadow 7 and Egyptian 6, 13 and 29 lack standalone wins. Thirteen carried
schedules also fail. L3 route closure remains open. See
[release scope](ReleaseScope.md) for the current status.

The latest audit covers all 6,020 bundled fan levels. It verifies 2,403 winning
routes, records 3,599 levels without matching candidates and 18 failed replay
candidates, with no load, decode or render failures. The strict route gate has
3,617 levels without verified wins. The two “It’s a Magical World” copies
remain without winning routes. Imported packs remain open-ended. See
[release scope](ReleaseScope.md) for the closure work.
NeoLemmix uses a separate engine and its own style dependencies.

## What "modern" means here

- **Speed control.** Hold a key or the controller trigger to ramp fast-forward
  up smoothly, then release to ease back down. Tap for an instant 2×–10× step.
- **Retry without cost.** Instant retry, rewind on supported engines, and undo
  on the nuke command, so a player can recover from one wrong click.
- **Optional hints.** Three tiers per level, from a gentle nudge to opening
  moves, each gated behind a separate click so a player never sees a spoiler
  by accident. Hints match a verified route wherever one exists.
- **THE TROLLEY.** A persistent rescue analysis after every attempt, win or
  loss, comparing the player's result against the best known and the proven
  maximum. See [THE TROLLEY](TheTrolley.md).
- **Full controller support.** Xbox and PlayStation layouts, skill cycling,
  target focus, and menu navigation, alongside keyboard and mouse.
- **Accessibility controls.** Independent switches for reduced motion and
  reduced flash, without changing gameplay speed or removing original
  sprites. Text and menu scaling and initial VoiceOver support are in place.
  Full listening and controller-only journeys still need verification.
- **Period-accurate presentation choices.** DOS, Amiga, or Macintosh-style
  artwork, chosen per player and preserved between launches.
- **Replay and movie export.** Every win can be reviewed at variable speed or
  exported as a video with its original sound.
- **Saves that survive updates.** A saved run, including a paused Hot Seat
  game, now continues correctly after the app itself changes. This closed a
  real defect: an earlier build once refused every saved run after an update.

## Game Center

The app has a working GameKit integration: 181 leaderboards built from the
same rescue data that proves each level, plus career boards for total stars,
distinct clears, and three-star runs. Scores sync automatically when a
player is connected, and queue locally when they are not.

Apple does not allow Game Center under a Developer ID signature. That
signature is what lets a downloaded app run without an App Store review, so
Game Center is currently limited to a separate, development-signed build
that only runs on the two Macs registered for internal testing. Worldwide
leaderboards need an App Store release to reach every player. See
[Game Center setup](GameCenterSetup.md).

## How this gets tested

Every claim of "Complete" above is backed by a recorded, replayable route
that the current engine must reproduce exactly, not just a level that opens
without crashing. An automated audit rebuilds the engine from source, replays
every route, and checks campaign progression, saved-run recovery and app
behavior before any archive is packaged. A version numbered 1.0 or later is
mechanically refused if any required route or gate is still open. This is
what lets the release notes above be trusted rather than taken on faith.

## Where the project stands right now

Macintosh 2.0.3 build 86 is public. It fixes language selection and retains the
published classifications and limits. See the
[release notes](ReleaseNotes-2.0.3-build86.md) and
[distribution evidence](ReleaseReadiness/2.0.3-build86/README.md). Full
bundled-content closure remains open. The 2.0 source connects all three native
games and supported NeoLemmix to mobile sessions. Its signed build 12 contains
Classic only. Real-data fidelity, full package, physical-device, accessibility
and distribution gates remain open. See the [2.0 release gate](ReleaseReadiness/2.0ReleaseGate-2026-10-14.md).

## Roadmap

**1.6 and 1.7: shipped.** 1.6.0 added adaptive music, optional soundtrack
libraries, level skips and saved sessions. 1.7.0 added the bundled NeoLemmix
packs and the Oh My! All Lemmings! learning journey. 1.7.1 fixed journey sessions.

**1.7: NeoLemmix compatibility gate passed.** The pinned evidence covers 794
levels, the 160-level Redux replay corpus, source final-state comparisons and
selected live visual captures. The bundled archive audit and style-rights
inventory now cover the exact set. Build 84 indexes all 794 levels; 719 resolve
with the bundled DMA styles, while 75 still need 44 community styles. Their
rights and the full winning-route gate remain open. See the [1.7 roadmap](1.7Roadmap.md)
and [current release scope](ReleaseScope.md).

**1.8: Mac polish.** Sharper pixel rendering, NeoLemmix sound effects and
reliable music recovery after a nuke. L2/L3 remain Preview and NeoLemmix Beta.
The patch branch combines the current work. See the
[1.8.x consolidation evidence](ReleaseReadiness/1.8xConsolidation.md).

**1.9: The Tribes complete, Chronicles Beta.** L2 has preserved wins for all
120 levels and continuous runs through twelve tribes. L3 has 90 of 90 retained
standalone wins. Its three 30-level chains each finish with 50 survivors.
Original-engine fidelity, media and release-candidate checks remain open. The
update also adds original Macintosh music and counters, Hot Seat Resume rosters
and saved-run fixes.

**2.0: full iOS release for iPad, iPhone and iPhone Duo.** Source now connects
Classic, L2, L3 and supported NeoLemmix packs to mobile libraries and sessions.
Build 12 remains Classic-only. The 2.0 roadmap still has real-data, campaign,
input, recovery, accessibility, Duo, device and distribution gates open. See
the [2.0 mobile roadmap](2.0Roadmap.md).

The historical iPhone/iPad Simulator matrix covers its recorded source commit.
It does not certify the full three-game release. Final source, rendered UI,
physical touch, audio, recovery, thermal, accessibility, signing, TestFlight
and App Store checks remain open.

**Content discovery from 1.2.** The shared CoverFlow-style
level browser is implemented in source with shipped pixel artwork and one clear
primary action. Automated tests cover its typed selection, simulated input and
reduced-motion layout. Classic cards now follow the active player's progress in
each rating unless the player enables the Settings override.

The source also includes profile-owned manual playlists and editable
`Random 10` playlists. Random creation asks for one pack, while `Shuffle all`
uses an explicit fan-level pool. Seeded playlist shuffle and `Shuffle all` keep
a fixed, non-repeating order and a persistent resume position. Missing or
changed entries stay visible for removal or replacement. Playlist runs do not
advance campaign progress or enter Hot Seat, recovery, route, replay or verified
record storage.

Targeted model, storage, settings and game-flow tests cover these contracts.
Physical controller, complete VoiceOver and packaged three-engine journeys
remain open. This work belongs beside the 1.2 [content atlas and import
boundary](ContentUniverseRoadmap.md#12--content-atlas-and-import-boundary).
The fan-pack and application update paths now have source and targeted test
coverage. The release Mac must verify the signed package and the live update.

**Longer term: Windows and Linux.** The simulation core is Swift, but it
currently depends on Apple-only frameworks for graphics, image decoding and
hashing: CoreGraphics, ImageIO and CryptoKit. Reaching Windows and Linux
means replacing those dependencies and building a new interface outside
AppKit, a bigger step than the iOS work above. No work has started.

Consoles are not a current target. Switch, PlayStation and Xbox all need
platform access this project does not have, and are out of scope for now.

**Ongoing and separate from all of the above: a rights holder conversation.**
This project runs as an engineering demonstration today, not a distributed
product. A public release on any platform depends on an agreement with
Sony, the current rights holder, on scope, assets and distribution. See
the [partner evaluation brief](PartnerEvaluation.md) for what that
conversation would draw on.
