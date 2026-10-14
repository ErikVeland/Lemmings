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
- Put forward game actions (Start, Play, Ready, Next, Continue and Resume) at the
  bottom of a vertical group or the right edge of its last row. Put Back, Cancel
  and secondary navigation before them. Keep drawing, input and accessibility
  order consistent. Use Apple's Human Interface Guidelines for platform controls.
  System alerts retain Apple's platform-specific ordering and safe default focus.
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
digits for crisp, readable numbers above each lemming on Mac and iOS. iOS draws
these digits at the screen's native Retina resolution above the flat or curved
playfield, with the Mac's font size relative to zoom. The touch magnifier uses
the same native text. Countdown text follows the sprite and adds no input surface.
Use large green lettering for page titles,
small green lettering for section headings and selected or primary actions,
and small blue lettering for body text, quantities and secondary actions.
Keep each row of peer controls at the same face and scale. Do not size individual
labels to fill their boxes. Use spacing and grouping to separate supporting
text from headings. Preserve accessible names and input targets.

Wrap level titles at word boundaries. Allocate the measured line height before
placing metadata, previews or actions. Keep the title face and scale consistent
for each screen size; do not shrink a long name or replace its ending with dots.
Break an unbroken name only when a word exceeds the available width. Keep
Official and Fan-made source labels separate from the level title and its status.
Use the catalogue's source metadata, including in mixed journeys and collections.
The selected carousel entry has a full title and source above its artwork.
See [Interface hierarchy](InterfaceHierarchy.md) for implementation and validation.

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
When selection ends, keep following the last actor and fade the combined border
and glow to zero over 0.35 seconds. New selection restores full opacity. Use the
existing frame clock, including while paused, and clear retained selection on
rewind or a new run. The iOS CRT fade updates selection without uploading the
unchanged playfield image.

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

Gameplay Menu fades after three seconds, with a 0.6-second fade. Hover or keyboard
focus reveals it. Its 88 × 44 input target stays active. Reduced motion hides it
without animation. Results and handovers keep their navigation actions visible.
Accessibility offers Fade Menu button. Turning it off keeps Menu visible during
play in Classic, Lemmings 2 and Lemmings 3, including with reduced motion enabled.
Q and Escape use the same
return-to-library path, keeping the saved run and its owner. Command-Q retains
the app's quit action. Dialogs and text entry keep their own input handling.
Journey wins save at completion; Next level advances the queue and turn.
Hot Seat Resume actions name every participating profile in turn order, using
the same roster lettering as the library badge. Solo Resume keeps its owner.

Handover pages accept Space, Return and keypad Enter for their primary Ready action.
Held keys must not repeat that action. Pointer confinement also applies to paused
screens and menus in all three games. Respect the capture preference, Option release,
window focus, system sheets and app switching. The top four points of the
captured window release the pointer so it can reach title bars and macOS menus.
Capture stays released while a macOS menu is open. Re-entering below that strip
restores capture after the menu closes. Side and bottom edges retain
confinement. This policy is shared by Classic, Lemmings 2 and Lemmings 3.

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

## Settings (1.9.2)

Group each settings tab by purpose. Gameplay contains play controls, targeting,
pointer feedback and level access. Pointer capture belongs with play controls.
Audio places music choices before sound effects, then playback behaviour.
Keep rhythm-on-pause and bottom-fall death sounds adjacent. Soundtrack downloads
are the final Audio action. Graphics separates machine presets, Classic artwork
and sequel artwork. Video separates display options from added effects.
Controller separates gamepad behaviour from button mapping. Accessibility
separates interface size from motion and flash reductions. Privacy separates
sharing from local counts.

Show setting explanations after an 800 ms hover over a control or its caption.
Use the stone frame and bitmap fonts inside the existing game canvas. Help must
not take focus or intercept the setting's input. Cancel pending help on pointer
exit, scrolling, tab changes or Back. Dismiss visible help on input or focus loss.
Retain the same explanation as accessibility help, including for disabled options.
Privacy details live in a hover popover and a clickable Privacy info popover.
Keep every setting reachable by scrolling and keyboard/controller focus.
The shared page retains all three games' settings and native engine limits.

