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
Classic Macintosh mode uses release sprites and recreates the remaining stone
and control tiles at 2× within their existing button bounds. Amiga mode keeps
the supplied panel artwork.

NeoLemmix uses Classic stone controls and bitmap counters with a compact,
whole-pixel layout. Macintosh mode recreates the stone and control glyphs at
2× within the same targets. The bar adapts to the level's skill count. Skill icons in the
bar and beside the cursor use the level's themed sprites and actual skill names.
Eight NeoLemmix skills must not select Classic's fixed eight-skill artwork.
The Macintosh artwork setting substitutes verified equivalents as described in
[NeoLemmix Mac artwork](NeoLemmixMacArtwork.md).
Locked spawn intervals disable both rate buttons. Minimap input follows the
visible map inside its frame. Offscreen checks cover 0, 1, 8, 10 and 21 skills,
resizing, CRT source rendering, selection, pause, undo and unavailable controls.
Lemmings 2 and 3 retain their separate panels and the same shared transport controls.
The 1.9 **Original Macintosh** counter option uses the supplied panel digits and
recessed socket at whole-pixel scales. It shares the existing Classic/NeoLemmix
targets and accessible counts. See [Macintosh fidelity](MacintoshFidelity.md).

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

Classic and Santa sprites show assigned permanent skills with a small pixel backpack: brown for
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
Keep these three targeting options in one stone group, with its label aligned
to the first option. The shared Settings page serves all three games.
Original disables these aids. Individual changes select Custom, which persists
even if the player restores the previous values. Only selecting a preset resets
its choices. Machine artwork presets preserve targeting preferences.
L2 retains a builder until native assignment rules allow another build. In L3,
Use favours bomb-equipped blockers, then active brick builders. These preferences
do not grant tools, change skill rules or queue builds.
L2's Exploder can be assigned to blockers; its blast Bomber cannot. The preference
only applies when the native skill rules permit the assignment.

Approaching targeting uses a nearby wall's direction when only one side has
upper-body terrain. It favours an eligible lemming facing that wall even when
the pointer sits inside the returning crowd. Floors, shallow steps and walls
on both sides retain cursor-relative selection. A centred click alone does
not count as approach. Keep the normal pick regions, same-direction nearest
selection, skill eligibility, bomb/builder priorities and L3 manual carriers.
Classic's brief hover cache must yield when a target turns away and an eligible
lemming still faces the wall. Classic/NeoLemmix, L2 and L3 use the same direction
cue. L3 applies it to its native actions and carried tools; it has no Basher slot.

Flat Panel disables and dims Tube Strength and Pixel Width, including their
labels. Monitor and Television restore these controls without resetting their
values. Whole pixels only remains available in Flat Panel. The Classic renderer
uses these tube settings; L2 and L3 retain their existing bitmap renderers.

Level Select uses a dropdown with Player Unlocked (default) and All. It keeps the
existing Classic progress override and saved choice. L2 and L3 retain their native
campaign selection rules.

Catalogue discovery, fan-pack reading and level preparation stay in the background.
Keep the current menu visible and usable until the destination is ready. Back,
another destination or a different selection cancels pending preparation. Do not
show a separate screen for internal loading work. Show an error only when the
player needs to act. Hot Seat still waits at Ready before play begins.
Show a compact bitmap Loading status on the current screen during preparation.
It must not intercept input or survive cancellation, failure or completion.
Opening the curated journey must not scan future fan packs. Validate the current
entry when it starts or resumes, then check later packs when they are reached.

## Fresh level start

Fresh starts and retries show a shared 3–2–1 countdown before play. Only visible,
active gameplay time advances the countdown. Menus and inactive windows hold it.
Pause or single-step cancels automatic start. Saved runs remain paused, and
Hot Seat handovers still wait for the player to indicate readiness.

Space and P toggle pause once per press during gameplay in all three engines,
including imported fan levels. Key repeat and key release do not toggle pause.
Text entry and menu/handover actions retain their own Space handling.

Gameplay and results offer a visible Menu action. Q and Escape use the same
return-to-library path, keeping the saved run and its owner. Command-Q retains
the app's quit action. Dialogs and text entry keep their own input handling.
Journey wins save at completion; Next level advances the queue and turn.
Hot Seat Resume actions name every participating profile in turn order, using
the same roster lettering as the library badge. Solo Resume keeps its owner.

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

## Liquid fill

Classic DOS and Mac artwork extend liquid columns only as far as the first solid
terrain pixel. Do not resume the fill in cavities below a shelf or floor. Use the
current terrain mask so digging, construction and rewind update the boundary.
This visual extension does not change water collision or level data.

## Transition timing

Avoid abrupt visual and audio transitions. Ease from the current value when a
transition changes direction, and do not restart a fade on repeated updates.
Nuke music starts its slowdown when the countdown changes from 2 to 1.
Desaturation starts only when the rescue target becomes impossible.
After the final nuke explosion, restore music tempo and filter over 2.4 seconds
with smooth easing. Keep this recovery running on the result screen.

Journey and playlist continuation keeps the current level visible while the next
level prepares. Do not show the library, title screen or level browser between
turns. Present the next Hot Seat player’s Ready handover only after loading.

## Solution replays and curated lessons

Solution replays fill the current game window, with a compact stone control bar.
Use the shared 1×, 2×, 3×, 5× and 10× speed model, including held F and Shift.
Keep pause, single-step and rewind separate from the live attempt. Home and Goal,
unassigned-lemming cycling, last-assignment tracking, drag/scroll panning and
2×/4× zoom affect only the replay camera. Manual camera movement cancels automatic
following. Zoom has no gameplay charge or saved-profile cost.
These controls apply to simulated Classic solution replays. Recorded movies from
Classic, L2 and L3 contain their original camera view and cannot track individual
lemmings. A simulation replay format for the sequels remains separate work.

The curated journey excludes known hidden-exit puzzles and unsuitable introductory
lessons in `Resources/Progression/exclusions.json`. Original campaigns and fan packs
keep their levels. Generation respects these exclusions and rejects replay commands
after the winning tick. Existing journey runs retain their ID, owner and visit
history when excluded entries are removed. The next retained entry becomes current.
This is an editorial exclusion list, not a claim that all hidden exits have been
automatically detected or that every lesson has a level-specific hint deck.
