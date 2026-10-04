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

NeoLemmix uses Classic stone controls and bitmap counters with a compact,
whole-pixel layout. The bar adapts to the level's skill count. Skill icons in the
bar and beside the cursor use the level's themed sprites and actual skill names.
Eight NeoLemmix skills must not select Classic's fixed eight-skill artwork.
The Macintosh artwork setting substitutes verified equivalents as described in
[NeoLemmix Mac artwork](NeoLemmixMacArtwork.md).
Locked spawn intervals disable both rate buttons. Minimap input follows the
visible map inside its frame. Offscreen checks cover 0, 1, 8, 10 and 21 skills,
resizing, CRT source rendering, selection, pause, undo and unavailable controls.
Lemmings 2 and 3 retain their separate panels and the same shared transport controls.

Assignment feedback follows the engine's actual eligibility rules. The Modern cursor is grey when no lemming is under the pointer. Yellow means the lemming cannot
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

Gameplay settings offer Original and Modern cursor styles in all three games.
Original uses the supplied Amiga artwork: a dotted cross with a yellow centre
over empty terrain and green square corners with yellow edge markers over a
lemming, including an ineligible target. Preserve its colours and transparency.
The 28-pixel source images occupy 14 game pixels and scale with playfield zoom
without smoothing. Modern uses four corner brackets at the input position, with
strokes one display pixel wide at every zoom and no central crosshair.
Original and Modern presets select their matching cursor styles.
An individual choice selects Custom, persists, and survives machine presets.
Both cursors remain at the input position and use the same targeting geometry.
Place the selected skill sprite diagonally below
and right of the bottom-right corner, about 10 screen pixels from each edge. Offer None, 1× and 2×
skill icon sizes in Gameplay settings. The icon, empty-skill X and counter share
a height of 14 screen points at 1× and 28 at 2×, independent of playfield zoom.
Preserve the sprite aspect ratio and use the counter’s bitmap font for the red X.
Modern defaults to 1×; Original hides the icon.
Offer a separate default-off lemming count below-left, aligned with the skill icon and the same distance from the opposite corner.
Count live sprite centres inside the reticule, regardless of skill eligibility.
Keep the count available when the icon is hidden.
Clamp the sprite to the playfield edge. Directional skills must use directional
artwork rather than falling back to a plain dot.
When a finite selected skill has one use left, fade only its sprite gently.
At zero uses, replace the sprite with a steady red X. Reduced motion and reduced
flashes keep the one-use sprite steady. The None size still hides the badge. Lemmings 3 has no
shared skill stock: only Use shows the hovered lemming's remaining tool uses.

Classic shows assigned permanent skills with a small pixel backpack: brown for
Climber, orange for Floater, and purple for both. Gameplay settings offer a
Show skill backpacks checkbox, enabled by Modern and disabled by Original.
Individual changes select Custom and persist across machine presets.
Follow the current pose and
facing direction in PC and Mac artwork, with hair and hands in front. Include
the pack in the sprite used for selection, speed trails and CRT rendering.
Remove it during death and exit animations. These markers apply to Classic;
NeoLemmix and the sequel artwork retain their own skill presentation.

Gameplay settings offer None, Obvious and Modern selection effects. None adds no
selection highlight. Obvious restores the game-scale coloured halo and overhead
pixel marker. Original selects None, and the Modern preset selects Modern.
An individual choice persists as part of the Custom preset. Machine artwork
presets preserve this choice.

Modern gives the selected lemming a steady white silhouette outline exactly two
physical display pixels wide after zoom, Retina scaling and CRT projection.
Modern always includes a mint-green halo, including when HD effects are off.
A brighter inner glow and soft outer falloff follow the silhouette. Build the
halo from distance to the silhouette so thin limbs do not lose their glow.
Its brightness breathes gently over 2.8 seconds of simulation time, with a
visible floor. The outline stays steady. Both stay at SDR brightness and
preserve the sprite interior. The reticle retains the skill eligibility colours.

Classic, Lemmings 2 and Lemmings 3 draw selection with the current sprite frame.
Flat mode uses the game's bitmap draw. CRT adds selection to its existing frame.
Selection must not activate the full-window HDR overlay, request a drawable of
its own or schedule a timer. Cache masks and glow images across animation frames
with a fixed entry limit. Keep bitmap clipping and CRT shading local to the sprite.
The effect adds no input surface. Pausing holds the current brightness, and
reduced motion or reduced flashes hold the midpoint. Reuse the same cached glow
for every pulse phase. Change its opacity rather than blurring it again.

L2's mask follows the primary lemming sprite, including mirroring and its vertical
pixel aspect. Separate projectiles, flames, balloons and parachutes are not part
of that mask. L3 follows the sprite that its current animation mapping renders.
Bitmap captures and machines without Metal use the same outline and green bloom.
Headless pixel checks cover two-pixel width at 1×/2× backing scale, fractional zoom,
mirroring, clipping, curved CRT output, pulse limits and cache reuse. Native
canvas captures check halo visibility against all three games' terrain with
HD effects both on and off, and record cached draw costs on real sprites.
Composited CRT window captures need an explicitly requested visible test run. Other poses and L2 attachments still
need a full visual sweep.

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

Catalogue discovery, fan-pack reading and level preparation stay in the background.
Keep the current menu visible and usable until the destination is ready. Back,
another destination or a different selection cancels pending preparation. Do not
show a separate screen for internal loading work. Show an error only when the
player needs to act. Hot Seat still waits at Ready before play begins.

## Fresh level start

Fresh starts and retries show a shared 3–2–1 countdown before play. Only visible,
active gameplay time advances the countdown. Menus and inactive windows hold it.
Pause or single-step cancels automatic start. Saved runs remain paused, and
Hot Seat handovers still wait for the player to indicate readiness.

Space and P toggle pause once per press during gameplay in all three engines,
including imported fan levels. Key repeat and key release do not toggle pause.
Text entry and menu/handover actions retain their own Space handling.

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

## Camera keys and positional sound

With Modern controls, H or Home centres the entrance. G or End centres the goal.
In L2, G first selects Hang Glider when the level includes it. G with Hang Glider
selected centres the goal. End always centres the goal. Other skills keep their
number keys and available letter shortcuts. Slash opens hints; question mark
opens controls help. I and F1 remain hint aliases. Text entry, app shortcuts,
menus and Hot Seat Ready retain their input ownership.

Effect positions follow the visible playfield, including camera movement, aspect
ratio and precision zoom. Keep events on the correct side when offscreen and
reduce their level with distance. Global warnings and interface sounds stay
centred. Do not add continuous construction loops over the original soundtrack.