Offscreen, muted settings checks cover all seven tabs at 1120×720 and 900×620,
checkbox text targets, scrolling, delayed hover and cancellation, keyboard
activation of Privacy info, remapping help, and available/unavailable sharing.
Classic settings model and persistence checks pass. The broader music suite
stops at its missing `demos` catalogue fixture. An isolated sequel check fails
L2's existing frame-step rhythm assertion before reaching L3. Runtime audio
parity therefore remains unverified for this change. The settings reorganisation
retains the existing engine actions and saved values. Physical controllers,
audible playback and Intel execution were not tested.

## Result navigation (1.9.2)

Name the result's session setup action Hot Seat. Keep the P shortcut on the same
route. A completed playlist or journey attempt can open the confirmation to
return to the library and change players. Cancelling keeps the result, attempt
owner and queued turn. Unfinished sequence attempts retain their navigation
guard. Classic, Lemmings 2 and Lemmings 3 supply their completion state to this
shared flow.

Place Worldwide beside the other secondary result links. It opens community
boards directly. Keep Game Center as a separate provider. Older local record
pages also retain the This level, All levels and Worldwide links.

Offscreen, muted checks cover the shared result layout with Classic, L2 and L3
conditions, community loading/empty/offline states, provider selection, older
records, mouse targets and accessible actions. The Classic app wiring checks
Hot Seat cancellation, the P shortcut, return to setup and the unfinished-run
guard. Actual sequel result-to-setup transitions were not exercised in this
focused run. Their completion state uses each native engine's `isComplete`.

## Leaderboard action replay (1.9.2)

Use the shared stone replay actions and each engine's bitmap renderer. Keep Play
as the primary action. It changes to Pause while running. Keep the time and
player identity above the playfield. Group the transport below it and wrap into
a second row in compact windows. Dim the native skill/transport panels, remove
unused timeline controls and the L3 Menu action, and omit those inactive targets
from accessibility. The playback simulation has no live gameplay callbacks.

Offscreen muted checks passed for reconstruction in all four engines and for
Classic, L2 and L3 rendered start, middle, end, rewound and compact states. Target
bounds, mouse hits, single stepping, play/pause, timer progression and speed
changes were checked. The native renders were inspected at 1120 x 720 and
760 x 520. NeoLemmix uses the shared Classic playfield. Its reconstruction was
checked, but a separate NeoLemmix artwork render was not captured in this run.

## Rescue celebration

Solved Mac playfields add a very faint golden haze to terrain and scenery in
Classic, Lemmings 2 and Lemmings 3. Limit it to 5.5% opacity at SDR brightness.
Keep original artwork sharp and draw the haze beneath lemmings and interface
text. Empty space receives only the soft falloff near scenery edges. Use the
existing fade, rewind reset and brief celebration for 100% rescue requirements.
Windowless before-and-after exports of two Classic scenes were inspected.
Sequel gameplay and mobile appearance remain for manual validation. Automated
tests and public release audits were skipped for this local manual build.

Build background haze images off the main thread. Reuse dynamic scene haze for
at least 0.25 seconds and limit its source width to 256 pixels. Keep fade opacity
independent of that refresh rate. Bound each canvas cache to 32 entries and
16 MiB, with at most two pending renders. Classic replaces its scene bitmap each
tick, so image identity alone must not trigger a fresh blur on every frame.
Both Mac sequels reuse decoded bitmap pixels for gameplay draws. Lemmings 2
rebuilds its panel image only when its pixels or palette change. Artwork reloads
clear that panel cache. Windowless exports retain normal and mirrored pixel
orientation. Higher-speed gameplay remains for manual validation.

