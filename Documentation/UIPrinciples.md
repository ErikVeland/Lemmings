# UI clarity

Write invitations and optional help as if welcoming friends round to play.
Keep the humour in the shared puzzle, the questionable bridge and the next idea.
Use it sparingly so repeated visits still feel comfortable. Action names,
save errors, destructive confirmations, privacy choices and accessibility
instructions stay clear and direct. Never tease the player for needing help
or add a joke where it delays Retry, Continue or Ready. Preserve the original
games' level titles, authored messages and credits.

Bonus skills use the shared bitmap chooser and stone controls in all three
games. Show the record and earning limits before spending, one selected skill
or tool carrier, Back at bottom-left and Use bonus skill at bottom-right.
Keep Ready handovers paused. Name newly earned consumables on results, with
the rare Bonus skill first when several arrive. Show Bonus skill used on the
attempt and BONUS on its separate records. Preserve full receipt reasons.
Gameplay reward badges share the menu fade and retain their hover area.
Reveal them on hover or use, then resume fading. Paused Inspect must not hold
the badges at full opacity.

The 2.1 welcome page uses the same bounded bitmap reading column as About.
Reflow paragraphs when the window changes size. Keep Continue visible at
bottom-right. Lead with this release's access, inspection and Bonus skill changes,
then give a short pointer to the full earlier history.

Tester Sync separates configuration from delivery. The selected On control
means the library key is stored. The status reports Syncing, Synced, Saved on
this device or Offline. Partial uploads and newer local saves cannot display
Synced. Keep the shared library scope concise and make Back the primary next
action after setup. Mac, iPhone, iPad and TV use the same bitmap page.

Mac About uses the shared stone tabs for About, Version history and Contributors.
Version history has a scrollable release index and a separate reading pane.
Open the installed version first. Keep the reading column bounded, with distinct
section headings, paragraph spacing and indented list items. Changing versions
returns the notes to their top. Bundle the installed version's notes before feed
publication, without duplicating its feed entry.
Release-index buttons retain at least 44-point input height.
History and contributor paragraphs scroll within the body. Back stays
at bottom-left and starts focused. Buy me a coffee is the bottom-right action.
Contributor delivery retains saved content during loading or failure and offers
Retry in the offline state. Markdown supplies text only, with bitmap headings
and body lettering.

Muted offscreen About checks cover three window sizes, release selection by
keyboard and accessibility, both scroll panes, wrapped bullets, input targets
and cached/offline contributors. Packaging checks cover the current notes before
and after feed publication, with one entry for the installed release.

Home keeps Donate with its secondary footer actions on Mac, iPhone, iPad and
TV. Preserve the gameplay primary action and keep Donate enabled without game
data. Mac and iOS open the shared coffee URL. TV shows its QR code and address
with Back at bottom-left. iOS uses the same page if browser opening fails.
Fit the code and Back together at a whole-pixel scale. Compact preview pages
reserve the gap after the preview before placing the footer.

Privacy count reset opens ARE YOU SURE? with Back focused. Restore previous
counts becomes available after clearing and disables after recovery. The backup
retains counts earned after the reset. These shared local counts cover Classic,
Lemmings 2 and Lemmings 3 without changing their turn or handover flows.

Mac Home changes the update arrow to a pixel hourglass immediately after an
update request and while an update downloads. Keep its mouse, keyboard and
accessibility actions available in the same bounds. Its accessible name reports
loading, downloading or ready to install. Completion, cancellation, failure and
session cleanup clear the busy state.

Mac gameplay shows the saved percentage alongside the rescue counters. Use the
engine's level total and round down to whole percent. Classic and NeoLemmix keep
the Home count and add the percentage in parentheses. L2 uses a blue Saved
annotation beside its existing status overlay. L3 keeps the percentage beside
Save and draws its percent symbol with the shared bitmap renderer.
Muted offscreen checks cover Classic bitmap fixtures at 0%, 50% and 100% across
three widths, native L2/L3 zero-save renders and sequel timeline targets. Separate
NeoLemmix and nonzero sequel renders remain unchecked. Mobile HUDs use the shared status strip described below.

The user's requirement: icons and states must make sense without explanatory
sentences. Apply this to new UI and changes to existing UI.

The iOS/tvOS funeral mood desaturates the playfield pixels directly. Flat mode
draws over its opaque game canvas; CRT uses its existing saturation/brightness
uniforms. Do not use a grey sibling UIView to blend with a Metal surface.
The fade preserves black and adds no input target, Metal pass or source upload.
Muted flat-render checks and inspected gameplay captures verify desaturation,
dimming and exact recovery. Headless Metal output is unavailable in this
environment and still needs device verification.

- Use the game's bitmap artwork and pixel controls throughout game pages and HUDs.
  Menu lettering must not depend on the selected level graphics.
  Do not mix system fonts, SF Symbols, rounded Aqua controls or modern gradients
  into game artwork. AppKit can supply input and accessibility beneath game rendering.
- Set reading text flush left in sentence case. The Macintosh character sets
  include lowercase letters. This applies to About, Version history, Contributors,
  What's new, hints, award and reward explanations, and controller help.
  Separate paragraphs with a blank-line gap. Keep list items, such as control
  help, close together. Pass whole paragraphs and let the page wrap them.
  Titles, headings, action names and HUD text stay in capitals. The compact HUD
  face has no lowercase, so text that falls back to it stays in capitals.
- Show each outcome once. A filled star already communicates an earned goal.
- Reserve bevels and green pressed fills for controls. Passive previews, counters,
  help, receipts and information panels use flat, neutral backgrounds. Show a
  selected level cover with an outline, without a filled button face.
- Use familiar action symbols. Pause changes to Play. A reversible action changes
  to Undo. Do not leave a destructive symbol on a button that now undoes it.
- Distinguish state through shape as well as colour. Earned stars are filled;
  unearned stars are outlined. An unknown target uses a question mark.
- Keep one primary action per screen. Give it a stronger outline and a directional
  marker. Selection has an underline; keyboard focus has its own outline.
- Put forward game actions (Start, Play, Ready, Next, Continue and Resume) at the
  bottom of a vertical group or the right edge of its last row. Back stays furthest
  left, at the bottom-left of a multi-row action group. Reserve that slot for
  Back, Cancel, Library or Close navigation and keep the primary forward action
  at bottom-right. Secondary actions fill the rows above and remaining slots.
  Back must not become centred or move right when actions are added or removed.
  Keep drawing, input and accessibility
  order consistent. Use Apple's Human Interface Guidelines for platform controls.
  System alerts retain Apple's platform-specific ordering and safe default focus.
