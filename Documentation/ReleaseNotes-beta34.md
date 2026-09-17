# Ultimate Lemmings — beta 34

Version 0.1, build 34. All three archives include Intel and Apple silicon builds,
full soundtracks and the same gameplay changes. Build 33 was a local build only.
These notes list all changes since beta 32.

| Archive | Minimum macOS | Records |
| --- | --- | --- |
| UltimateLemmings-beta34-macOS.zip | 13.0 | Local records; notarised |
| UltimateLemmings-beta34-macOS12.zip | 12.3 Monterey | Local records; notarised |
| UltimateLemmings-beta34-gamecenter-macOS.zip | 13.0 | Game Center; registered test Macs only |

## Changes since beta 32

### Players, saves and Hot Seat

- You can delete a player. Select the player in **Player Profiles**, select
  **Delete**, then confirm. Deletion removes that player's progress, saved runs,
  scores, records and achievements. You cannot undo it.
- Changes to initials and portraits save immediately.
- **Add player** adds a player without switching to them. The main button
  changes with the selection: **Add player**, **Play as** or **Done**.
- The Hot Seat page has **+ New player** (or press N). The new player joins the
  roster, and the page returns. With one profile, adding a player is the first step.
- A saved run that cannot be restored no longer blocks **Resume Saved Run**.
  Select **Discard saved run**. The files move to a "Set aside" folder.
- If the records file cannot be read, select **Fix records**. If it still fails,
  select **Start new records**. The unreadable files stay in the records folder.

### Gameplay and display

- A lemming walking up a slope into an exit is now saved. Before, the slope could
  lift it out of the exit before it reached the middle.
- Classic explosion countdowns use white, bold system digits again.
- Macintosh-style artwork no longer scrambles small level objects, such as the
  entrance hatch, on some displays.

### Hints and verified routes

- Verified hints cover 286 of the 292 official Classic-family levels. Oh No!
  More Lemmings has 94 of 100. Both Holiday campaigns and both Xmas demos are complete.
- Lemmings 2 has verified routes for 73 of 120 levels. Cavelems has routes for all ten levels.
- Lemmings 3 has verified routes for 41 of 90 levels.

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

- Add, rename and delete players. Check that each player keeps only their own
  progress and records, and that a deleted player's saves do not return.
- Start a new Hot Seat from one profile: add a player from the Hot Seat page,
  choose a game, and pass turns in Classic, L2 and L3.
- Quit during a level in each game, reopen, and resume.
- Walk lemmings up sloped ground into exits, and check levels with Macintosh-style artwork.
- Try the new Oh No! hints: Crazy 2, Wild 7, Wild 15, Wicked 15 and Havoc 14.
- Monterey testers: launch on macOS 12.3 or later, play all three engines, and check sound,
  fullscreen, speed changes, save/resume and replay export. Report the Mac model and OS version.
- Game Center testers: connect, submit a score, improve it offline, reconnect, and switch local players.

Report build 34, the archive used, your macOS version, the level and the steps when a test fails.
Do not include account passwords or authentication codes.
