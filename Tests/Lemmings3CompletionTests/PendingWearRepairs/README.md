# L3 routes awaiting walking-wear repair

These four routes won against the source before the original DOS walking-wear
rule was added in `10a0d50`. They no longer pass strict replay on the current
runtime and are kept only as route seeds. They are excluded from the winning
fixture manifest. Move a route back to `Fixtures` only after accepted inputs
and a winning outcome pass two strict replays on the corrected source.

- `010.json`: first rejected input 42, Walker at tick 251.
- `021.json`: first rejected input 1, Jumper at tick 1021.
- `029.json`: first rejected input 14, Brick up-left at tick 239. A separate,
  lower-retention standalone fallback now passes strict replay in `Fixtures`;
  this older route remains a seed for improving survivor retention.
- `107.json`: first rejected input 1, Brick up-left at tick 1867.

The Egyptian 214 and 217 winning fixtures were replaced by lower-retention
strict replays after this rule change; their survivor losses still need repair.