- Keep quantities and player identity visible. They explain the current situation.
- Use one column for portrait phone Home. Use wider grids where the screen has
  room for readable peer actions. A lone action in a mobile grid row spans the
  row. Do not leave an empty button slot beside it.
- Put music notices at the playfield's upper-left corner. Reserve room for
  navigation and replay overlays, and keep the notice outside the HUD.
- Anchor the gameplay icon row 12 points from the content area's top and right
  edges. Keep Settings and Menu together, with a 24-point gap before that group.
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

iOS and tvOS keep the player profile visible in solo and Hot Seat play. The HUD
shows the profile portrait and green name at the left of a single status line,
with rescue progress at the right. Solo uses the
attempt's settings profile; Hot Seat uses the attempt owner. Menu headers,
pause/results and level browsing retain the same identity. Classic, Lemmings 2
and Lemmings 3 use the shared controller. Headless, muted checks cover 99 Classic
HUD renders and 135 menu states with input-target geometry. Both mobile SDKs
compile. Physical touch, remote focus and sequel gameplay remain device checks.

On iOS and tvOS, waking the scene or ending an audio interruption keeps the game
paused until Resume. Foreground menus remain usable during an interruption.
Explicit Resume clears the interruption block and retries audio activation;
audio failure must not prevent gameplay. A delayed interruption-end event must
not reopen Pause after Resume. Ready and Hot Seat handovers still wait for the
player. Classic, Lemmings 2 and Lemmings 3 share this controller and lifecycle.
[Apple does not guarantee a matching interruption-end notification](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioInterruptions/HandlingAudioInterruptions.html).

Muted, isolated lifecycle checks cover interruption ordering around sleep,
missing and delayed end events, route loss, inactive input, duplicate Resume and
Ready handovers. Audio queue checks cover failure and stale callbacks. iOS and
tvOS SDK modules compile. The existing pause audit passes 252 bitmap and target
checks, then fails its separate
restart-confirmation caption-width assertion at `Tools/IOSMenuAudit/pause.swift`.
Narrow layouts also report existing caption word-wrap warnings. The main package
test command cannot fetch Sparkle with network access unavailable; focused tests
use unchanged copies of the lifecycle sources. Physical sleep/wake, touch and
remote event delivery across the three engines remain device checks.

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

## Anniversary foundation priorities

Basic Zoom is free in Classic, Lemmings 2 and Lemmings 3. Show the action and
active state without a balance or earning explanation. Earned Superzoom remains
a separate optional resource. Preserve its saved ledger and existing rules.
Original/Modern are presentation choices. They preserve controller, input,
interruption, recovery and accessibility preferences. New profiles start with
restrained modern presentation and enter play without a required style-choice
page. Saved explicit choices remain intact.

When exact checked hints are unavailable, show **General coaching** and
**No level-specific hints available.** before advice. General tiers use neutral
Observe/Plan/Practise labels. Checked routes identify themselves as examples.
Keep pause restoration, Ready, spoiler boundaries and accessible evidence intact.

Modern pointer states differ in shape as well as colour: short empty brackets,
full eligible brackets and crossed unavailable brackets. Preserve the supplied
Original cursor artwork. Pointer marks add no input target and cannot change
selection geometry. Apply the shared geometry in native games and mobile/TV
presentation. Verify monochrome captures as well as zoom and Retina output.

Results lead with outcome, saved count, rescue stars and Continue/Retry. Career
and Rewards earned are explicit review actions. Future milestone bars, resource
balances and time records belong in those review pages. Phone and TV award rows
remain static until selected. No reward page may take over the result.

## Typography

Use the extended Lemmings lettering for interface text, including in-game notices.
Keep the compact 5×7 face for tiny HUD text when a complete line cannot fit a
12-pixel Lemmings face. Duo and narrow mobile status bars keep the regular
lettering, abbreviating labels and omitting secondary statistics as needed;
a narrow counter area alone must not select the tiny face. Never enlarge that
compact face for a title or countdown.
Preserve the original 1× artwork. The dedicated 2× display cut refines colour-cluster
contours, reduces doubled sparkle blocks and adds letter-specific highlight and
shade facets. Keep the doubled advances and bearings. Larger text retains this
painted texture, rather than replacing it with uniform bevel bands.
Keep the original blue/green ramps, accents, Tamil forms and measured bearings.
Start countdowns use the dedicated 4× green Lemmings numerals on Mac, iOS and TV
in all three games. Draw the 64×80 cells at native size. Their contours, counters,
facets and sparkles are authored on the final grid, with the original painted
colour clusters and fourfold bearings and advances.
Classic lemming explosion countdowns use white, bold system
digits for crisp, readable numbers above each lemming on Mac and iOS. iOS draws
these digits at the screen's native Retina resolution above the flat or curved
playfield, with the Mac's font size relative to zoom. The touch magnifier uses
the same native text. Countdown text follows the sprite and adds no input surface.
Use large green lettering for page titles,
small green lettering for section headings and player names,
and small blue lettering for controls, body text and quantities. Home's local and
global saved totals use green digits and separators, with blue labels. Keep control
captions blue when selected, primary, hovered or focused. Use borders,
underlines and directional markers for those states. Mixed lines retain
their roles: player initials are green, while v, Next:, counts and status text
are blue. Game titles are green and level counts are blue. Reuse the semantic
bitmap text renderer on Mac, iOS and TV, including player setup and replay pages.
Keep each row of peer controls at the same face and scale. Do not size individual
labels to fill their boxes. Use spacing and grouping to separate supporting
text from headings. Preserve accessible names and input targets.

Muted offscreen typography checks compare the original 1×, shared 2× and 4× numeral cuts, export
transparent blue/green atlases with glyph metrics, and render twelve sizes,
Latin and Tamil extensions, start countdowns, tiny HUD captions and shared fades.
Three-engine control checks verify corner anchoring, targets and actions. Both mobile SDKs
compile. Physical mouse, touch and remote delivery remain manual checks.

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
On iOS, lifting a touch, stylus or precise click returns aim to the actual hover
position. Without hover, clear the skill badge and target, then let the existing
selection fade finish. Hover exit clears aim. Fan toggles use the same release
boundary. TV retains its persistent controller pointer and target lock.
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
Macintosh 1-bit sprites use diagonal dithering for Climber, horizontal stripes
for Floater and a checker pattern for both. Use the matching colour frame's
anatomy to place the marker and preserve foreground pixels. Keep every marker
pixel black or white and use the same backpack preference and input targets.

Gameplay settings offer None, Obvious and Modern selection effects. None adds no
selection highlight. Obvious uses the game-scale coloured halo and overhead
green pixel diamond. Original selects None, and the Modern preset selects Modern.
An individual choice persists as part of the Custom preset. Machine artwork
presets preserve this choice.

