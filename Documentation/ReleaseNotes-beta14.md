# Ultimate Lemmings — beta 14

Version 0.1, build 14. Universal Mac app for Intel and Apple silicon, macOS 13 or later.

Beta 14 ships in two archives. Read **Which archive you have** below before you test.

## Changes since beta 13

### Worldwide rankings can now be tested

- A second archive enables Game Center. Its name ends in `-gamecenter`. On that
  build the leaderboard pages connect, submit scores and show worldwide places.
- The Developer ID archive keeps worldwide rankings off. Apple does not allow
  Game Center under a Developer ID signature. That build saves local records and
  says so on the leaderboard page.
- Worldwide scores in the Game Center archive use Apple's sandbox. They stay
  separate from production scores.

### Achievements and run details

- The collection row at the bottom of the Achievements page is now selectable.
  Click **1 Rescue**, **2 Philosophy**, **3 Rivalries** or **4 Mastery** to open
  that collection. The current collection is the bright one. The number keys and
  the arrow keys still work.
- Run details swap their two lettering colors. Values are now green and labels
  are blue, so the numbers read first.

## Which archive you have

| Archive | Worldwide rankings | First run |
| --- | --- | --- |
| `UltimateLemmings-0.1-beta14.zip` | Off. Local records only. | Opens normally. |
| `UltimateLemmings-0.1-beta14-gamecenter.zip` | On, through Game Center. | Needs the quarantine step below. |

The Game Center archive is not notarized, so macOS stops it on first run. Run this
once after you move the app to Applications:

```sh
xattr -dr com.apple.quarantine "/Applications/Ultimate Lemmings.app"
```

The Game Center archive also runs only on Macs registered for this beta. If the
app refuses to open, tell the maintainer and use the other archive.

## Tester focus

1. Upgrade from beta 13. Check profiles, progress, records and achievements.
2. On the Game Center archive, connect Game Center from a leaderboard page.
   Complete a ranked level. Check the level board and the three career boards.
3. Disconnect, improve a score offline, then reconnect. Check that the improved
   score arrives.
4. Change Game Center accounts and switch local players. Check that scores follow
   the correct player.
5. Open the Achievements page. Select each of the four collections by clicking.
   Check that the selected one is brighter and that the page resets to its first
   entry.
6. Open Run details. Check that values and labels are readable in Flat, Monitor
   and Television modes.

Report the game, rank and level, player, Mac model, macOS version, display mode
and exact steps. Preserve a replay or movie where available.

## Known limits

- This is a test beta, not a 1.0 release. The original DOS campaign has 120
  verified winning routes. Another 214 core campaign routes remain unverified,
  plus conversion gaps. Missing evidence does not prove those levels are broken.
- L2 and L3 fidelity work remains. L3 environmental effects, original movie
  soundtracks and story transitions are not complete. NeoLemmix compatibility is
  partial.
- Checkpoints do not cover classic fan imports or L2 practice. Installed-release
  migration and physical power-loss trials remain open.
- Sustained 10x performance is not established. Recent short local samples with
  replay recording reached about 6.8x to 8.7x when 10x was requested. Hardware,
  audio, accessibility and physical-controller validation remain incomplete.
- Game Center itself is newly testable and unproven. Network loss, account
  changes and offline behavior have no recorded results yet.
- The package is for private testing under the project's game-data policy. It
  does not establish rights-holder approval for public distribution.

See [beta testing](BetaTesting.md) and the repository's release gate register for details.
