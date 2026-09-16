# Ultimate Lemmings — beta 33

Version 0.1, build 33. All three archives include Intel and Apple silicon builds,
full soundtracks and the same gameplay changes.

| Archive | Minimum macOS | Records |
| --- | --- | --- |
| UltimateLemmings-beta33-macOS.zip | 13.0 | Local records; notarised |
| UltimateLemmings-beta33-macOS12.zip | 12.3 Monterey | Local records; notarised |
| UltimateLemmings-beta33-gamecenter-macOS.zip | 13.0 | Game Center; registered test Macs only |

## Changes since beta 32

- Fixed a Macintosh-artwork rendering bug where small, detailed level objects
  (such as the entrance hatch) could render with scrambled pixels. The level
  image's crop could land on a fractional pixel boundary and scale unevenly;
  it is now always cropped to whole level pixels. How visible this was
  depended on the display, which is why some testers saw it and others did not.
- Lemmings 2 now has verified routes for 73 of 120 levels. Cavelems chains all
  ten levels, the first tribe to do so. See
  [SeededSearch.md](Lemmings2Completion/SeededSearch.md).
- Lemmings 3 now has verified routes for 41 of 90 levels from a new beam
  solver in `Tools/Lemmings3Solver`.
- Additional Classic-family campaigns now have 130 winning replays: Oh No!
  More Lemmings 73/100, both Xmas demos 4/4, and both Holiday campaigns fully
  covered at 32/32 each.
- No runtime physics changed in `Sources/NxlvKit`. Existing Trolley
  certificates and hints stay valid.

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

- Play any level with Macintosh-style artwork enabled and confirm the entrance
  hatch and other small objects render cleanly, especially on an external or
  non-Retina display.
- Monterey testers: launch on macOS 12.3 or later, play all three engines, and check sound,
  fullscreen, speed changes, save/resume and replay export. Report the Mac model and OS version.
- Complete a Lemmings 2 campaign level and check **Show Recorded Routes**. Send useful route files to the organiser.
- Check paused Hot Seat handovers and saved-run recovery in Classic, L2 and L3.
- Game Center testers: connect, submit a score, improve it offline, reconnect, and switch local players.

Report build 33, the archive used, your macOS version, the level and the steps when a test fails.
Do not include account passwords or authentication codes.

## Known limits

Classic has verified wins for 238 of 292 official levels. Lemmings 2 has preserved
wins for 73 of 120 levels, with one complete ten-level tribe chain (Cavelems).
Lemmings 3 has wins for 41 of 90 levels. Solver candidates are not counted until
preserved and verified.

The Monterey archive is a compatibility beta. Physical Monterey and Intel testing
remains open. Its Intel build omits the Swift runtime compatibility library because
the installed compiler supplies that library only for Apple silicon.

Live Game Center services, physical controllers, full VoiceOver navigation and
sustained performance still need tester validation. This beta does not declare
Classic 1.0 complete. Keep these archives within the private test group.