Modern gives the selected lemming a steady white silhouette outline exactly two
physical display pixels wide after zoom, Retina scaling and CRT projection.
Modern always includes a mint-green halo and faceted green pixel diamond above
the selected actor, including when HD effects are off. The diamond follows the
rendered sprite through zoom, mirroring and CRT projection, and fades with the
selection. Paused Mac inspection marks the inspected actor without skill-target
bias. The marker adds no input target and does not change simulation state.
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

Mac gameplay uses one row of matching stone icon tiles at the upper-right:
Bonus skill, Hot Seat ghosts and Graphics, then a larger gap before Settings and Menu.
Unavailable features collapse out of the row. A spent Bonus skill stays disabled.
Ghosts use a filled ghost with a selected underline when on, and a slashed ghost
when off. Bonus skill uses a hammer in both the action row and reward counter.
Explain every icon with the existing flat Settings help popover and bitmap lettering.
Show it after an 800 ms hover or immediately on keyboard focus. Include the
action, current state and shortcut. Keep disabled explanations available.
Help must not take focus or intercept input. Dismiss it on pointer exit, input,
focus loss or leaving gameplay. Retain the explanation as accessibility help.
Command-comma opens Settings and holds gameplay while its page is open. F2 or
Graphics cycles installed Classic artwork without restarting the run. NeoLemmix
cycles PC and Macintosh artwork. Lemmings 2 and 3 switch between Original PC and
Macintosh-style artwork. Cycling overrides the current shuffled artwork and
keeps Shuffle enabled for future levels. The tooltip and accessible value name
the current source. Shortcuts ignore repeats, text entry, menus and handovers.

The whole gameplay row and reward badges share one opacity and timer. They fade
out over 0.6 seconds after three seconds, and fade in over 0.18 seconds on hover,
keyboard focus or reward use. Hovering any tile or a gap keeps the whole row
visible. Each input target stays active at 44 × 44 points. Tiles have 8-point gaps
within each group, with 24 points between actions and menus. Reduced motion changes visibility
without animation. Results and handovers keep their navigation actions visible.
Accessibility offers Fade gameplay buttons. Turning it off keeps the controls
visible in Classic, Lemmings 2 and Lemmings 3, including with reduced motion enabled.
`TEST_SCOPE=quick-controls` passes muted, offscreen checks for the three engines
at 640, 900 and 1600 points. Checks cover the icon row, Hot Seat ghost states,
input targets, status clearance, Settings access, graphics cycling, disabled
controls, shared fading, hover, focus, reduced motion, shortcut guards, run
preservation and Classic shuffle/wraparound.
Representative renders were inspected. NeoLemmix-specific graphics cycling,
CRT rendering and physical keyboard delivery remain separate manual checks.
Q and Escape use the same
return-to-library path, keeping the saved run and its owner. Command-Q retains
the app's quit action. Dialogs and text entry keep their own input handling.
Classic and NeoLemmix restore keyboard focus to the displayed playfield after
the launch action returns, including CRT mode. Space must work without a
playfield click. Deferred focus must leave menus and Ready handovers in control.
Muted, offscreen native checks cover immediate and deferred focus, NeoLemmix
file loading, and Space/P press, repeat, release and resume in all four engines.
Physical keyboard delivery in the rebuilt app remains a manual check.
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

After a confirmed solution reveal, use the shared Your game / Solution stone
selector. Retain each view's simulation, camera and transport state. Switches
pause both views, and Back returns directly to the game. Play remains explicit.
Keep the attempt owner and Ready handover. The same player's retry can retain
the replay; a different level or owner clears it. Previous move and Next move
seek to successful assignments while paused. Disable unavailable directions
and preserve the live attempt, checkpoint and records. See [pause and replay
behaviour](MobilePauseScreen.md) for platform inputs and engine limits.

Classic adds a default-off Ghost solution checkbox beneath the live selector
after the confirmed reveal. Use the current sprite silhouettes with a sharp
translucent outline, behind the real lemmings. Follow live simulation ticks and
rewinds without moving the retained study replay. Toggling preserves pause and
Ready states. See [Ghost solution](GhostSolution.md) for ownership and validation.
On iOS, the paused replay panel uses a full-width Ghost solution toggle with
an On/Off value and a moving pixel switch. tvOS uses wide, stacked rows beside
the pause overview. Selection has an underline and focus has a white border.
Keep these controls in paused or Ready panels, outside active gameplay. Closing
the panel clears selector focus and activation. Hidden controls cannot consume
controller actions. Keep the whole ghost row as one native touch/focus target.

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
Use a flat neutral frame and bitmap fonts inside the existing game canvas. Help must
not take focus or intercept the setting's input. Cancel pending help on pointer
exit, scrolling, tab changes or Back. Dismiss visible help on input or focus loss.
Retain the same explanation as accessibility help, including for disabled options.
Privacy details live in a hover popover and a clickable Privacy info popover.
Keep every setting reachable by scrolling and keyboard/controller focus.
The shared page retains all three games' settings and native engine limits.
Mac dialog containers must not bounce beyond their content and expose the
screen behind them. When a page fits, consume wheel input without moving it.
Long settings panes and enlarged pages retain bounded scrolling.

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

Securing the rescue target uses one faint, single-pixel golden border in Classic,
Lemmings 2 and Lemmings 3 on Mac, iPhone and iPad. Keep its opacity at 10% and
leave all interior game pixels unchanged. Do not blur scenery, light every
lemming, build crowd masks or activate an HDR surface for rescue feedback.
Apple TV retains no completion glow. Keep input and accessibility targets intact.

The border is steady. Repeated target updates must not redraw it. All-rescued
levels show it once for 1.5 seconds. Use the existing frame clock to expire it,
with no separate timer. Rewind below the target and retry reset the state.
Reduced motion and reduced flashes use the same steady cue.

Jubilant music is the primary feedback. Adaptive DJ and Golden Path lift to an
available arrangement of the same composition as soon as the rescue target is
secured, including 100% rescue levels. Start a smooth 2.6-second crossfade without
waiting for the opening section or bar alignment. Do not repeat the transition
on results. Keep silent music, alternate-soundtrack preferences and paused output
intact. A missing compatible arrangement retains the current theme.

Saved journey and playlist results contribute to the player's career across all
three engines. Earned Superzoom follows three distinct no-Rewind three-star
levels. Ordinary Zoom has no earning rule. Repeated clears do not add credit.
Preview results do not claim a saved reward. New rewards remain available through
the explicit Rewards earned action without delaying Continue or Retry.

