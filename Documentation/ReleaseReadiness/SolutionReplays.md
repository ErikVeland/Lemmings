# Confirmed solution replays

Classic hints now end with **Show solution replay** when a winning record passes
validation against the loaded level. The player must then choose **Show full solution**
on a separate spoiler screen. **Keep trying** receives the initial keyboard and
controller focus. Double-clicks and repeated Return presses cannot accept the prompt.

The replay uses game artwork and controls. It follows the demonstrated lemming,
marks skill assignments, and offers Play/Pause, 1×/3×/10× speed and Replay.
Space controls playback. Escape returns to hints. The live attempt stays paused
until the hints close, then returns to its previous pause state.

Playback owns a separate Classic simulation. It does not change skills, terrain,
run ownership, campaign records, achievements or Hot Seat progress.

## Coverage

The bundle contains 221 distinct winning input records covering all 120 Original
levels and 103 additional Classic-family routes. Two routes share identical
initial states and titles. This is not complete coverage of the wider Classic and
fan catalogue. Levels without a matching verified record retain their existing hints.

`Tools/SolutionReplays/generate.py` rebuilds the bundle from the completion fixtures.
The shipping asset script includes it. The app checks the initial state and the
complete expected outcome on a background task before exposing the final action.
Missing, stale, failed and unfinished records are rejected.

## Validation

The focused hints integration suite checks:

- Hint tier order, separate spoiler confirmation, cancellation and safe controller focus.
- Winning playback with legacy and live-input timing, including tick-zero release-rate input.
- Exact final simulation state, pause, 3×/10× playback and return to the paused hints.
- Unchanged live simulation, run owner, shared session and saved records.
- Rejection of changed initial states, missing outcomes and broken routes.
- All 120 existing hint decks, general coaching, keyboard help and flat/CRT presentation.

Evidence: `.build/ghost-hints/verified.log` and `.build/ghost-hints/render-verified.log`.
Screenshots: `.build/hints/solution-confirm-flat.png`,
`.build/hints/solution-playing-flat.png` and `.build/hints/solution-complete-monitor.png`.

This feature is a source change for the next packaged build. It does not update
an already distributed ZIP.
