# Precision Zoom

Classic, Lemmings 2 and Lemmings 3 use the same earned Zoom controls. They also
work in supported fan levels. The use count belongs to the active player profile.

- Press **Z** to switch 2× Zoom on or off at the cursor.
- Scroll up over the playfield to switch 2× Zoom on. Scroll down to switch it
  off. A scroll-wheel tick or one Magic Mouse or trackpad gesture can start it
  once. Scrolling down also switches off Superzoom. Scrolling up while
  Superzoom is active leaves it running and spends no Zoom use.
- Press **Shift-Z** to switch 2× Superzoom on or off at the cursor. Superzoom
  runs the simulation at 0.5× speed, even if fast-forward was selected.
- Starting either effect spends one use. Switching it off spends nothing.
  Switching from one effect to the other starts the new effect and spends its use.
- Earn one Zoom use per three no-Rewind career stars. Earn one Superzoom use per
  three distinct no-Rewind levels with a three-star result. A level contributes
  only its best result; retries do not duplicate stars.
- A manual retry returns the uses spent in that unfinished attempt. A completed
  failed run permanently spends its used Zoom and Superzoom charges. The reduced
  balance applies to the retry and later levels. New stars can add more uses.
  A completed winning run returns its spent uses on the next attempt.

The playfield shows the remaining counts and active effect. The keyboard help
has the earning rules. Comma and full stop remain backward and forward
transports; Z no longer rewinds. Controller rewind controls are unchanged.
Horizontal scrolling and Shift-scroll still pan the camera. Scrolling over
the control panel does not activate Zoom.

The ledger is saved per profile after each activation and at the end of a run.
A restored run keeps its active effect and spent uses. If the saved ledger is
unreadable, Zoom is disabled so the game does not grant extra uses. Removing a
profile also removes its ledger.

Older Lemmings 3 results did not save whether Rewind was used. This change
records that flag for new runs, but cannot reclassify existing results. Confirm
how to treat historical Lemmings 3 stars before certifying earned-use counts
for profiles with those results.

Run `zsh Scripts/run-precision-zoom-tests.sh` for the data-independent earning,
retry, failure, recovery, cursor-mapping and scroll-gesture checks. Run the app
integration variable-speed checks for keyboard routing and bullet-time. On a
data-ready Mac, verify that each game's terrain and lemmings enlarge while its
panel stays the same size, pointer selection matches the displayed target,
zoom-out holds the cursor target, wheel and touch scrolls start at most one
use per gesture, and retry and failure update the count as described above.
Check Classic in both flat and CRT modes.