Mac level-end pages use complete action rows. Divide the row among the actions
that exist, with consistent gaps and no vacant button slots. Group review actions
above the final row. Keep Back left and the primary next action right. Include
Back on successful results as well as failures. Learning journeys retain Hints,
Try later, Level Skip and the named Hot Seat retry actions.

Measure and wrap the result identity before placing the rescue summary. Omit the
status row when it has no content. Size reward receipts and achievement details
to their measured text and cards, with balances and navigation directly below.
A single action fills its row. Keep drawing, keyboard, mouse and accessibility
bounds in agreement when the panel height changes. Anchor the action row at the
same bottom position across result, reward and achievement pages. Short panels
shrink above the actions, so pagination does not move the navigation targets.

Mac results keep the Career card concise: career stars, awards and any explicit
Rewards earned receipt. Resource balances and future milestone progress remain
on Career and receipt pages. Phone and TV results show a static Awards count;
selecting it opens optional details. Keep the attempt owner's data in Hot Seat.
Returning from details never retries, advances or passes a turn.

Historical earned-resource captures predate free basic Zoom and quiet results.
Recheck those changed renders and targets before accepting the new source.
Physical VoiceOver and controller delivery remain manual checks.

## Records level browsing and music notices

Records Previous/Next follows the current campaign or pack order, including
levels without attempts. Unplayed levels show empty boards. Recorded levels keep
their exact rules and conditions. The first and last levels disable the outward
action. Mouse and arrow keys use the same list without changing gameplay,
progression or Hot Seat ownership. Standalone files fall back to saved boards.

Classic, Lemmings 2 and Lemmings 3 share a brief Now Playing notice when the
actual track file changes. Use the catalogue song title and soundtrack name,
with the source folder as a fallback for user files. Use an upper-left broadcast
credit box inside the playfield: a black stone-framed backing, a green pixel accent,
a prominent green song title and smaller blue soundtrack credits. Wrap complete
titles at word boundaries at fixed bitmap sizes. On narrow or shallow playfields,
show successive credit pages rather than truncate text or cover the controls.
The notice accepts no pointer input. Fade it in gently over 0.35 seconds. Short
credits retain four seconds plus a half-second fade. Longer credits receive more
reading time. Reduced motion keeps it steady until expiry.
Accessibility offers Show song info. Turning it off hides the notice and its
accessible title immediately, across all three Mac engines. Both new options
default on and survive presets and saved settings. Do not repeat the notice for
the same track or show it on results or handovers. Silent music clears it.
The iOS/tvOS source shares this renderer, Show song info and the short fade-in.
iOS keeps its Menu control visible without the Mac's fading preference. TV omits
the on-screen Menu control and uses Siri Remote Back or controller Options/Menu.

Offscreen music-card checks cover complete wrapped credits, narrow/shallow credit
pages, reading time, fades, same-track expiry after resize, reduced motion,
playfield containment and Menu hit targets in flipped and unflipped Mac views.
Bitmap captures use shipped lettering at Mac, phone, tablet and TV sizes.
iOS and tvOS SDK source compilation passes. Composited Mac CRT placement and
physical touch/controller and television readability remain manual checks.

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

The earlier scenery haze and sprite aura passed local bitmap and GPU checks.
They have since been removed from gameplay under the rescue-feedback policy
above. Physical frame timing still requires device validation. Offscreen
focus-dependent checks remain skipped. See the 1.9.4 distribution evidence for
its historical measurements and remaining limits.

## Rewind feedback

Successful Mac rewinds, including one-tick Command-Z, add a restrained 160 ms impulse of
sharp sprite echoes in Classic, Lemmings 2 and Lemmings 3. Echoes trail toward
the future positions just left behind. Reuse the speed-trail cache, crowd limits,
mirrored artwork and whole-pixel sampling. Keep every solid lemming above the
echoes. Do not capture the whole playfield or add an input surface. Repeated
taps replace the impulse, and forward play clears it. HD effects off, reduced
motion or reduced flashes suppress the echoes. Keep the shared rewind badge.

The shared sound player reverses a quiet 180 ms slice of captured effects.
Silent history stays silent. Smooth endpoints replace the synthetic tape zip
and pitch rebound. Rapid requests continue the active groove without stacking voices.
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

## Home resume actions across platforms

Offer one shortcut per distinct saved destination. On iOS, Resume journey restores
its matching checkpoint; omit Resume level only when the current session and
validated level identity match. Keep standalone Classic, Lemmings 2, Lemmings 3
and NeoLemmix checkpoints independently accessible. Journey's home count means
levels solved and is labelled Solved; do not repeat queue position on Resume.

Mac journeys and playlists save checkpoints with their queue, exact entry,
content revision, player and Hot Seat identity. Resume journey/session restores
the matching attempt, selected action and camera while keeping play paused.
Retain Continue journey/session when an older saved queue has no matching
checkpoint. Keep Resume level for independently saved attempts. The normal TV app now shares the iOS
journey/session and checkpoint destination rules. Sequel entries require the same
compatible imported data, and journeys currently accept Classic entries. Do not hide a
checkpoint based only on a title, counter or player name.

## Mobile and TV skill feedback

Touch/controller aiming and TV use the shared SkillPointerBadge renderer: native
selected-skill artwork, remaining supply, a dark backing and a restrained green
inner glow. Keep the icon visible at zero stock and show a warning-coloured zero.
Unlimited Classic skills use the existing star marker. Lemmings 3 actions have no
shared supply; Use displays the targeted lemming's carried-tool uses. Other L3
actions omit the counter. L2 uses the original skill tiles without their empty
padding; L3 uses its original action-panel tiles. Missing artwork falls back to
the complete action name. Existing iOS None/1x/2x settings remain respected.

The badge stays within the playfield, away from the aim point, and adds no input
target. Selected HUD skills retain their outlines and add the same inner glow.
Offscreen muted checks cover native Classic/L2/L3 icons, stock semantics, invalid
indices and edge placement. iOS and tvOS SDK source compilation passed; physical
controller/touch and television readability still require manual validation.

## iPad landscape home

Wide tablet Home menus keep the moss cap and stone base on a bounded, centred
box. Leave spare height around the box for level scenery. Keep touch targets
and lettering at the selected interface size. Compact panes retain scrolling
when the content cannot fit.

Windowless, muted checks cover 84 home states across three interface sizes,
including saved runs, loading, disabled actions, tablet landscape and portrait,
split view and phones. Bitmap renders and shared input bounds were inspected.
The shared artwork module compiles for iOS. Physical UIKit touch and VoiceOver
still need device validation. The wider menu
audit stops at a stale result inset assertion: it expects 16 points while the
current result layout uses 20.

## Tablet gameplay panel and settings grid

