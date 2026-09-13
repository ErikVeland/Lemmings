# Ultimate Lemmings — beta 29

Version 0.1, build 29. Universal Mac app for Intel and Apple silicon, macOS 13 or later.
Full soundtracks are included. This build uses local records.

## Changes since beta 28

- Removed 23 empty or malformed fan levels from ten packs. All 535 packs remain, with 6,020 retained levels. Every retained level passed loading and startup checks.
- Saved fan queues skip deleted entries while preserving the active level, paused state and attempt owner. A save whose active level was deleted fails cleanly.
- Added verified winning replays for Oh No! Tame 12, 13, 18 and 20, and Holiday 1993 Flurry 2, 3 and 5. All twenty Tame levels now have recorded wins.
- Added three verified Oh Yes! conversion replays and a full-rescue replay for Xmas 1992 level 1.
- Refreshed hints and rescue targets for this engine. All earlier rescue targets remain, with five additional full-rescue certificates.
- Added Audio → Bottom Falls → Play death sound across Classic, Lemmings 2 and Lemmings 3. It defaults to on. Turning it off affects bottom deaths only. Mute, source silence and effects volume still apply.
- Classic bottom falls use the Macintosh death recording, also used as the Amiga fallback. Lemmings 2 and Lemmings 3 use their native recordings.

## Validation and limits

The retained Classic, fan and conversion corpus has 6,372 level identities and no load/start failures. Recorded winning routes cover 230 of 292 official Classic levels, 389 fan levels and three of 60 conversions: 622 wins in total. The remaining 5,750 identities lack verified winning routes. This does not mean they are impossible.

Lemmings 2 remains a preview with 64 recorded wins out of 120 levels and no verified complete ten-level tribe chain. Lemmings 3 remains a preview with 16 recorded wins out of 90 levels.

Full app journeys passed on Apple silicon and with the Intel binary under Rosetta, including saved-run recovery, input, hints and Hot Seat. Physical Intel and minimum-macOS tests, controller hardware, full VoiceOver support and sustained 10× performance remain open. This beta does not declare Classic 1.0 complete.

## Install and test

1. Unpack the ZIP.
2. Move Ultimate Lemmings.app to Applications.
3. Open the app.

Try Resume with a saved fan attempt, the new winning replays and the Bottom Falls audio option. Check that Hot Seat restores the correct player and stays paused until that player is ready.

Keep this beta within the private test group. No additional game files are needed for the bundled campaigns.
