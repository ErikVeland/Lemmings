# Ultimate Lemmings — beta 36 (RC1)

Version 0.1, build 36. Release Candidate 1: the first build since beta 32 built
for real, physical hardware testing rather than the developer's own Macs. All
three archives include Intel and Apple silicon builds and full soundtracks.
Builds 33 and 35 were local-only and build 34 did not reach testers, so these
notes list every change since beta 32.

| Archive | Minimum macOS | Records |
| --- | --- | --- |
| UltimateLemmings-beta36-macOS.zip | 13.0 | Local records; notarised |
| UltimateLemmings-beta36-macOS12.zip | 12.3 Monterey | Local records; notarised |
| UltimateLemmings-beta36-gamecenter-macOS.zip | 13.0 | Game Center; registered test Macs only |

## Changes since beta 32

### Official Classic campaign

- The official Classic campaign is complete: all 292 official levels (Lemmings,
  Oh No! More Lemmings, both Xmas releases, both Holiday releases) have
  verified winning routes, up from 238/292 at beta 32.
- All 60 Oh Yes! More Lemmings conversions (Amiga versus and Mega Drive Sunsoft
  levels) now have verified winning routes.
- Oh No!, Xmas and Holiday now run the later DOS rules for those releases: new
  lemmings leave a hatch one pixel further right, two-hatch levels alternate
  hatches in turn (A, B, A, B), and a shrugging builder keeps shrugging when
  given a climber. Original Lemmings is unchanged. Some routes that worked in
  earlier betas no longer work in these levels under the corrected rules.
- Fan levels no longer need a winning route for Classic 1.0; they must load,
  render and start. All 6,020 retained fan levels do.
- Hints and solution replays cover all 292 official levels and all 60
  conversions.

### Sequel progress (preview only)

- Lemmings 2 has verified routes for 73 of 120 levels, including the first
  complete ten-level tribe chain (Cavelems).
- Lemmings 3 has verified routes for 41 of 90 levels, from a new solver in
  `Tools/Lemmings3Solver`.
- No sequel engine physics changed. Both games remain preview status pending
  wider original-engine comparison.

### Saved runs and Hot Seat

- A saved run no longer breaks when a later build changes the engine. Restore
  no longer depends on matching the whole-engine fingerprint: it replays under
  the current rules, then the rules the run started with, then continues from
  the saved engine state. This includes Hot Seat games. If an earlier build
  showed **Cannot restore run**, retry **Resume Saved Run** on this build
  instead of discarding it.
- You can delete a player. Deletion removes that player's progress, saved
  runs, scores, records and achievements, and cannot be undone.
- Changes to a player's initials and portrait save immediately.
- **Add player** adds a player without switching to them.
- The Hot Seat page has **+ New player** (or press N).
- A saved run that cannot be restored no longer blocks **Resume Saved Run**;
  select **Discard saved run** instead. Discarded files move to a "Set aside"
  folder rather than being deleted outright.
- If the records file cannot be read, select **Fix records**, or **Start new
  records** if that still fails. The unreadable file stays in the records
  folder.

### Gameplay and display fixes

- A lemming walking up a slope into an exit is now saved; before, the slope
  could lift it out of the exit before it reached the middle.
- Classic explosion countdown digits are white and bold again.
- Macintosh-style artwork no longer scrambles small level objects, such as the
  entrance hatch, on some displays.
- Oh No! Havoc 20 now plays as in the original game: lemmings from the left
  hatch land on the ledges in the narrow shaft instead of falling to the
  bottom.

## Install

Quit any other copy of Ultimate Lemmings. Unpack the appropriate ZIP and move
Ultimate Lemmings.app to Applications. Open the app. No additional game files
are needed.

The Game Center archive has an Apple Development signature. It runs only on
Macs registered in its provisioning profile and cannot be notarised. If macOS
blocks it, clear the downloaded app's quarantine flag with:

```sh
xattr -dr com.apple.quarantine "/Applications/Ultimate Lemmings.app"
```

Choose the local player whose records should use Game Center, then select
**Connect Game Center** from a leaderboard page. Other players must not submit
records into that player's account.

## What to test

This is a real-device candidate: report your exact Mac model, macOS version,
and whether it is Intel or Apple silicon on every report.

- Update from a beta 32 install and confirm your saved runs, Hot Seat games and
  records carry forward without a **Cannot restore run** error.
- Play any level with Macintosh-style artwork enabled and confirm the entrance
  hatch and other small objects render cleanly, especially on an external or
  non-Retina display.
- Play Oh No! Havoc 20, Havoc 5 and Wild 9, and any two-hatch Oh No! or Holiday
  level. Check that lemmings leave hatches in alternating turn.
- Open hints and solution replays in Oh No!, Xmas and Holiday levels, and in
  Oh Yes! More Lemmings conversions. Check that each replay wins.
- Add, rename and delete players. Confirm each player keeps only their own
  progress and records, and a deleted player's saves do not return.
- Monterey testers: launch on macOS 12.3 or later, play all three engines, and
  check sound, fullscreen, speed changes, save/resume and replay export.
- Game Center testers: connect, submit a score, improve it offline, reconnect,
  and switch local players.
- Report frame pacing and stability during long or fast-forwarded sessions,
  particularly on Intel hardware.

Report build 36, the archive used, your macOS version, Mac model, the game and
level, and the steps when a test fails. Do not include account passwords or
authentication codes.

## Known limits

Lemmings 2 has preserved wins for 73 of 120 levels and Lemmings 3 for 41 of 90;
both remain preview status. Physical Intel, minimum macOS, HDR, multiple
displays and sustained performance are what this candidate exists to test —
they are not yet established. Live Game Center services under network loss,
full VoiceOver listening journeys and physical controller journeys still need
tester validation. This build does not declare Classic 1.0 complete. Keep
these archives within the private test group.
