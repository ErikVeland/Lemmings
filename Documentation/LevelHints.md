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

Checked hints exist for the 120 original Lemmings levels. All three tiers come
from a verified winning route for that level, so they cannot send a player down a
route the engine does not accept.

Every other campaign gets labelled general coaching instead: Oh No! More Lemmings,
the Xmas and Holiday campaigns, Lemmings 2, Lemmings 3, converted levels and fan
packs. That text is honest advice about the mechanics in play. It is not derived
from a solution for the level in front of you, and it is labelled so no player
mistakes it for one.

This is a beta limitation, not a design choice. Checked hints follow recorded
winning routes, so a campaign gains them when its routes are recorded. 214 core
campaign routes remain unverified, which is the same gap the release gates track.
See the [1.0 gap evaluation](ReleaseReadiness/OneZeroGapEvaluation.md).

Each click reveals one tier:

1. **A gentle nudge** points to the kind of obstacle or crowd-control problem to consider.
2. **The approach** identifies the opening skills and skills to keep for later.
3. **Opening moves** shows the first three assignments from a winning route, with numbered locations on a cropped level map.

Opening moves are examples. Timing, release rate and changes to the terrain can affect them.
The third tier does not reveal the complete solution. Reopening the page starts with the nudge again.
Return and repeated F1 presses do not reveal another tier.

All hint text and map numbers use the same bitmap font as the game menus.
Paragraphs and numbered steps retain their line breaks. Long hints scroll with
the mouse wheel, controller right stick, arrow keys, Page Up/Down or Home/End.
Each new tier starts at the top. Assistive tools can read the complete hint text.

The bundled catalogue covers all 120 original Lemmings levels: Fun, Tricky, Taxing and Mayhem.
Other levels, including the sequels and fan levels, receive explicitly labelled general coaching.
Missing or stale hint data also falls back to coaching.

## Source and validation

`Resources/Hints/classic.json` contains opening locations extracted from the existing winning replay witnesses.
`Tools/LevelHints/main.swift` replays every original level, checks each assignment and compares the complete recorded outcome.
It exports only the first three assignments, the order of skill types and the opening release-rate changes.
The app matches the initial level fingerprint and engine fingerprint before offering a checked route.
Levels with the same title or artwork cannot borrow another level's hints.

Regenerate with `Scripts/generate-level-hints.sh`. It checks the replay certificates and compiles the current simulation first.
The output is deterministic. Normal app builds copy the saved catalogue without running a solver.

Run `TEST_SCOPE=hints Scripts/run-app-integration-tests.sh` to check coverage, exact level matching,
spoiler boundaries, native keys, pause restoration, flat/CRT presentation and missing-route coaching.
The checks exercise all 360 original hint tiers, verify complete text and accessible values,
and test keyboard scrolling and scroll reset with an oversized coaching page.
They also render the three tiers under `.build/hints` for visual inspection.