Landscape iPad and an unfolded iPhone Duo use the Mac layout for Classic
gameplay: the original panel at a whole 3× or 4× scale, with the status row
above the playfield. A hinge across the screen keeps the panel below the hinge.
A hinge down the screen keeps the divided touch deck, because the panel must
not cross the hinge. Portrait and phones keep the touch deck. Lemmings 3 keeps
its own panel. Lemmings 2 and NeoLemmix have no panel artwork on mobile and
keep the touch deck.

Wide settings, language and button-remap pages pair their rows. A lone last row
spans both columns. Portrait phones keep one column. Apple TV keeps its paged grid.
An unfolded Duo uses the tablet Home box.

Hot Seat ghosts have one local switch on Mac, iPhone, iPad and Duo. The Hot Seat
page and the pause menu show Ghosts on or Ghosts off. Hidden ghosts keep their
recorded turns. Classic, Lemmings 2 and Lemmings 3 share the switch.

## Device menu layouts

Portrait phone Home uses a full-width list for libraries, saved runs and footer
actions. Landscape phones and tablets use paired rows. A final lone library or
footer action spans the complete row, including action shelves with Back and a
primary forward action. Keep Back left and the paired forward action right.

Mac Home reuses the shared bitmap menu layout. Saved play and Journey lead the
library group. Put player identity above the footer actions and retain saved
counts and marching lemmings beneath the menu. Larger windows give the logo and
rows more space. Compact windows scroll without shrinking the lettering.
Mouse targets, accessibility frames, arrow-key movement and keyboard activation
follow the same geometry. Keyboard navigation reaches the footer and corner
controls and scrolls the focused target into view.

The shared music notice occupies the upper-left playfield corner across Classic,
Lemmings 2 and Lemmings 3. On Mac, reserve the Menu control's width. Mobile
replays reserve their title and skill panels. Preserve wrapped credit pages,
fades, settings and input pass-through.

Offscreen, muted validation passes 14 focused tests, with 60 native Mac menu
captures and 135 mobile home renders. Checks cover mouse activation, keyboard
movement and activation, compact scrolling, visible accessibility bounds,
single-column phones, odd library counts, footer navigation and complete music
credits. iOS SDK modules compile. Physical touch, VoiceOver navigation and
composited CRT display appearance remain manual checks.

## Home groups and semantic colours

Wide Home pages keep saved play and Journey map in the leading group. The six
Classic and fan libraries use equal horizontal and vertical gaps. Lemmings 2
and Lemmings 3 occupy a separate row with their shipped title artwork and
accessible game names. Profiles, Records and Collections / Playlists share one
three-column footer. Portrait phones retain one column and scrolling. Spare
landscape height stays around the bounded menu box. Keep the gaps inside the
library grid consistent.

Resume journey returns to a saved journey. Resume level opens an independently
saved attempt. Journey map opens the progression hub. Mac uses Resume
journey when its matching checkpoint exists and Continue journey otherwise.
These labels retain each platform's saved ownership and paused readiness flow.

Player names and titles remain green across Home, turn headers, player setup,
record names, cover browsing and replay identity. Interface captions, counts,
status text, v and Next: remain blue. Selection uses its existing frame,
underline and marker rather than changing caption colour. Original title logos
keep their authored palettes. Semantic text runs preserve translated player
caption order and keep numeric player initials green.

Muted, offscreen checks pass for 57 menu renders across tablet, portrait phone,
compact landscape and television-sized canvases, including selected and disabled
states and Classic/L2/L3 identity pages. They check matching grid gaps, the
three-button footer, sequel separation, action identities, target containment
and non-overlapping hit regions. Five native control and badge captures check
blue enabled/disabled and selected/unselected captions, accessible activation,
and the shared green L2/L3 player badge. The Mac source build passes. Physical
touch, controller focus on devices, VoiceOver and composited CRT output remain
manual checks.

## Localisation

Resolve app-authored captions and accessibility messages through the shared
`L10n` catalogue before measuring text or placing input targets. Keep complete
sentences together and use plural rules for count-dependent wording. Keep
save keys, action IDs, artwork names and keyboard bindings separate from
translated captions. Preserve player names and original content titles.
Keep supported Western Latin accents and letters in the bitmap text. Measure
the complete caption, including marks above and below the original cell, before
centring it or allocating wrapped rows. Reuse `BitmapLatinGlyphs` and the shared
text measurements instead of stripping accents or adding a system-font fallback.
Check expanded text with the shipped bitmap renderers and unchanged input
semantics. Font scripts and text baked into original artwork need explicit
language validation. See [Interface localisation](Localisation.md).

## TV pointer and planning controls

TV keeps the aim reticle visible during planning and rewind. The skill badge
remains offset from the aim point. A root overlay carries the reticle over HUD
controls and projects playfield input through the CRT mapping. It has no input
surface. Cross activates the shared HUD button bounds. Keep the controller's
Circle pause/play loop separate from Menu navigation. TV Circle resets speed
and toggles planning pause/play immediately. R2 resumes
planning and controls fast-forward without parking play. L2 resets fast speed
before rewind. See [controller QoL](ControllerQoL.md)
for trigger and engine limits.

## Failure navigation

iOS and TV results keep Back to the level library and Menu to Home alongside
Retry or the named Hot Seat action. Back retains the bottom-left target and the
primary action stays bottom-right. A result-save error retains both navigation
actions. Normal exits follow the Hot Seat house rule. A save-error exit retains
the unresolved checkpoint and current turn.
Mac results retain Back and Menu, including the Hot Seat Try later variant.

Sequel mobile results without ranking conditions save local records without
ranking telemetry. Classic retains its supported ranking telemetry. Failure
regressions cover saved and reopened records across all three engines. Bitmap
checks cover 54 phone, tablet and TV layouts, including save errors and Hot Seat.
Native Mac checks cover 12 solo/Hot Seat loss variants, accessible actions,
mouse targets and keyboard activation.
The Mac source build and iOS/tvOS SDK module builds pass. Physical touch,
VoiceOver and remote focus remain device checks.

## Navigation and recovery

Source review covers the Mac menu constructors and the shared mobile and TV
routes: libraries, journeys, collections, profiles, Hot Seats, settings, imports,
cloud saves, records, hints, replays, results and startup recovery. A visible Mac
Back control gets a default dismissal action. Required Ready handovers retain
their explicit boundary. Hardware Back uses a safe visible choice on welcome,
consent and skill-pause pages.

Save and handover errors offer Retry, Back and an independent Menu exit. Error
exits retain unresolved saves and ownership. Cancelling a save prevents its late
completion from leaving the game. Returning from help or errors restores Ready
or the completed result, and an immediate End Run opens results. Late hints and
cancelled exports cannot replace the player's new page. Menus retain standard
controller input when gameplay controllers are disabled. Library-only settings
stay in the library. Records repair confirms a reset and preserves unreadable
files. TV migration errors allow Continue without marking migration complete.
Long startup and transfer errors update their scrolling input surface.

