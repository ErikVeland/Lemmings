# Ultimate Lemmings — beta 15

Version 0.1, build 15. Universal Mac app for Intel and Apple silicon, macOS 13 or later.

## Changes since beta 14

### Hot seat

- **Shared Session** is now **Hot Seat**. The app menu item, the Player Profiles
  button and the page all use the new name.
- The main menu names everyone playing. One player shows `EKV`. A hot seat shows
  `EKV v UVA`, and so on for up to eight players.
- The level briefing names the player before the level starts. The first line
  reads `YOUR TURN` and the player's initials.
- **Pass the turn** on the Hot Seat page selects the house rule. `Every level`
  hands over after each level, won or lost. `At first fail` keeps a winner in
  their seat. `Every level` is the default, and the choice is remembered after
  you quit.
- The result page names the player who receives the Mac next, after a clear as
  well as after a loss.
- The Hot Seat page says `Return to the start menu to begin` until a second
  player joins.

### Worldwide scores belong to one profile

- Game Center ranks one person, so one local profile owns this Mac's worldwide
  place: the first profile created. Other profiles on the same Mac keep local
  records.
- The leaderboard page now names the owning profile instead of saying only that
  the account belongs to another player.
- Progress, records, statistics and achievements remain separate for every
  profile. Campaign progress in a hot seat still belongs to the host, so the
  players stay on the same level.

### Presentation

- The game opens straight into full screen. It no longer shows a window first and
  then animates, which also stops the displays redrawing at launch.
- Fast-forward no longer draws a tapering wake behind each lemming. Ghosting
  alone shows the speed. It is faint at 2x and strongest from about 5x.
- The result page uses green lettering for the rescue count, the star tallies,
  the goal verdict and the two card headings. Supporting text stays blue.

## Tester focus

1. Upgrade from beta 14. Check profiles, progress, records and achievements.
2. Start a hot seat with two or three profiles. Try both turn settings. Check the
   briefing names the right player and the main menu lists everyone.
3. Quit and reopen. The turn setting must survive. The roster must not.
4. Connect Game Center as the first profile created, then as another profile.
   Only the first profile submits. Check that the other player is told why.
5. Watch the launch. Report any window that appears before full screen, and any
   display that redraws.
6. Play at 2x, 5x and 10x in Flat, Monitor and Television modes. Report ghosting
   that is too faint to read or too strong to see through.

Report the game, rank and level, player, Mac model, macOS version, display mode
and exact steps.

## Known limits

- This is a test beta, not a 1.0 release. The original DOS campaign has 120
  verified winning routes. Another 214 core campaign routes remain unverified.
- L2 and L3 fidelity work remains. NeoLemmix compatibility is partial.
- Game Center remains newly testable. Network loss, account changes and offline
  behavior have no recorded results yet.
- Sustained 10x performance is not established.
- The package is for private testing under the project's game-data policy.

See [hot seat](HotSeat.md) and [beta testing](BetaTesting.md) for details.
