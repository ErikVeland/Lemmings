# Interface changes

For work that changes visible UI, read `Documentation/UIPrinciples.md`.
The user requires clear icons and states without explanatory clutter.
Use familiar symbols, distinct state shapes, clear grouping and one primary
next action. Keep necessary action names and accessibility text. Do not add
sentences that repeat an icon, count, progress bar or visible result.
Verify the rendered states and their input targets before calling a UI change done.

Game UI must match the shipped pixel artwork. Read and reuse `GameControls.swift`,
`GameStoneButton` and the bitmap renderers before adding a control.
