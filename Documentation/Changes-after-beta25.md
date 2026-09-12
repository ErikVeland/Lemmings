# Changes after beta 25

## Hot Seat player changes

- Opening Players from results or run details now uses the same confirmation as the Hot Seat menu command. Cancelling preserves the level, attempt owner and shared session during play, briefing and results.
- Profile selection cannot silently switch an active Hot Seat to solo play. The Hot Seat button remains available through the guarded setup route.
- Returning to solo requires confirmation. Removing the second player uses the same confirmation for mouse and number-key input.
- Confirmed setup changes use the existing save-and-return path. Starting a new Hot Seat still requires its separate reset confirmation.

These changes are not included in the signed beta 25 archives.

Validation: the focused app integration suite passed, including player-change cancellation, incoming-player retries, checkpoint recovery, fan queues and Escape save recovery. Evidence: `.build/hot-seat-safety-final.log`.
