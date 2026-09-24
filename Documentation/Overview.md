# Ultimate Lemmings — status and roadmap

This is a plain-language summary of the project for someone who has not read
the engineering documents. For gate-by-gate detail, see
[release scope](ReleaseScope.md), [the modern release plan](ModernReleasePlan.md)
and the [partner evaluation brief](PartnerEvaluation.md). See the [content
universe roadmap](ContentUniverseRoadmap.md) for the long-term 2D content scope.

Ultimate Lemmings is an unofficial native macOS port of the original Lemmings
games. It is not affiliated with, endorsed by, or licensed by Sony Interactive
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
1.5 gate and is not presented as completed content.

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

The official Classic campaign closed at 352/352 on 22 September 2026. The 1.0
RC1 baseline was build 36. The current 1.1 CR2 source candidate is commit
`e1a2cbb`. It includes shared target selection, rewind transport and the related
presentation work across Classic, Lemmings 2 and Lemmings 3. CR2 is not a release
claim yet. A fresh package, release audit, physical-device checks, VoiceOver
journeys and hardware/performance evidence remain open.

## Roadmap

**Now: close 1.1 CR2 on macOS.** Target selection and the shared rewind
transport are implemented across the three engines. The next work is candidate
validation and release evidence, not another large feature. See the
[QoL roadmap](../docs/superpowers/plans/2026-09-23-qol-roadmap.md).

**Next: 1.2 content discovery and sequel completion.** Build a CoverFlow-style
level browser that keeps the shipped pixel artwork and gives one clear primary
action. Add `Shuffle all` for eligible fan levels and saved playlists. A
playlist can use ten randomly selected levels or an order chosen by the player.
Preserve the source engine, pack identity and level identity in every playlist
entry so saves, replays and results remain safe. This work belongs beside the
1.2 [content atlas and import boundary](ContentUniverseRoadmap.md#12--content-atlas-and-import-boundary).

Make Lemmings 2 and Lemmings 3 completion verification a 1.2 exit gate. The
remaining 96 winning routes must close, and both games need engine-fidelity,
campaign-progression, media and recovery evidence. Until that gate passes, both
games remain Preview.

**After that: iPhone and iPad.** The simulation library already builds for
iOS and has no dependency on the Mac's window system. It still needs a touch
interface: direct crowd selection, safe-area layout, and app suspension
handling. No one has produced or tested an iOS build yet.

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
