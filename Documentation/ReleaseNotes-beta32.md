# Ultimate Lemmings — beta 32

Version 0.1, build 32. All three archives include Intel and Apple silicon builds,
full soundtracks and the same gameplay changes.

| Archive | Minimum macOS | Records |
| --- | --- | --- |
| UltimateLemmings-beta32-macOS.zip | 13.0 | Local records; notarised |
| UltimateLemmings-beta32-macOS12.zip | 12.3 Monterey | Local records; notarised |
| UltimateLemmings-beta32-gamecenter-macOS.zip | 13.0 | Game Center; registered test Macs only |

## Changes since beta 31

- Classic panel buttons use the original Amiga rock background and game-font labels.
  The speed box shows the current speed, including 1X after returning to normal.
- Completed Lemmings 2 campaign levels with survivors now save a route file.
  **Show Recorded Routes** opens the folder so testers can share routes with the organiser.
  Practice levels are excluded. Recorded seeds are checked before promotion to solution evidence.
- Lemmings 2 routes preserve ordered skill, pointer, fan, machine, chain and nuke events.
  The solver can improve recorded seeds and search with the survivors carried from the previous level.
- Improved preserved rescue routes for Cavelems, Outdoor and Polar. Nineteen carry-over
  witnesses now support continuous runs at the correct starting populations.
- Refreshed rescue certificates and hints for the current engine without lowering earlier targets.
- The Monterey archive lowers the minimum system version to macOS 12.3 for Macs such as the 2015 MacBook Pro.

## Install

Quit any other copy of Ultimate Lemmings. Unpack the appropriate ZIP and move
Ultimate Lemmings.app to Applications. Open the app. No additional game files are needed.

The Game Center archive has an Apple Development signature. It runs only on Macs
registered in its provisioning profile and cannot be notarised. If macOS blocks it,
clear the downloaded app's quarantine flag with:

```sh
xattr -dr com.apple.quarantine "/Applications/Ultimate Lemmings.app"
```

Choose the local player whose records should use Game Center, then select
**Connect Game Center** from a leaderboard page. Other players must not submit
records into that player's account.

## What to test

- Monterey testers: launch on macOS 12.3 or later, play all three engines, and check sound,
  fullscreen, speed changes, save/resume and replay export. Report the Mac model and OS version.
- Check the Classic panel at different window sizes, including Pause, Nuke, Undo Nuke and speed.
- Complete an L2 campaign level and check **Show Recorded Routes**. Send useful route files to the organiser.
- Check paused Hot Seat handovers and saved-run recovery in Classic, L2 and L3.
- Game Center testers: connect, submit a score, improve it offline, reconnect, and switch local players.

Report build 32, the archive used, your macOS version, the level and the steps when a test fails.
Do not include account passwords or authentication codes.

## Known limits

Classic has verified wins for 238 of 292 official levels. Lemmings 2 has preserved
wins for 64 of 120 levels and no complete ten-level tribe chain. Lemmings 3 has
wins for 17 of 90 levels. Solver candidates are not counted until preserved and verified.

The Monterey archive is a compatibility beta. Physical Monterey and Intel testing
remains open. Its Intel build omits the Swift runtime compatibility library because
the installed compiler supplies that library only for Apple silicon.

Live Game Center services, physical controllers, full VoiceOver navigation and
sustained performance still need tester validation. This beta does not declare
Classic 1.0 complete. Keep these archives within the private test group.