When the rescue target is secured, give Classic, Lemmings 2 and Lemmings 3 the
same golden haze around their playfields and a soft golden aura around the
rendered lemmings. Reuse their sprite masks and keep the original sprite pixels
clear. The aura follows scrolling, precision zoom and mirrored artwork. HDR adds
golden light to the SDR aura, bounded by the display's available headroom.
Reduced flashes or disabled HD effects keep the steady rim and omit the bright
sprite aura. Keep input targets unchanged. Rewind and retry clear the glow.
Qualifying result panels use the same golden rim; failed results do not.

Golden Path must retain Adaptive DJ's same-composition musical lift. A completed
win can lift during the opening section so short lessons still celebrate.
Levels requiring every lemming keep their current music. They get one brief
glow: 0.35 seconds in, a short hold, and 0.65 seconds out, ending after 2.2 seconds.
Reduced motion or reduced flashes show it steadily for 1.5 seconds. Do not
repeat it while the rescue target remains secured. Other levels retain the
steady glow and musical lift. Keep silent music, soundtrack preferences and
paused handovers intact. The iPad source shares the music exception and brief
glow timing. Its per-lemming golden aura and HDR output remain unvalidated;
the mobile sequel renderers do not yet expose the shared sprite masks.

Saved journey and playlist results contribute to the player’s career across all
three engines. Result panels show each newly earned Zoom and Superzoom use in
bitmap lettering, including accessibility. Credit follows existing thresholds:
one Zoom per three no-Rewind stars and one Superzoom per three distinct no-Rewind
three-star levels. Repeated clears do not add credit. Preview results do not claim
a saved reward.

## Records level browsing and music notices

Records Previous/Next follows the current campaign or pack order, including
levels without attempts. Unplayed levels show empty boards. Recorded levels keep
their exact rules and conditions. The first and last levels disable the outward
action. Mouse and arrow keys use the same list without changing gameplay,
progression or Hot Seat ownership. Standalone files fall back to saved boards.

Classic, Lemmings 2 and Lemmings 3 share a brief Now Playing notice when the
actual track file changes. Use the catalogue song title and soundtrack name,
with the source folder as a fallback for user files. Keep both rows in the
existing green/blue bitmap fonts and stone artwork. The notice accepts no pointer
input. Fade it in gently over 0.35 seconds. Keep its four-second display period,
then fade out for half a second. Reduced motion keeps it steady until expiry.
Accessibility offers Show song info. Turning it off hides the notice and its
accessible title immediately, across all three Mac engines. Both new options
default on and survive presets and saved settings. Do not repeat the notice for
the same track or show it on results or handovers. Silent music clears it.
The iOS source shares Show song info and the short fade-in. Its Menu control
remains visible and does not use the Mac's fading preference.

## Replay skill information

Solution and leaderboard action replays show remaining skills in the upper-right
corner. The shared stone panel uses the shipped bitmap font. It retains the last
three successful skill uses with exact tick numbers. A directional marker and
green lettering identify uses at the current tick. Seeking reconstructs both
the inventory and event history. The panel passes pointer input to the playfield.

Classic and NeoLemmix show their configured skills. Lemmings 2 uses its native
skill slots and supplies. Lemmings 3 shows tools held by active lemmings and names
the tool used by each recorded action. Recorded video replays retain their
captured HUD and do not gain command annotations.

Windowless, muted bitmap exports were inspected for long names, infinite supplies,
exhausted skills, current-tick markers and six-digit ticks.
The panel adjusts its spacing to keep these values complete. Tests and release
audits were skipped for this local Apple silicon manual build.

## Saved journey resumption

The journey hub finds its saved queue across solo and Hot Seat sessions. Prefer
this session's journey, then the active journey, then the most recently saved
journey. Show its current lesson and Continue. Switching sessions uses the shared
Resume session confirmation and restores the saved solo mode or Hot Seat roster
and turn. Save the departing level and retain its queued session. Opening the hub
must not switch players, move a run or change progress. New-session actions apply
when no compatible journey exists. Classic, Lemmings 2 and Lemmings 3 keep the
shared resume flow and paused Hot Seat readiness step.