Run `zsh Scripts/run-navigation-recovery-tests.sh` for the muted, offscreen gate.
It passes 44 focused tests, 81 page states, 1,458 layouts and 486 bitmap renders
across six screen sizes and all interface sizes. The larger menu audit also
passes 441 pages, 60 HUD states, 18 native artwork states, six cover states and
three unfold frames. It checks that scrolling can reveal each action, including
compact Home and long errors, and retains disabled-control and gap checks.
iOS and tvOS SDK compilation passes. Five UIKit navigation regression cases
typecheck on both SDKs but have not run on devices. Physical touch, remote focus,
VoiceOver and complete content-corpus simulation remain validation gaps.

## Mac Home scenery

Mac Home keeps its bitmap menu in a bounded, centred box. Large windows leave
level scenery visible around it. Compact windows retain scrolling, complete
captions and the same mouse, keyboard and accessibility targets. Saved counts
sit below the box. Marching lemmings reuse the front-end artwork when no game
has been loaded.

Use the selected player's last played level as scenery when available. If that
level is missing or there is no history, keep one randomly chosen level until
the destination or player changes. Render the scenery separately from gameplay.
Opening Home must not create an attempt or add a Recently Played visit.
Classic, Lemmings 2, Lemmings 3, catalogue NeoLemmix levels and Classic fan packs
use the existing source loaders and object artwork.

The camera eases from the opening view towards the exit and back. Clamp it to
the full level image. Use the existing menu clock and a maximum speed of three
level pixels per second. Accessibility offers a separate Static home screen choice, saved per player. It
freezes the camera and marching animation without changing gameplay effects.
The game's Reduce Motion setting and macOS Reduce Motion also freeze both.

Focused, muted offscreen checks pass for Classic, Lemmings 2 and Lemmings 3.
They cover exact last-played scenery, random and missing-content fallbacks,
unchanged play history, camera bounds, exit travel and return, Reduce Motion,
24 bitmap captures from 900×620 to 5110×2878, mouse targets, accessibility bounds
and keyboard selection reveal. The Mac source compiles. NeoLemmix and fan-pack
scenery reuse their preview loaders but were not included in these native
fixtures. Physical VoiceOver navigation and composited CRT appearance remain
manual checks.

## iPad and TV Home scenery

iPad and the normal TV app use the same bounded Home box and scenery flow.
Leave spare height around the box. Wide layouts use three columns for the six
Classic/fan libraries and a separate row for the sequel logos. Keep the selected
interface size on iPad and scroll when its contents cannot fit. TV uses its
fixed landscape layout and the largest fitting whole-pixel scale. Player identity stays
above the footer without a duplicate Next caption under the logo. Portrait
phones retain their existing Home presentation.

iOS Home puts progress fractions below their action titles at every interface
size, including wide iPad layouts and saved playlist runs. Keep the title and
count in one input target. The footer action is named Playlists.
Muted, windowless checks cover 567 layouts across nine languages, six mobile
viewports and the shared TV board, including selected and disabled states.
They verify separate count lines, caption bounds, target sizes, hit testing,
non-overlap and inactive gaps. Physical touch and VoiceOver remain device checks.

The backdrop occupies a separate, non-interactive view behind the menu. Keep
one uploaded bitmap and move its image layer with nearest-neighbour sampling.
Reuse the existing menu display link. Pause the camera for Static home screen, the game or system Reduce Motion
setting, an inactive scene or a covering page. Resume without
catch-up movement. The backdrop adds no touch, controller or accessibility target.

Save a small scenery reference after a successful level start, scoped to the
selected profile and solo/Hot Seat session. Reopen artwork on a worker without
restoring a checkpoint, ticking physics or recording a visit. Classic and native
L2/L3 use their real exits. NeoLemmix uses its resolved entrance and exit zones.
Older matching checkpoints and Classic recents seed this reference. Missing
content or no history selects random installed scenery. Keep that choice across
menu redraws until its source, player or session changes.

Windowless, muted checks pass for 126 Home captures across iPad portrait,
landscape, small and Split View panes, TV safe areas, 1080p and 4K canvases,
and all three interface sizes. They cover Classic/L2/L3 scenery identity,
scoped references, missing/random fallback, target bounds and non-overlap,
selected/disabled actions, footer scrolling, camera limits and return, and the
reduced-motion/inactive clock. iOS and tvOS SDK modules and app entry points
compile. These checks use the shared render and target geometry. Native UIKit
touch, VoiceOver, remote focus delivery and physical TV compositing/performance
remain device checks. NeoLemmix and fan scenery use existing loaders but were
not included in the native scenery fixtures.

Static home screen checks cover saved settings, older preferences, profile
isolation and presets. Muted offscreen checks pass for two native Mac setting
renders, mouse/keyboard/accessibility activation, Classic/L2/L3 scenery and 18
phone, tablet and TV setting renders. Mac, iOS and tvOS source builds pass.
Physical device input and composited display output remain manual checks.

## Regional Lemmings 3 branding

Use The Lemmings Chronicles for the US device region and All New World of
Lemmings elsewhere, including an unknown region. Read the region independently
of the interface language. Mac, iPad and TV share this rule for Home artwork,
game names and accessibility labels. Decode both original title logos with
their authored palettes and nearest-neighbour sampling. Keep save identifiers,
content fingerprints and storage paths independent of the displayed title.

The muted, windowless `--regional-brand` menu audit passes 36 captures across
Mac, iPad and TV sizes and all three interface sizes. It checks both original
logos, regional and language independence, accessible action names, target
containment, hit testing and non-overlap. Artwork packaging retains the exact
US source file. Mac source typechecking, iOS/tvOS SDK modules, app entry points
and the localisation catalogue pass. Physical VoiceOver and device input remain
manual checks.

## Book Home menu

Home uses both panes when a vertical division leaves room for two lists.
Keep the saved games and libraries in their existing order, down the left list
and then the right. Balance the lists using measured captions and the footer
space. Keep Profiles, Records and Playlists together below the left list, with
the update and Settings icons in the header. Retain one primary action, the
player identity, native sequel logos and complete progress counts.

Both lists retain the selected interface size and share vertical scrolling when
needed. Full-height unobstructed banks keep scrolled actions clear of the hinge
and camera. Drawing, keyboard navigation and accessibility follow the same list
order. Other pages retain their existing safe menu region.

