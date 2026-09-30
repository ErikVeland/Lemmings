# Interface changes

For work that changes visible UI, read `Documentation/UIPrinciples.md`.
The user requires clear icons and states without explanatory clutter.
Use familiar symbols, distinct state shapes, clear grouping and one primary
next action. Keep necessary action names and accessibility text. Do not add
sentences that repeat an icon, count, progress bar or visible result.
Verify the rendered states and their input targets before calling a UI change done.

Game UI must match the shipped pixel artwork. Read and reuse `GameControls.swift`,
`GameStoneButton` and the bitmap renderers before adding a control.

# Cross-game parity

Treat QoL and Hot Seat behaviour as shared features across Classic, Lemmings 2
and Lemmings 3. Check all three engines when changing controls, turn ownership,
retry/continue actions, handovers, hints or saved-run navigation. Reuse shared
controls and flows. Keep handovers paused until the player is ready. Record
engine-specific limits and validation gaps instead of silently omitting support.

# Test windows

Run native UI tests through `Tools/UITestRunner/run.py`. Keep its default
offscreen mode so tests do not cover the playfield or take desktop focus.
All automated testing must stay headless and in the background while the user
tests gameplay. Mechanical tests must mute all music, sound effects, replay audio
and alert sounds. Keep the runner's default `LEMMINGS_TEST_AUDIO=muted` in every
window mode. Do not change system volume or saved game audio settings to silence
tests. Audible audio tests require a new explicit user request.
Report failures and checks that cannot run headlessly back to Codex. Do not launch test windows, switch displays, take focus or show error
dialogs. Secondary-display and foreground runs require a new explicit user
request. Do not run them automatically as a fallback.

# Transitory write-ups

Keep posts, forum threads, social media drafts and other one-off write-ups out
of the repository. Write them to `~/Documents/Ultimate Lemmings/Posts`. The
repository keeps only material that stays current: feature docs, roadmaps, the
current release notes and release evidence that a gate or roadmap cites.
