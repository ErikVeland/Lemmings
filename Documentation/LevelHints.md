# Level hints

Press **i**, or choose **Help > Level hints**, or press **F1** (Fn-F1 on keyboards
with brightness keys), or choose **Level hints** from the controls help. Classic also offers hints in its pause menu. On iOS and tvOS, Hint is the first pause action in Classic, Lemmings 2 and Lemmings 3.
**Command-/** opens the same page from the menu bar.
On a controller, use **LT + Y**. Choose a button with the D-pad, press **A** to reveal one tier,
and press **B** to return to the game. Held buttons do not reveal hints when the page opens.

`i` is reserved for this page, so no skill uses it as a shortcut.

Hints are optional. They never appear automatically or assign skills.
The game pauses while the page is open. Closing it restores the previous pause state.

## Coverage

The current catalogue contains 350 checked Classic level identities: 120 original
levels, 100 Oh No! levels, 64 Holiday levels, six Xmas levels and 60 conversion
levels. The page header says **Checked example route**. Its advice and opening
markers come from a matching verified winning route, rather than a claim that
every tier has a human-authored explanation of the puzzle.

Levels without matching checked routes use the header **General coaching**.
Every page begins **No level-specific hints available.**, followed by generic
Observe, Plan or Practise advice. The progress label says Coaching instead of
Hint. Native accessibility text and mobile/TV reading order retain this distinction.
This applies to stale or missing Classic data, unmatched fan levels and L2/L3.
General coaching does not claim a solution or add route markers. L3 coaching
discusses its tools instead of borrowing Classic skill instructions.

Checked hints follow preserved winning routes. Sequel and community completion
have separate evidence limits.
See the [current campaign closure evidence](ReleaseReadiness/CampaignClosure-2026-09-22.md).

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

The exact original Fun 1 and Fun 2 identities also have short obstacle explanations:
the route between the upper platform and lower path in Just dig!, and individual
fall protection in Only floaters can survive this. These notes are keyed to the
full level fingerprint. A matching title or changed terrain cannot borrow them.
The catalogue also requires its recorded engine fingerprint to match the packaged
engine fingerprint. Other checked decks retain their route-derived advice. No
sequel solutions or broader human review are implied.

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
The checks exercise all 1,050 checked hint tiers, verify complete text and accessible values,
and test keyboard scrolling and scroll reset with an oversized coaching page.
They also render checked tiers and generic Classic/L2/L3 pages under `.build/hints`.
Shared phone, tablet and TV layouts check complete availability text and action targets.

Run `Scripts/test-level-hint-catalogue.sh` for headless checks of all 350 decks,
release-rate ordering, the first two tiers' spoiler boundaries, explicit coaching
availability and exact-identity obstacle explanations. New copy uses English
fallback until its translations have been reviewed.
