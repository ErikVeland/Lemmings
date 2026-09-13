# Ultimate Lemmings — beta 30 Game Center

Version 0.1, build 30. Universal Mac app for Intel and Apple silicon, macOS 13 or later.
Full soundtracks are included. This private development build enables Game Center.

## Changes since beta 29

- Added full-rescue solutions for Xmas 1992 level 2 and Holiday 1993 Flurry 6, 7,
  9, 11 and 15. All four Xmas 1992 levels now have recorded wins.
- Updated the solution bundle and rescue evidence. All earlier recorded wins
  and published rescue targets remain valid.
- Added 16 Lemmings 2 carry-over witnesses. Egyptian now has a continuous run
  through eight levels. The strict gate requires twelve complete tribe runs.
- Added a Lemmings 3 level 5 winning route. It saves one lemming, loses nine and
  retains ten in reserve. Better rescue results remain open.
- Enabled the existing Game Center integration with the registered development
  profile. Leaderboard IDs and score thresholds remain unchanged.

## Install

This build runs only on Macs registered in the embedded development profile.
It has an Apple Development signature and is not notarised.

1. Quit any other copy of Ultimate Lemmings.
2. Unpack the ZIP and move Ultimate Lemmings.app to Applications.
3. Run this command in Terminal to clear the downloaded app's quarantine flag:

```sh
xattr -dr com.apple.quarantine "/Applications/Ultimate Lemmings.app"
```

4. Open the app and select the local player whose records should use Game Center.
5. Choose **Connect Game Center** from a leaderboard page.

If your Mac is not registered, send its provisioning UDID to the beta organiser
so they can update the profile and rebuild the app.

## Game Center tests

- Connect with the test account and complete a ranked level. Check the level
  board and all three career boards.
- Improve a record while offline. Reconnect and confirm that the improved score
  appears. Restart the app and check that it retains the local record.
- Change the Game Center account and reconnect. Confirm that scores follow the
  selected account and its linked local player.
- Switch local players. Other local players can view worldwide boards but must
  not submit records into the linked player's account.
- Check that failed attempts, rewind runs and changed level conditions do not
  submit ranked scores.

Report the build number, macOS version, level, local player and steps when a
test fails. Do not include account passwords or authentication codes.

## Known limits

Live sign-in, score submission, account changes and network recovery need tester
validation. The app does not upload replay movies or local initials.

Classic has verified wins for 236/292 official levels. The full retained Classic,
fan and conversion corpus has 629 wins across 6,372 identities, with no load/start
failures. L2 has 64/120 distinct wins and no complete ten-level tribe chain.
L3 has 17/90 wins. Physical hardware, accessibility and sustained performance
validation remain open. This beta does not declare Classic 1.0 complete.

Keep this build within the private test group. The notarised beta 29 archive
remains available separately with local records.
