# Ultimate Lemmings — beta 19

**Do not distribute this build.** The archive was packaged while the speed
control code was being rewritten, so its speed button behavior is not the
behavior described here and has not been verified. Wait for beta 20.

Version 0.1, build 19. Universal Mac app for Intel and Apple silicon, macOS 13 or later.

Beta 17 carries everything from betas 15 to 18, which were built but never handed
out. Read **Start a hot seat** first. A hot seat needs two players
selected, and nothing on screen changes until it does.

## Start a hot seat

1. Add every player in Player Profiles first. A hot seat cannot create profiles.
2. Return to the start menu. A hot seat cannot start from inside a level.
3. Open **Hot Seat…** from the app menu, or **Hot seat** in Player Profiles.
4. Press a number for each player who is joining. **The host alone is not a hot
   seat.** The page tells you how many players are ready.
5. Select **Done**. The hot seat starts at the next level.

The main menu then reads `EKV v UVA` instead of one set of initials. If it still
shows one, the roster did not take.

## Changes since beta 14

### Hot seat starts a new game

- A new hot seat begins at the first level. It no longer resumes wherever the
  host's own campaign had reached.
- A hot seat keeps its own campaign, separate from every solo profile. Ending it
  gives the host back their own campaign untouched. Records, statistics and
  achievements stay separate for each player, as before.
- Opening the Hot Seat page selects the host and the next profile for you. One
  player is not a hot seat.

### Keyboard

- **B** steps through Bomber, Blocker, Builder and Basher on repeated presses.
  Every skill still has its number, so 3 and B both reach Bomber.
- **Floater** is now **U**, for umbrella. Its own initial is reserved for
  fast-forward. The panel hint shows the key that works.
- **i** opens the level hints, as well as F1.
- The pause menu can **Quit to main menu**. The run's checkpoint stays on disk,
  so **File > Resume Saved Run** still finds it.

### Hot seat

- **Shared Session** is now **Hot Seat** everywhere.
- The main menu names everyone playing, for up to eight players.
- The level briefing shows the player's lemming portrait beside their initials
  before the level starts.
- A small badge in the top right of the level shows the same portrait and
  initials while you play.
- **Pass the turn** selects the house rule. `Every level` hands over after each
  level, won or lost. `At first fail` keeps a winner in their seat. `Every level`
  is the default and is remembered after you quit. The roster is not.
- After a loss: **Retry as [next initials]**. After a clear: **Retry as [your
  initials]** and **Next level: [next initials]**. A plain **Retry** always stays
  available.
- Removing the player whose turn it is no longer leaves the turn with them, and a
  roster below two players ends the hot seat instead of stranding it.
- The turn shown on screen follows the game every frame, so ending a hot seat
  during a level clears it at once.
- The Hot Seat page lays out around the number of profiles, so two players leave
  no gap and eight are not cut off.
- Everything above appears only in a hot seat. Solo play is unchanged.

### Worldwide scores

- One local profile owns this Mac's worldwide place: the first profile created.
  Other profiles keep local records, and the leaderboard page names the owner.

### Speed effects and the speed button

- Fast-forward ghosting is much stronger. The earlier change removed the bright
  wake and left the ghosts too faint to see. They now carry the effect on their
  own, visible at 2x and clearly heavier as the speed climbs.
- Mashing the button or the F key is an emergency stop. It does not flicker the
  speed on and off.

### Presentation

- The game opens straight into full screen instead of showing a window first.
- Result and run detail pages use green for values, headings and the verdict, and
  blue for supporting text.
- The achievements collection row is selectable.

## Tester focus

1. Follow **Start a hot seat** exactly. Confirm the main menu shows both sets of
   initials before you start a level.
2. Check the briefing portrait, the in-level badge and the result buttons after
   both a win and a loss.
3. During a level, open Hot Seat and select **Play solo**. The badge must clear
   at once.
4. Remove the player whose turn it is. Play must continue with a real player.
5. Play solo and confirm no portrait, badge or extra buttons appear.
6. Quit and reopen. The turn setting must survive. The roster must not.

## Known limits

- The in-level badge is on the classic playfield. Lemmings 2 and Lemmings 3 play
  in their own windows and do not show it.
- Campaign progress in a hot seat belongs to the host, so players stay on the
  same level. Records, statistics and achievements stay separate.
- This is a test beta, not a 1.0 release. 214 core campaign routes remain
  unverified. NeoLemmix compatibility is partial.
- The package is for private testing under the project's game-data policy.

See [hot seat](HotSeat.md) and [beta testing](BetaTesting.md) for details.
