# Precision Zoom

Classic, Lemmings 2 and Lemmings 3 on Mac use the same free Zoom controls.
They also work in supported fan levels. Earned Superzoom uses belong to the active player profile.

- Press **Z** to switch 2× Zoom on or off at the cursor.
- Scroll up over the playfield to switch 2× Zoom on. Scroll down to switch it
  off. A scroll-wheel tick or one Magic Mouse or trackpad gesture can start it
  once. Scrolling down also switches off Superzoom. Scrolling up while
  Superzoom is active leaves it running.
- Press **Shift-Z** to switch 2× Superzoom on or off at the cursor. Superzoom
  runs the simulation at 0.5× speed, even if fast-forward was selected.
- Ordinary Zoom is available from the first attempt. Starting, stopping, retrying
  and failing never spend a Zoom use. Zoom does not change simulation speed.
- Starting Superzoom spends one use. Switching it off spends nothing.
  Switching from Zoom to Superzoom spends one Superzoom use.
- Earn one Superzoom use per three distinct no-Rewind levels with a three-star
  result. A level contributes only its best result. Retries do not duplicate credit.
- A manual retry returns Superzoom uses spent in that unfinished attempt.
  A completed failed run permanently spends its used Superzoom charges.
  New three-star levels can add more uses. A completed winning run returns its
  spent uses on the next attempt.

The playfield marks the active effect and shows Superzoom and skip counts.
Ordinary Zoom has no balance or reward receipt. The keyboard help has the
Superzoom earning rule. Comma and full stop remain backward and forward
transports; Z no longer rewinds. Controller rewind controls are unchanged.
Horizontal scrolling and Shift-scroll still pan the camera. Scrolling over
the control panel does not activate Zoom.

While zoomed, hold the cursor near any playfield edge to scroll in that
direction. Corners scroll both axes. Classic, Lemmings 2 and Lemmings 3 clamp
the camera to the visible zoomed area, so the top, bottom and side edges remain
reachable. Switching Zoom off restores the normal camera limits.

The ledger is saved per profile after each activation and at the end of a run.
A restored run keeps its active effect and spent Superzoom uses. Old ledgers
retain their Superzoom costs, current attempt and active effect. Obsolete Zoom
costs are ignored and removed when saved. If a ledger is unreadable, Superzoom
is unavailable and ordinary Zoom still works. Removing a profile removes its ledger.

iPhone, iPad and TV already provide free camera magnification through the shared
mobile frontend in all three games. Their existing Precision action selects
a closer camera view. It does not use the Mac Superzoom ledger or slow simulation.
Earned Superzoom on those platforms remains a separate parity gap.

Older Lemmings 3 results did not save whether Rewind was used. This change
records that flag for new runs, but cannot reclassify existing results. Confirm
how to treat historical Lemmings 3 stars before certifying earned-use counts
for profiles with those results.

Run `zsh Scripts/run-precision-zoom-tests.sh` for free Zoom, Superzoom earning,
retry, failure, legacy migration, cursor-mapping and scroll-gesture checks. Run the app
integration variable-speed checks for keyboard routing and bullet-time. On a
data-ready Mac, verify that each game's terrain and lemmings enlarge while its
panel stays the same size, pointer selection matches the displayed target,
zoom-out holds the cursor target, wheel and touch scrolls start at most one
action per gesture, and retry and failure preserve free Zoom and Superzoom costs.
Check Classic in both flat and CRT modes.

Cursor-camera regression checks cover anchored zoom bounds at Classic/L3 and
L2 pixel scales, Classic bitmap renders at the top and bottom, unchanged pointer
positions, and TV scrolling in all three engines. They run offscreen with muted
audio. Mac and tvOS SDK compilation pass. Physical TV input, composited CRT
output and zoomed native Mac sequel renders remain manual validation gaps.