The muted, windowless `LemmingsMobileMenuAudit --book-home` check passes 120
captures across four book poses, all three interface sizes, solo, saved games,
Hot Seat, expanded captions and unavailable/selected/busy states. It checks both
lists, every action, target sizes, hit testing and scroll reachability. Focused
menu/layout tests and iOS/tvOS SDK compilation pass. Physical touch, rotation,
VoiceOver and display compositing remain device checks.

## Rounded gameplay headers

iOS gameplay applies the system's horizontal corner-adapted safe area to the
status text and top Menu target. On iOS 27.1 and later, also honour the top bar
layout region for the 44-point row. Apply only the extra horizontal clearance
inside the ordinary safe area. Keep the playfield and lower controls in place.
All three engines use the same header geometry for pixels, input and accessibility.
L3's native panel retains Menu in its lower navigation row.

The muted, windowless `LemmingsMobileMenuAudit --rounded-hud` check passes 72
rounded-rectangle fixture captures across Classic, Lemmings 2 and Lemmings 3,
portrait, landscape, book, stacked, zero-top-inset and existing-safe-area views.
It checks complete status banks and bitmap fields inside each screen outline,
the 44-point Menu target, hit testing, reserved regions and unchanged gameplay
geometry. Focused layout regressions and both mobile SDK module builds pass.
UIKit's device-supplied corner values, physical touch, VoiceOver and composited
CRT output remain device checks.

## Divided mobile screens

Duo's vertical navigation area holds Menu, rewind, tick steps, release rate,
speed, End run and Pause/Resume. Use the system's preferred bar edge and
corner clearance. Keep the skills together below the minimap and return the
former bottom transport row to gameplay. Play/Resume stays at the bottom of
the side column, with the same height and baseline as the skills. Inset Play
and Pause artwork inside the stone well while retaining the full button target.
Align End run with the minimap row. Secondary side buttons share a 44-point height and the
skill row's two-point gaps, with larger gaps between action groups.
Drawing, touch and accessibility share these rectangles.
Mobile stone backgrounds use a cached 2× reconstruction of the original rock
tile, with its red-brown palette. Tile the finer grain at a fixed size in both
directions so speed and release-rate controls do not stretch it. Preserve the
original panel tiles, bevels, glyphs and selected-state accents.
Classic, L2 and L3 use the same layout. A strip that cannot fit 44-point targets,
or a divided/occluded content region, retains its existing deck.

The muted, windowless Duo audit covers 192 bitmap captures, including left and
right navigation strips, all three engines, paused/running, selected skills,
speed, armed End run and Undo states. It checks target containment, separation,
activation centres and accessible names. UIKit's device-supplied bar geometry,
physical touch and VoiceOver still need device validation.

Simulator exposes an Apple-family-2-like Metal device, including for iPhone Duo.
Do not use that family to disable explosion and fast-forward previews. Allow
the existing bounded overlay budget, shader creation and measured pressure
checks to decide availability. Physical device capability limits, reduced
flashes, low-power and thermal limits still apply. Use the reported EDR headroom
without increasing it artificially. The tested Duo session reports 1.0, so its
effect previews remain within SDR brightness.

Muted, windowless checks in the booted Duo simulator verify Metal pipeline
creation, speed and cinematic explosion activation, touch/precision release,
cancellation, restoration to actual hover and hover exit across Classic,
Lemmings 2 and Lemmings 3. Twelve bitmap captures cover active and released
badges. Adaptive FX policy tests pass, including simulator capability and
physical-device limits. iOS and tvOS shared modules and UIKit regression cases
compile. Full composited effects, brighter-than-SDR output on a physical HDR
screen and real touch delivery remain manual checks.

Duo gameplay spans the upper part of the view. In book view, lemmings remain
visible across both screens, with controls filling the lower part of both screens.
Split buttons, status text and the minimap around the vertical division. In stacked
view, gameplay fills the upper screen and the controls fill the lower screen.
Scale the original pixel artwork with the available control area. Keep input
targets and status text clear of reserved regions. Gameplay may span a vertical
division, with input blocked inside it.
Classic, Lemmings 2 and Lemmings 3 reuse the shared skill, rate, transport and
minimap controls. Native skill sets stay visible together. Compact landscape
uses the two-row deck when the single-row strip would need skill scrolling and
there is enough height. Short phone landscapes retain their scrollable skill bank.

Menu measurement, input targets and drawing use the same viewport height.
Reserve space for details and footer actions before sizing a level preview.
Keep the selected interface size and scroll when the remaining content cannot fit.
Changing the layout retains the existing session and paused Ready boundary.

Mobile and TV level previews fill the interior of their flat frame, with crisp
pixels and no stretching or added padding. Ready and Library use a stable
320 by 160 opening view: the authored Classic camera or the entrance in the
other engines, clamped to the map. Apply this on first presentation and frame
refresh, independent of gameplay zoom and orientation. Pause and results retain
their gameplay camera snapshot and fill the same frame. QR codes fit completely
inside their pane.
The muted, windowless `LemmingsMobileMenuAudit --preview-fill` check covers 48
renders across Classic, Lemmings 2, Lemmings 3 and Cellbash, phone portrait and
landscape, tablet, TV and all interface sizes. It checks opening crops, complete
interior coverage, border containment and Library/Start input targets.
Representative renders, including Cellbash, were inspected. iOS and tvOS SDK
modules compile, and all nine level-preparation regressions pass. The separate
support audit could not decode its unchanged source QR image in the headless
environment, before preview drawing. Physical touch, rotation and TV remote
delivery remain device checks.

The muted, windowless `LemmingsMobileMenuAudit --duo` check passes 156 bitmap
captures across eight poses, all three native engines and all menu interface
sizes. It checks gameplay across both upper panes, lower-area fill, complete
native skill sets, reserved-region containment for controls and status text,
status/minimap separation, target sizes, activation centres and preview actions.
The wider menu audit passes 441 pages, 60 HUD states, 18 native artwork states,
six cover states and three unfold frames. Focused layout and menu regressions
pass, and iOS/tvOS SDK modules compile. Physical Duo folding, rotation, touch,
VoiceOver and composited CRT output remain device checks.

## Fixed TV menus

TV gameplay keeps player identity and shared Mac status information above the
playfield in all three engines. Show released/total, rescued/required, saved
percentage rounded down, time, actual deaths, deaths remaining before failure
or SAFE, supported release rate, speed and the current pause/end state. L3 also
shows reserves. Draw the skull with the shared bitmap glyph because the shipped
menu font has no skull.

iOS and tvOS share one 44-point status row above the playfield. Anchor the player
portrait and green name at the left, with green rescue counts and whole saved
percentage at the right. Use larger score lettering on wide TVs and compact
bitmap lettering on phones. Keep the clock beside the score. Spread supporting
blue statistics through the remaining space in priority order, without wrapping.
Narrow screens keep the player, rescue score and clock first. Full statistics
remain available through accessibility. Preserve all control targets. A system
occlusion or screen division retains its existing unobstructed status bank.

