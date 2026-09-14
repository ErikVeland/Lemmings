# Ultimate Lemmings — beta 31

Version 0.1, build 31. Universal Mac app for Intel and Apple silicon, macOS 13 or later.
Full soundtracks are included.

Beta 31 comes as two archives with the same game:

- **UltimateLemmings-0.1-beta31.zip** is notarised. It runs on any Mac and uses local records.
- **UltimateLemmings-0.1-beta31-gamecenter.zip** enables Game Center. It runs only on the Macs registered in its development profile.

## New in beta 31

- The Classic Pause and Nuke buttons now show the original Amiga panel artwork. Pause shows paw prints and Nuke shows an explosion. Resume remains a play triangle. A Nuke you can still undo remains an undo arrow.
- Added full-rescue solutions for Oh No! Crazy 4 and Crazy 7. Both levels now offer solution playback, and both are certified rescue targets.
- Refreshed rescue targets and checked hints for this engine. No earlier rescue target or hint changed.

## Also new if you last tested beta 29

Beta 30 went only to Game Center testers. If you use the notarised build, these changes are new to you as well:

- Added full-rescue solutions for Xmas 1992 level 2 and Holiday 1993 Flurry 6, 7, 9, 11 and 15. All four Xmas 1992 levels now have recorded wins.
- Added 16 Lemmings 2 carry-over routes. Each starts with the lemmings saved on the level before it. Egyptian now plays continuously through eight levels.
- Added a Lemmings 3 level 5 winning route. It saves one lemming, loses nine and keeps ten in reserve.

## Install the notarised build

1. Quit any other copy of Ultimate Lemmings.
2. Unpack the ZIP and move Ultimate Lemmings.app to Applications.
3. Open the app.

## Install the Game Center build

This build has an Apple Development signature and is not notarised.

1. Quit any other copy of Ultimate Lemmings.
2. Unpack the ZIP and move Ultimate Lemmings.app to Applications.
3. Run this command in Terminal to clear the downloaded app's quarantine flag:

```sh
xattr -dr com.apple.quarantine "/Applications/Ultimate Lemmings.app"
```

4. Open the app and select the local player whose records should use Game Center.
5. Choose **Connect Game Center** from a leaderboard page.

If your Mac is not registered, send its provisioning UDID to the beta organiser. The organiser can then update the profile and rebuild the app.

## What to test

- Pause and resume a Classic level from the panel. Check that the paw and explosion buttons look right at your window size. Check that a double-click on Nuke still works and that you can undo it.
- Play back the Crazy 4 and Crazy 7 solutions from Oh No!.
- Game Center build only: connect with the test account and complete a ranked level. Check the level board and all three career boards.
- Game Center build only: improve a record while offline, then reconnect and confirm the improved score appears.
- Game Center build only: switch local players. Other local players can view worldwide boards but must not submit records into the linked player's account.

Report the build number, which archive you used, your macOS version, the level and the steps when a test fails. Do not include account passwords or authentication codes.

## Known limits

Classic has verified wins for 238 of 292 official levels. Lemmings 2 remains a preview with wins for 64 of 120 levels and no complete ten-level tribe run. Lemmings 3 remains a preview with wins for 17 of 90 levels.

The Pause and Nuke artwork uses a palette matched to a reference image. It is not a recovered original hardware palette.

Live Game Center sign-in, score submission and account changes still need tester validation. Physical Intel and minimum macOS hardware, controller hardware, full VoiceOver support and sustained 10× performance remain untested. This beta does not declare Classic 1.0 complete.

Keep both archives within the private test group. No additional game files are needed for the bundled campaigns.
