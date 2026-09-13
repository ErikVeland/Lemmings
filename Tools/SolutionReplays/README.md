# Solution replays

Run `python3 Tools/SolutionReplays/generate.py` after the completion replay gates pass.
The generator bundles winning records from the Original and Classic Family fixture suites.
It keeps the shortest record when two levels have the same initial state.

The current bundle contains 237 distinct records for 239 verified level routes, including all 120 Original levels.
It contains inputs and expected outcomes, not level artwork or terrain.

Before offering playback, the app matches the loaded level's initial state and runs
strict replay validation on a background task. A missing, changed, failed or unfinished
record does not expose the solution button. Unverified levels retain their existing hints.

The animated player uses the same before-tick and after-tick input timing as the
strict replay player. It owns a separate simulation and does not record campaign
progress, achievements, saved attempts or Hot Seat turns.
