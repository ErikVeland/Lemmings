# Ultimate Lemmings — status and roadmap

This is a plain-language summary of the project for someone who has not read
the engineering documents. For gate-by-gate detail, see
[release scope](ReleaseScope.md), [the modern release plan](ModernReleasePlan.md)
and the [partner evaluation brief](PartnerEvaluation.md). See the [content
universe roadmap](ContentUniverseRoadmap.md) for the long-term 2D content scope.

Ultimate Lemmings is an unofficial native port of the original Lemmings games.
The release baseline is macOS. Version 1.3 added an iPhone/iPad development
target, and 2.0 is the planned mobile release. It is not affiliated with, endorsed by, or licensed by Sony Interactive
Entertainment, which holds the Lemmings rights today. See
[README.md](../README.md) and `THIRD_PARTY_NOTICES.md` for the full notice.
This document is a status summary, not a product announcement.

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

## What each release contains

| Release | Levels | Proven routes | Status |
| --- | ---: | ---: | --- |
| Lemmings | 120 | 120 | Complete |
| Oh No! More Lemmings | 100 | 100 | Complete |
| Xmas Lemmings 1991 | 4 | 4 | Complete |
| Xmas Lemmings 1992 | 4 | 4 | Complete |
| Holiday Lemmings 1993 | 32 | 32 | Complete |
| Holiday Lemmings 1994 | 32 | 32 | Complete |
| **Official Classic total** | **292** | **292** | **Complete** |
| Oh Yes! More Lemmings (conversions) | 60 | 60 | Complete |
| **Classic release total** | **352** | **352** | **Complete** |
| Lemmings 2: The Tribes | 120 | 73 | Preview |
| Lemmings 3: The Chronicles | 90 | 41 | Preview |

"Complete" means every level has a winning route, recorded once and
reproduced by the current engine on every check. "Preview" means the game
runs and is enjoyable, and its rules are not yet proven against the original
engine. Both sequels play through their full campaigns with original
artwork, music and interfaces. See [wording definitions](ReleaseScope.md#wording)
for the full distinction, including "Playable."

Beyond these eight official releases, the app also loads 6,020 Classic-format
fan levels in 535 retained packs. The full corpus has load and render evidence;
344 levels also have current winning witnesses. This corpus is separate from
NeoLemmix `.nxlv` compatibility. Real NeoLemmix fan-pack coverage remains a
1.7 gate and is not presented as completed content.

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

The official Classic campaign closed at 352/352 on 22 September 2026. The
[macOS 1.5 build 50 distribution record](ReleaseReadiness/1.5Build50Distribution.md)
records the published package and a successful update from 1.2 build 41.
The 1.6 build 51 source has [local validation](ReleaseReadiness/1.6LocalValidation.md),
but its distribution gates remain open. The 1.3 development milestone added
an iPhone and iPad target. Its source and recorded Simulator gates pass.
Physical-device, VoiceOver, thermal, signing and distribution evidence remain
open before the planned 2.0 mobile release.

## Roadmap

**1.6: finish the Mac music release.** The local candidate includes adaptive
music, optional soundtrack libraries, level skips and session changes. Verify
public library downloads, then freeze, sign, notarise and test the actual app
update. See the [1.6 validation record](ReleaseReadiness/1.6LocalValidation.md).

**1.7: close NeoLemmix compatibility.** The source recognises NeoLemmix
levels, styles and the current section-based replay format. The development
gate uses a pinned Community Edition checkout and separates import/render
failures from known unsupported mechanics. Fencer, Laserer, interactive
gadgets, zombie infection, Superlemming and native reference-replay comparison
remain open. See the [1.7 roadmap](1.7Roadmap.md).

**1.8: complete Lemmings 2 and Lemmings 3.** The remaining 96 winning routes
need proof. Both games also need engine-fidelity, campaign-progression, media
and recovery evidence. Until the 1.8 gate passes, both games remain Preview.

**2.0: finish physical iPhone and iPad acceptance.** The repository has a UIKit/Metal app
target, player-owned Classic data import, direct crowd selection, pan and zoom,
safe-area controls, interruption checkpoints and presentation-only thermal
budgets. The shared session and checkpoint boundary covers Classic, Lemmings 2
and Lemmings 3, but only Classic is player-facing mobile content. See the
[2.0 mobile roadmap](2.0Roadmap.md).

The GitHub iPhone and iPad Simulator matrix passes. The remaining gates are
physical touch, audio, background, thermal, accessibility, signing and
distribution checks. This Mac has the iOS SDK but no Simulator runtime or
connected device, so it cannot supply that evidence.

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