Persistence regression cases cover saved queues, session selection and retained
native progress in all three engines. These cases were added for the next public
release audit. Automated tests were skipped for the local manual build. The existing Continue
and Resume controls are reused. Their captions and bounds were inspected in
windowless exports. Native pointer dispatch and complete session round trips
remain for manual validation.

On iOS, Home offers saved levels and journey runs only from the selected solo
player or Hot Seat. A missing shared checkpoint cannot fall back to a globally
saved solo level or another Hot Seat. Clear the previous checkpoint action while
the selected session loads. The Journey page retains its cross-session search.
Ownership regressions cover Classic, Lemmings 2 and Lemmings 3 checkpoint envelopes
and matching legacy global saves. Offscreen, muted bitmap checks cover selected
Hot Seats with and without saved levels across five phone and tablet sizes.
The iOS modules compile. Device navigation and native sequel checkpoint round
trips remain for manual validation.

## 1.9.4 public validation

The public audit passes the saved-journey XCTest and Swift Testing regressions,
including retained queues and native progress across all three engines. Native
offscreen checks cover saved-session navigation, replay inventory and exact
skill ticks, compact and large render states, update discovery, song notices,
completion callbacks, result actions, and paused Hot Seat handovers. Settings
checks scroll each control into view before testing visibility and input.

The scenery haze is a faint SDR effect built asynchronously. Pixel comparisons
preserve empty black space and original artwork; a 1,000-frame bitmap check
bounds draw overhead with changing scene-image identities. GPU checks verify
the reduced sprite aura and idle cleanup. Sustained speed and physical HDR
appearance remain manual. Offscreen focus-dependent checks remain skipped.
See the 1.9.4 distribution evidence for measured speed and remaining limits.

## Rewind feedback

Successful Mac rewinds, including one-tick Command-Z, add a 160 ms impulse of
sharp sprite echoes in Classic, Lemmings 2 and Lemmings 3. Echoes trail toward
the future positions just left behind. Reuse the speed-trail cache, crowd limits,
mirrored artwork and whole-pixel sampling. Keep every solid lemming above the
echoes. Do not capture the whole playfield or add an input surface. Repeated
taps replace the impulse, and forward play clears it. HD effects off, reduced
motion or reduced flashes suppress the echoes. Keep the shared rewind badge.

The shared sound player adds a centred 115 ms tape zip with a rubbery pitch
rebound, including when recent gameplay was silent. Mix in a quiet reversed
slice of recent effects when available. Rapid taps replace the previous cue.
Honour mute, sound volume and suspended output, and exclude rewind audio from
its own history. Mobile shares this sound; the sprite echoes are Mac-only.

Music scratches backwards through recent stereo PCM for 180 ms, with the shared
vinyl braking curve. Recordings, native mixed MOD samples and every audible
Adaptive DJ layer use this path across Classic, Lemmings 2 and Lemmings 3 on Mac
and mobile. Rapid taps continue the same reverse groove; held rewind extends
it without stacking copies. Keep the current music volume and DJ mix gains.
Mute, zero volume, suspension and track changes cancel the scratch. Rewind
keeps gameplay paused; forward playback retains the existing vinyl spin-up.
The groove holds at most 12 seconds of recent audio. It supplies transport
feedback and does not seek the song or tracker timeline to the gameplay tick.

Offscreen, muted native checks cover immediate direction, repeat replacement,
paused expiry, forward cancellation, actual Classic/L2/L3 bitmap renders,
solid sprite preservation, timeline targets and gaps, and reduced-effects
settings. Offline audio checks cover silent history, finite samples, short
endpoints, reversed history, 2,400 requests, mute and output suspension.
Music checks cover sample direction, stereo, rapid-tap continuation, real
recording and MOD output, parked engines, retained pause, vinyl spin-up and
Adaptive DJ layer gains. All automated audio checks stay offscreen and muted.
The full Mac source typechecks. Sequel seeks retain their existing replay
reconstruction cost. Audible feel, physical HDR/CRT display output,
sequel attachment poses and mobile appearance remain for manual validation.
