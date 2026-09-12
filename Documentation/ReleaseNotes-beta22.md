# Ultimate Lemmings — beta 22

Version 0.1, build 22. Universal Mac app for Intel and Apple silicon, macOS 13 or later.

This is the first build cut to the shape of a 1.0 release. The feature set for the
classic games is frozen. Read [Release scope](ReleaseScope.md) first. It states
exactly which games are complete, which are playable, and which are previews.

## What is complete

**Lemmings, all 120 levels.** Every level has a preserved winning replay that the
engine reproduces, 103 of them rescuing every lemming. Destructive skills follow
the original steel-probe rules. **Xmas Lemmings 1991** is complete on the same
terms.

## What is playable

Oh No! More Lemmings, Holiday 1993 and 1994, and Xmas 1992 all load, render and
run. 99 of their 168 levels have a preserved winning route. A level without one is
not broken. Nobody has recorded a win for it yet.

## The classic climb

The classic releases now form one journey instead of a list. It runs Fun, Tame,
the two Xmas sets, Tricky, Crazy, Holiday 1993, Taxing, Wild, Holiday 1994,
Mayhem, Wicked, then Havoc, which is the hardest rank either campaign offers.
Thirteen stages, 292 levels, each level once.

Release order alone would drop you from Mayhem straight back into Tame.

## While you play

- The bottom right of the panel shows where you are: rank position, rescues
  against the target, the best known result for the level, and how many lemmings
  are still to enter. It works with the original artwork as well as the
  Macintosh artwork.
- Press **i** for level goals and tiered hints. **F1** still works.
- The pause menu can quit to the main menu. The run's checkpoint stays on disk.
- **B** steps through Bomber, Blocker, Builder and Basher. **U** is the floater.
  Every skill still answers to its number.

## Hot seat

- A new hot seat starts at the first level. It keeps its own campaign, so it
  never continues or disturbs a player's solo progress.
- Opening the page selects two players for you. One player is not a hot seat.
- The briefing shows whose turn it is, with their lemming portrait, and a quiet
  badge repeats it during play.
- **Pass the turn** chooses between every level and at first fail.

## Please test

1. Play the original campaign from Fun through to Mayhem. This is the part that
   claims to be complete, so failures here matter most.
2. Check the bottom-right progress field with both artwork settings.
3. Run a hot seat with two and three players across a win and a loss.
4. Connect Game Center as the first profile created, then as another.
5. Report anything that contradicts [Release scope](ReleaseScope.md). A claim
   that is wrong is worse than a feature that is missing.

## Known limits

This is not 1.0. 69 classic and 130 sequel levels have no recorded winning route.
Physical Intel, minimum macOS, HDR, multiple displays and high refresh rates are
untested, and sustained 10x play is not established. Scalable text and VoiceOver
navigation are incomplete. Game Center is unproven against network loss and
account changes. Distribution rights for the original game data are not settled,
and that governs any public release.
