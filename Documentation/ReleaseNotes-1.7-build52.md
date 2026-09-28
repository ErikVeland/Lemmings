# Ultimate Lemmings 1.7 — Local test build

Build: 52
Release base: v1.6.0
Distribution: local Game Center build for the registered Macs. It is not notarized.

This is a development test of the 1.7 NeoLemmix work. NeoLemmix content stays
in Preview until the 1.7 release gates pass.

## NeoLemmix

- Choose a NeoLemmix levels folder. The level browser shows its packs in manifest
  order, with groups and levels in their original order.
- Records, previews, playlists and saved runs use stable pack and level IDs.
  Completed levels show a completion mark.
- The app does not start a level when its source files changed since the last save.
- Lemmings use the sprite style of the level theme. The app draws them in the
  NeoLemmix order and uses the eight-frame Walker cycle.
- Pickup skills show their generated skill icons.
- Teleporters and receivers, secondary gadget layers and moving backgrounds follow
  the NeoLemmix Community Edition timing rules.

## Oh My! All Lemmings!

- The all-games campaign is now a learning journey. It shows the next lesson,
  its stage and focus, and the count of solved levels.
- Pause a lesson to get hints, keep a level for later, or leave. Choose
  **Revisit** to play the levels that you kept for later.

## Controls and sound

- The selected lemming has a brighter halo and a small solid marker above its head.
  A narrow shimmer crosses the sprite. Reduced motion keeps the highlight steady.
- The Amiga sound sets use Macintosh samples for all effects that the Amiga
  bank does not have.
- Pause stops all sound effects, not only the music.
- The percussion mode finds the drums in the Jingle Bells and Rudolph tracks.

## Fixes

- The app no longer captures the pointer in a game window that is not on screen.
  A Monterey tester saw the pointer locked inside an empty rectangle after launch.

## Archive

- `UltimateLemmings-1.7-build52-local-gamecenter.zip` (1.8 GB)
- SHA-256: `9c8bbfdabc5aac3e3f00c0ebdc09e691439b57b5e06bd6e241b281a3be26b677`