The muted offscreen HUD gate checks 256 phone, iPad and TV renders, complete
visible fields, a shared baseline, non-overlapping targets, visible skull pixels
and L3 extra-death rewind. Another 99 renders cover solo and Hot Seat identity,
all profile portraits, compact and reserved-region layouts. Seven layout
regressions pass. Classic, L2 and L3 use native playfield fixtures; NeoLemmix
uses synthetic status fixtures. Physical television readability, touch, native
focus, VoiceOver and composited CRT output remain device checks.

TV Home uses a fixed landscape board: saved play and Journey on the left,
Classic/fan libraries on the right, sequel logos beneath them, and footer actions
along the bottom. Player identity and compact build/status text remain visible.
Choose the largest whole-pixel scale that fits the safe viewport and disable
scrolling on Home. Keep the scenery behind the bounded board.

TV settings use two-column pages with complete captions. Keep Back at bottom-left
and Previous/Next in fixed footer slots. Groups, individual settings, controller
remapping and soundtrack libraries share this layout. Keep every setting and
Reset action reachable. Retain native focus, accessibility names, selection
underlines and disabled states. Cache fit measurements between page changes.

`Scripts/run-tv-console-checks.sh` passes the muted, offscreen controller
regressions, 153 Classic/L2/L3 experience checks and 250 TV bitmap captures.
The captures include 178 settings pages, safe-area and full 1080p views, 4K safe
areas, all interface sizes, three saved destinations, Hot Seat names, build/status
text, disabled controls and target geometry. Representative renders were inspected.
iOS and tvOS SDK modules and app entry points compile. Physical DualSense
resistance, native UIKit focus delivery, VoiceOver and TV compositing remain
device checks. The diagnostic TV shell retains its separate input implementation.


Level results use both clear screens in book and tabletop layouts. The left
screen in book mode, or upper screen in tabletop mode, keeps the level snapshot,
outcome and existing navigation actions. Its preview fills the available pane
above the actions. The right or lower screen replaces the inactive gameplay
controls with a separately scrollable achievement sheet: rescue goals first, followed by earned awards and reward
receipts with their full criteria and reasons. Filled stars, outlines and question
marks distinguish earned, unearned and unknown goals. Bitmap type and shared
result rules apply to Classic, Lemmings 2 and Lemmings 3. The achievement sheet
keeps the selected text size; the result scales within the available pane to
keep its action shelf visible. Both panes remain available to accessibility in
result-then-achievements order. Each pane avoids the hinge and camera cutouts.
Returning to play or rotating out of a divided layout restores the normal view.
Muted offscreen checks pass 360 captures covering the three engines, all text
sizes, two tabletop sizes, three book poses, wins, partial rescues, failures and
Hot Seat labels.
Goal text, state shapes and action geometry have focused tests. iOS and tvOS SDK
compiles pass. Physical folding, touch scrolling and VoiceOver delivery remain
device checks.

Mac superzoom, skip and Bonus skill counters share the gameplay menu fade in Classic,
Lemmings 2 and Lemmings 3. Use a compact horizontal row of flat readouts with a
magnifier, skip arrow or hammer beside each count. Keep zero and large counts
readable. Show names, balances, purpose and current state in hover popovers.
Place song notices below the row. Show icon help ahead of paused inspection help.
The counters remain passive. Fade the whole badge, including its background
and active marker. Keep its layout and accessibility counts available. Muted
offscreen checks cover visible, partial, hidden and reduced-motion states,
disabled fading and menu input targets.

Free Zoom has no HUD badge. The wheel changes magnification continuously around
the pointer in all three engines. Keep horizontal and modified scrolling for
panning, preserve Superzoom costs and honour reduced motion.

Home offers one Resume journey action for the selected session's saved level or
route. The Journey Map headline counts retained completed levels across the
session. The curated route fraction has its own label inside the route hub.

Both Amiga versus ranks warn before play that two controllers are required
and must remain connected at the same time. Mac briefings use two short bitmap
lines so narrow windows retain the full requirement. Mobile and TV level
selection show the same requirement. Ordinary solo and sequel ranks omit it.
Muted offscreen checks cover Mac briefings at two widths, shared level pages
at phone and wide sizes, accessibility bounds and Back/Play targets.

Mac Hot Seat exposes Ghosts on/off in setup and beside the gameplay menu. The
button uses the shared stone control, a distinct selected state and explicit
On/Off names. Command-G changes the same saved local choice before or during
an attempt. Hide only the previous-player sprites. Retain their recorded turns
and seek them to the current tick when shown again. Preserve Glider/goal keys,
solution ghosts and the paused Ready handover across Classic, L2 and L3.

Mac paused inspection is enabled by default in Gameplay settings. The shared
Inspect lemmings while paused checkbox controls hover details and actor selection
in Classic, L2 and L3. Keep the gameplay Inspect button removed. Command-I opens
the full history while inspection is enabled. Preserve paused Ready handovers.

NeoLemmix one-way arrows follow live terrain edits. Macintosh arrows clip to
the drawn subpixels and share Classic terrain-edge shading and Mac HDR glints.
Retain the original physics masks and clip glints to the same visible arrows.
Display headroom still bounds HDR output. CRT and mobile NeoLemmix retain SDR
arrows until their glint compositing paths are implemented.

Classic one-way arrows always clip to the visible terrain, including converted
Sunsoft objects that omit terrain-only placement flags. Apply the same mask
with HDR off, and with DOS, Macintosh colour or monochrome artwork. Glints
use that mask too. Five focused regressions pass, including the Sunsoft wall
and inspected initial, cut and restored bitmap captures.

Familiar names live in Settings > Privacy. Keep the bitmap name editor, preview,
Apply and Back distinct. Contact selection is a deliberate system-picker action
on Mac and iOS; TV offers manual entry. Preview before Apply, and explain that
Forget removes retained names from saved runs too. Keep privacy wording literal.

On iOS, three-finger tap cycles the installed artwork available to the current
Classic level. Two-finger swipe in any direction requests DJ shuffle in all
three games. Both gestures stay within the playfield and yield to VoiceOver,
which exposes Graphics and DJ shuffle as custom actions. Multi-touch cancels
pending skill assignment; pinch retains zoom. Graphics changes preserve the
run, pause state and future-level Shuffle setting. Mobile Lemmings 2, Lemmings 3
and NeoLemmix do not yet implement artwork switching, so Graphics returns
unavailable for those sessions. Physical gesture delivery requires a device check.
