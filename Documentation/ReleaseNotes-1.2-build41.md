# Ultimate Lemmings 1.2 (build 41)

[Download the Mac app](https://github.com/ErikVeland/Lemmings/releases/download/v1.2-build41/UltimateLemmings-1.2-build41.zip)

Build: 41
Release commit: 2001bc3b05e4fec93a65a69c7aa594a9c41b1e51
Release base: b58df9c401173e94891145b19f1e8ab4025bd4e8

## Fixes

- A new installation now starts correctly. In builds 39 and 40, the game
  showed a black screen, and a menu action closed the app (issue #3).
- A click on the visible edge of a side card in the level browser now
  selects that card.
- Rescue targets show again. Builds 39 and 40 did not show them.
- Classic level hints show again. Builds 38 to 40 did not show them.
- The adaptive music keeps the opening track when a level starts. Before,
  a crossfade replaced that track almost at once.
- The Game Center variant now signs Sparkle with the app team. Before, it
  stopped at launch.

## Release checks

Each release now runs the app integration tests. It also starts each signed
app as a new user before publication. It stops when rescue proofs or level
hints do not match the game engine.

## Install and update

Build 39 and 40 installations can select **Ultimate Lemmings → Check for
Updates…** to install this build. For a new installation, expand the ZIP,
move Ultimate Lemmings.app to Applications, then open it.

Universal app for Intel and Apple silicon, macOS 12.3 or later. The public app
and all bundled Sparkle components are Developer ID signed and Apple notarised.

## Known limits

Lemmings 2 and Lemmings 3 remain previews. Known artwork-toggle and controller
sequence issues remain. With the Mac sound set, the "yippee" and "pop" events
have no sound, because the Mac disk has no sound for them. Physical Intel and
minimum-macOS testing is unverified.
