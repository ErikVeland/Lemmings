# Exact fan archive selection

13 September 2026. The fan loader passed ZIP member names directly to
`unzip -p`. Unzip interprets these arguments as wildcard patterns even when
Process launches it without a shell.

A reproducer showed that selecting `level[1].ini` read `level1.ini`.
An asterisk or question mark could concatenate several records. A literal
backslash could prevent a valid member from loading.

The loader now escapes unzip pattern characters and requires exactly one
matching member name in the archive index. This applies to level records and
pack-supplied graphics. Duplicate names are rejected, including direct reads
from saved selections. Nothing is extracted to disk.

The change does not alter engine rules, stock graphics, or saved-run schemas.
If an older save recorded a different level because of wildcard matching, the
existing fingerprint/state validation must reject that incompatible restore.
It must not silently continue the wrong level.

This is a Classic-format fan import fix. Native L2/L3 archive selection does not
use this reader and remains unchanged. Their native suites were not rerun.

## Evidence

- The pre-fix unzip reproducer is recorded under `.build/beta-exit-archive/`.
- Ten independent member names now decode to their own expected level titles.
- Duplicate members are excluded from selectable entries and direct reads fail.
- All preceding 218 Oh No!/Xmas and 64 Holiday fixture checks still pass.
- The full corpus retains all 6,395 levels, all 605 verified wins, and all
  previous initial states and statuses. The same 23 load/start failures remain.
- The nine missing-terrain failures reference pieces inside the playfield.
  They cannot be repaired by discarding offscreen placements. Their missing
  asset definitions remain unresolved.
- The completion gate still fails because 5,790 levels lack verified routes.
- The complete optimized arm64 app suite passes with beta 27 resources, including
  current/legacy fan saves, retry, interruption and Classic Hot Seat.
- The final corpus input manifest reports no drift. Core sources match the
  previously validated macOS 13 arm64 library.

Logs: `fan.log`, `app.log` and `reproducer.log`. Audit evidence:
`corpus/{levels.jsonl,coverage.json,inputs.json,input-drift.json}`,
`comparison.json` and `terrain-failures.log`.

The synthetic ZIP fixtures contain only generated text, with a deterministic
Python generator beside them. The source fix is not a new signed release.
The remaining terrain/entrance failures and wider beta-exit gates stay open.
