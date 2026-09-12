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
