# Changes after beta 25

## Hot Seat player changes

- Opening Players from results or run details now uses the same confirmation as the Hot Seat menu command. Cancelling preserves the level, attempt owner and shared session during play, briefing and results.
- Profile selection cannot silently switch an active Hot Seat to solo play. The Hot Seat button remains available through the guarded setup route.
- Returning to solo requires confirmation. Removing the second player uses the same confirmation for mouse and number-key input.
- Confirmed setup changes use the existing save-and-return path. Starting a new Hot Seat still requires its separate reset confirmation.

These changes are not included in the signed beta 25 archives.

Validation: the focused app integration suite passed, including player-change cancellation, incoming-player retries, checkpoint recovery, fan queues and Escape save recovery. Evidence: `.build/hot-seat-safety-final.log`.

## Resume from the main screen

- Resume is the first selected main-screen row when the current solo player or Hot Seat has a saved attempt. Click it or press Enter to return directly to the paused level.
- The row names the player who owns the attempt. Solo saves and shared-session saves remain separate.
- Main-screen resume removes the restore confirmation and success popup. Starting the app leaves the Resume action visible instead of opening a restore dialog.
- Exiting before the first simulation tick now saves the attempt. Classic briefings are also saved when leaving for the library.
- New Classic checkpoints preserve Full Quest mode when restored. Older checkpoints remain readable.
- The rendered main screen was inspected. File recovery checks passed, including backups, stale writers and future-version protection.

Resume validation passed in `.build/resume-safety-final.log`: one-action solo resume, Full Quest retention, a zero-tick UVA Hot Seat attempt, paused restoration and solo/shared isolation. Screenshot: `.build/resume-main-screen.png`.
