# UI clarity

The user's requirement: icons and states must make sense without explanatory
sentences. Apply this to new UI and changes to existing UI.

- Use the game's bitmap artwork and pixel controls throughout game pages and HUDs.
  Menu lettering must not depend on the selected level graphics.
  Do not mix system fonts, SF Symbols, rounded Aqua controls or modern gradients
  into game artwork. AppKit can supply input and accessibility beneath game rendering.
- Show each outcome once. A filled star already communicates an earned goal.
- Use familiar action symbols. Pause changes to Play. A reversible action changes
  to Undo. Do not leave a destructive symbol on a button that now undoes it.
- Distinguish state through shape as well as colour. Earned stars are filled;
  unearned stars are outlined. An unknown target uses a question mark.
- Keep one primary action per screen. Give it a stronger outline and a directional
  marker. Selection has an underline; keyboard focus has its own outline.
- Keep quantities and player identity visible. They explain the current situation.
- Keep concise names for actions without a familiar symbol. Do not replace a clear
  action name with an invented icon or an initial.
- Put criteria, records, award descriptions and instructions on their relevant
  detail/help pages. Do not repeat them below the main outcome.
- Checkbox text and box form one input target. Clicking either toggles the control.
  Menu gaps and disabled controls must never pass clicks to the underlying screen.
- Preserve accessible names and keyboard help. Visible captions should not be
  needed to explain a familiar icon, and images must not exclude screen-reader users.
- Inspect actual renders for success, partial success, failure, active, inactive,
  selected, focused and unavailable states. Check mouse and keyboard hit regions
  after changing layout. A successful compile does not establish usability.

The shared result panel and Classic HUD now apply these rules. The changes cover
star states, compact result layout, primary/selected actions, transport icon
changes and concise skill names beneath HUD counts. This is not a claim that every
sequel screen or every novice-player journey has been validated.

Assignment feedback follows the engine's actual eligibility rules. Grey means no lemming is under the pointer; yellow means the lemming cannot
accept the selected skill; green means the nearest target can accept the selected skill.
Successful assignments get a 100 ms green pulse, with local HDR brightness when
available. An existing assignment gets an 80 ms orange cue. An eligible neighbour
normally takes priority over orange. When Build targeting favours a current builder,
keep that builder selected until it finishes. Show its actual eligibility and do
not queue an early click. Honour the reduced-flash setting.

## Typography

Use the shipped green and blue bitmap fonts for all interface text, including
in-game notices. Classic lemming explosion countdowns use white, bold system
digits for crisp, readable numbers above each lemming. Use large green lettering for page titles,
small green lettering for section headings and selected or primary actions,
and small blue lettering for body text, quantities and secondary actions.
Keep each row of peer controls at the same face and scale. Do not size individual
labels to fill their boxes. Use spacing and grouping to separate supporting
text from headings. Preserve accessible names and input targets.

## Gameplay pointer

Use four corner brackets at the input position, with strokes one pixel
wide at every zoom and no central crosshair. Place the selected skill sprite diagonally below
and right of the bottom-right corner, about 10 screen pixels from each edge. Offer None, 1× and 2×
skill icon sizes in Gameplay settings. The visible 1× and 2× choices use actual
2× and 4× artwork. Modern defaults to 1×; Original hides the icon.
Offer a separate default-off lemming count below-left, aligned with the skill icon and the same distance from the opposite corner.
Count live sprite centres inside the reticule, regardless of skill eligibility.
Keep the count available when the icon is hidden.
Clamp the sprite to the playfield edge. Directional skills must use directional
artwork rather than falling back to a plain dot.
When a finite selected skill has one use left, fade only its sprite gently.
At zero uses, replace the sprite with a steady red X. Reduced motion and reduced
flashes keep the one-use sprite steady. The None size still hides the badge. Lemmings 3 has no
shared skill stock: only Use shows the hovered lemming's remaining tool uses.

Gameplay settings offer None, Obvious and Modern selection effects. None adds no
selection highlight. Obvious restores the game-scale coloured halo and overhead
pixel marker. Original selects None, and the Modern preset selects Modern.
An individual choice persists as part of the Custom preset. Machine artwork
presets preserve this choice.

Modern gives the selected lemming a white silhouette outline exactly two physical
display pixels wide after zoom, Retina scaling and CRT projection. White highlights march
along the outline without black segments. A soft green Gaussian bloom follows
the sprite's silhouette in linear HDR and remains visible in SDR. Its brightness
breathes smoothly over two seconds without changing its shape or disappearing.
Modern does not tint the sprite interior, draw a radial halo or add an overhead marker.
Reduced motion and reduced flashes keep both the outline and halo steady.
Reduced flashes also limit selection brightness to SDR.
The reticle retains the skill eligibility colours. Classic, Lemmings 2 and
Lemmings 3 share the selection renderer and keep its surface transparent to input.

L2's mask follows the primary lemming sprite, including mirroring and its vertical
pixel aspect. Separate projectiles, flames, balloons and parachutes are not part
of that mask. L3 follows the sprite that its current animation mapping renders.
Bitmap captures and machines without Metal retain a steady white SDR outline.
GPU checks cover two-pixel width at 1×/2× backing scale, fractional zoom, mirroring,
CRT curvature, HDR values and reduced effects. App captures cover the native
walking sprites in all three engines. Other poses and L2 attachments still need
a full visual sweep.

Gameplay settings offer Original, Modern and Custom presets. Modern enables
approaching-lemming targeting, blockers for bombs and current builders for Build.
Original disables these aids. Individual changes select Custom, which persists
even if the player restores the previous values. Only selecting a preset resets
its choices. Machine artwork presets preserve targeting preferences.
L2 retains a builder until native assignment rules allow another build. In L3,
Use favours bomb-equipped blockers, then active brick builders. These preferences
do not grant tools, change skill rules or queue builds.
L2's Exploder can be assigned to blockers; its blast Bomber cannot. The preference
only applies when the native skill rules permit the assignment.

Level Select uses a dropdown with Player Unlocked (default) and All. It keeps the
existing Classic progress override and saved choice. L2 and L3 retain their native
campaign selection rules.

## Fresh level start

Fresh starts and retries show a shared 3–2–1 countdown before play. Only visible,
active gameplay time advances the countdown. Menus and inactive windows hold it.
Pause or single-step cancels automatic start. Saved runs remain paused, and
Hot Seat handovers still wait for the player to indicate readiness.

Handover pages accept Space, Return and keypad Enter for their primary Ready action.
Held keys must not repeat that action. Pointer confinement also applies to paused
screens and menus in all three games. Respect the capture preference, Option release,
window focus, system sheets and app switching.

## Dialog input and accessibility

Return and keypad Enter activate the focused button. A new dialog focuses its
intended default action. Confirmations focus Back or Cancel. Tab and Shift-Tab
stay inside the current dialog, and closing a nested dialog restores its previous
focus. Held activation keys do not repeat. Text fields keep their normal editing
keys, and VoiceOver modifier combinations pass through to AppKit.

Level hints use Left and Right to revisit hint stages. Arrow keys never accept
the full-solution confirmation. Up and Down scroll the hint text.

Dialogs and help overlays use the normal system cursor. The gameplay reticle,
skill icon and count stay hidden until the final dialog or sheet closes. Covered
game controls are excluded from the active dialog's accessibility tree.
