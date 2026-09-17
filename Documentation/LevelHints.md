# Level hints

Press **i**, or choose **Help > Level hints**, or press **F1** (Fn-F1 on keyboards
with brightness keys), or choose **Level hints** from the controls help. Classic also offers hints in its pause menu.
**Command-/** opens the same page from the menu bar.
On a controller, use **LT + Y**. Choose a button with the D-pad, press **A** to reveal one tier,
and press **B** to return to the game. Held buttons do not reveal hints when the page opens.

`i` is reserved for this page, so no skill uses it as a shortcut.

Hints are optional. They never appear automatically or assign skills.
The game pauses while the page is open. Closing it restores the previous pause state.

## Coverage

As of 17 September 2026, checked hints cover 281 official Classic levels through
284 distinct level identities. This includes all 120 original levels, all 32
Holiday 1993 levels, all 32 Holiday 1994 levels, both complete Xmas campaigns and
89 Oh No! levels. All three tiers come from a verified winning route.

Levels without matching checked routes receive labelled general coaching.
This includes the remaining official levels, L2, L3, conversions and fan packs,
unless a fan level exactly matches a checked original identity. General coaching
is advice about the available mechanics, not a solution for that level.

Checked hints follow preserved winning routes. The official Classic gap is now
11 Oh No! levels. Sequel and community completion have separate evidence limits.
See the [current closure work](ReleaseReadiness/OneZeroClosure-2026-09-15.md).

Each click reveals one tier:

1. **A gentle nudge** points to the kind of obstacle or crowd-control problem to consider.
2. **The approach** identifies the opening skills and skills to keep for later.
3. **Opening moves** shows the first three assignments from a winning route, with numbered locations on a cropped level map.

The final tier also shows recorded release-rate changes before each opening move.
Changes at the same simulation tick show only the final rate. Repeated rates are omitted.
These details stay hidden in the first two tiers.

Opening moves are examples. Timing, release rate and changes to the terrain can affect them.
The third tier does not reveal the complete solution. Reopening the page starts with the nudge again.
Return and repeated F1 presses do not reveal another tier.

All hint text and map numbers use the same bitmap font as the game menus.
Paragraphs and numbered steps retain their line breaks. Long hints scroll with
the mouse wheel, controller right stick, arrow keys, Page Up/Down or Home/End.
Each new tier starts at the top. Assistive tools can read the complete hint text.

Missing or stale hint data falls back to labelled general coaching.

## Source and validation

`Resources/Hints/classic.json` contains opening locations extracted from the existing winning replay witnesses.
`Tools/LevelHints/main.swift` replays each included route, checks every assignment
and compares the complete recorded outcome. Original levels use the published
rescue witnesses. Other official campaigns use the checked solution bundle.
Both legacy before-tick and live after-tick inputs retain their recorded timing.
It exports only the first three assignments, the order of skill types and the opening release-rate changes.
The app matches the initial level fingerprint and engine fingerprint before offering a checked route.
Levels with the same title or artwork cannot borrow another level's hints.

Regenerate with `Scripts/generate-level-hints.sh`. It checks the replay certificates and compiles the current simulation first.
The output is deterministic. Normal app builds copy the saved catalogue without running a solver.

Run `TEST_SCOPE=hints Scripts/run-app-integration-tests.sh` to check coverage, exact level matching,
spoiler boundaries, native keys, pause restoration, flat/CRT presentation and missing-route coaching.
The checks exercise all 744 hint tiers, verify complete text and accessible values,
and test keyboard scrolling and scroll reset with an oversized coaching page.
They also render the three tiers under `.build/hints` for visual inspection.

Run `Scripts/test-level-hint-catalogue.sh` for headless checks of all 284 decks,
release-rate ordering and the first two tiers’ spoiler boundaries.
