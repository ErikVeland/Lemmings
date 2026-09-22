# Ultimate Lemmings — beta 35

Version 0.1, build 35. This is a local Game Center build for the registered test
Macs. It includes Intel and Apple silicon builds and full soundtracks. These notes
list all changes since beta 34.

| Archive | Minimum macOS | Records |
| --- | --- | --- |
| UltimateLemmings-beta35-gamecenter-macOS.zip | 13.0 | Game Center; registered test Macs only |

## Changes since beta 34

### Oh No!, Xmas and Holiday rules

Oh No! More Lemmings, both Xmas releases and both Holiday releases now use the
DOS rules of those releases. Original Lemmings does not change.

- New lemmings leave a hatch one pixel further right.
- In levels with two hatches, lemmings leave the hatches in turn: A, B, A, B.
- A builder that shrugs keeps shrugging when you give it a climber.

Oh No! Havoc 20 now plays as in the original game. Lemmings from the left hatch
land on the ledges in the narrow shaft and do not fall to the bottom.

Some routes that worked in beta 34 no longer work in these levels.

### Saved runs

An update no longer stops a saved run from resuming. This includes Hot Seat games.

- A run saved in an earlier build resumes with the rules that it started with.
- New saved runs also keep the full game state. A later build can continue the
  run even when it cannot replay the saved moves exactly.
- Before this change, a build with any engine change showed **Cannot restore
  run** for every saved run. If you saw that message and did not select
  **Discard saved run**, select **Resume Saved Run** again.

### Hints and verified routes

- Verified hints and solution replays cover all 292 official Classic-family levels.
- Oh Yes! More Lemmings has verified hints and solution replays for all 60 levels:
  20 Lemmings versus levels, 10 Oh No! versus levels and 30 Mega Drive Sunsoft levels.
- Lemmings 2 and Lemmings 3 do not change.

## Install

Quit any other copy of Ultimate Lemmings. Unpack the appropriate ZIP and move
Ultimate Lemmings.app to Applications. Open the app. No additional game files are needed.

The Game Center archive has an Apple Development signature. It runs only on Macs
registered in its provisioning profile and cannot be notarised. If macOS blocks it,
clear the downloaded app's quarantine flag with:

```sh
xattr -dr com.apple.quarantine "/Applications/Ultimate Lemmings.app"
```

## What to test

- Play Oh No! Havoc 20, Havoc 5 and Wild 9. Check that the published walkthrough
  routes work.
- Play two-hatch levels in Oh No! and Holiday. Check that lemmings leave the
  hatches in turn.
- Open hints and solution replays in Oh No!, Xmas and Holiday levels. Check that
  each replay wins.
- Continue saved runs and Hot Seat games from beta 34 in all three games.
- Play Oh Yes! More Lemmings levels, and check that their hints and solution replays win.

Report build 35, the archive used, your macOS version, the level and the steps when a test fails.
Do not include account passwords or authentication codes.
