# Controller playtest follow-up

14 October 2026. These changes apply to the current shared frontend.

| Default control | Gameplay action |
| --- | --- |
| Cross / A | Select a pointed HUD control or assign the selected skill |
| Circle / B | Reset fast speed to 1×, then pause/play on the next press |
| Square / X | Reset speed to 1× |
| Triangle / Y | Nuke / undo where the engine supports it |
| Menu | Open the game menu |
| TV L2 / R2 at fast speed | Reset to 1× and consume the press |
| TV L2 / R2 at 1× | Tap to step backward / forward, hold to scrub |

A reset press cannot become a scrub while held. Release before pressing again.
At 1×, a timeline press pauses immediately. Holding for 220 ms starts the scrub.
Releasing parks the timeline. Circle resumes. Ready and interruption boundaries
still require an explicit player action. Disconnects force a planning pause
without going through the fast-speed reset action.

TV keeps a visible aim reticle over terrain and HUD controls. The skill badge
does not replace it. HUD activation follows the existing button bounds,
including scrolled skills. CRT input uses the rendered coordinate mapping.
The displayed eligible actor stays selected while inside its pick box.
Deliberate actor cycling retains an ID lock and cannot silently retarget a
missing actor. Pause and rewind keep the pointer position.

The shared mobile/TV pause page exposes Settings directly. Soundtrack libraries
and Play Insights retain the paused attempt. Mac retains its in-game Settings
command. L2/L3 have no release-rate controls. L3 has no nuke. Native sequel rewind
retains its existing reconstruction cost.

Rewind effects use captured audio with soft endpoints. Silent effects history
stays silent. The music groove runs at a gentler reverse speed, and repeated
requests retain its attack envelope. Mac sprite echoes have lower opacity.
Music history remains bounded to 12 seconds and does not seek the full song to
the simulation tick.

Competitive Versus levels, including There can be only one, are excluded from
every generated solo progression policy. Teaching Journey eligibility uses the
same rule. Saved Mac sequence queues and mobile/TV learning queues remove
competitive entries. Ownership, run identity and completion records remain
intact. A queue with no remaining solo entry has no resumable solo run.

## Validation

Mechanical checks remain offscreen and muted. The focused suites cover shared
button actions, reset precedence, held-input consumption, TV shuttle controls,
target retention, precision bounds, rewind and saved journey cleanup.

Twelve bitmap captures cover Classic/L2/L3 HUDs and pause pages. They check
visible empty/eligible/unavailable pointer states, skill bounds and direct
Settings targets at TV and compact landscape sizes. The shipping bitmap
renderers produce these captures. UIKit event delivery is a separate device check.

iOS and tvOS SDK module compilation passes. Offline recording, tracker,
Adaptive DJ and effect-buffer checks pass, including mute, suspension, bounded
repeat requests and reversed sample direction. Physical Siri Remote/controller
precision, sofa readability, audible rewind feel and live settings navigation
remain manual validation requirements.

Local logs and captures are under `.build/playtest-*`. They are not a public
release audit or distribution build.
