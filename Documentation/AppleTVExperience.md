# Apple TV experience

The native tvOS app now opens the same frontend as iOS. The TV entry point calls
`LemmingsMobileApplication`; the shared library and game controllers provide the
features. TV adapts focus, remote/controller input and file transfer. It does not
maintain a smaller product menu or separate progression implementation.

The current source exposes the shared official/fan libraries, player-owned
L2/L3 and supported NeoLemmix Preview imports, learning and hints, collections,
profiles, Hot Seat, records, replay, settings, soundtrack and service pages.
Content entries require the same compatible data as iOS. Learning journeys
currently accept Classic entries. Native engine fidelity and device acceptance
remain separate gates.

## Build identity and changes

Home shows the installed version, build number and local build date. The TV
target bundles `BuildInfo.json` in its final build phase, before signing. Each
invocation gets its own identity, so a local rebuild can show its changes even
when its version and build number are reused. The current target is 2.0 build 2.

The Latest build page opens once for each installed identity, before first-run
play-style selection. Continue acknowledges it in device defaults. Opening the
page alone does not. What's New on Home reopens the same bundled notes. The
notice retains the background library/checkpoint load and does not start a game
or change saved-run ownership. All three game engines share this frontend.

Keep `Apps/UltimateLemmingsTV/BuildChanges.json` current with the changes since
the previous distributed build. These are authored notes, not generated Git
commit messages. Build identity describes the installed app and does not check
App Store or TestFlight availability.

Headless checks cover acknowledgement, legacy seen-build defaults, repeated
launches and local rebuilds with reused build numbers. Windowless, muted renders
check Home, Latest build and missing-note fallback at the three TV interface
sizes, with idle/focused states and shared input bounds. TV SDK compilation and
the unsigned arm64 TV Simulator app build pass. Physical remote focus, scrolling,
VoiceOver and first-launch delivery still require a device check.

## Presentation and input

The app uses the shared bitmap fonts, portraits, stone controls, native game
renderers, HUD, pause overview and result pages. Native UIKit focus supplies a
white outline over the exact bitmap action targets. Standard, Large and Extra
Large menu sizes use 2x, 3x and 4x whole-pixel scales. Long pages scroll. Pause
keeps Resume pinned. Transfer pages also scroll so Back remains reachable.

Menus use native TV focus. Carousel left/right selects a level and Select opens
it. Back returns through the shared navigation. The system keyboard supplies
search, player names, playlist names and cloud linking codes.

Gameplay has no on-screen hamburger or Menu button on TV. Siri Remote Back and
controller Options/Menu open the pause menu. The shared HUD omits both the bitmap
button and its input/accessibility target in Classic, Lemmings 2 and Lemmings 3.
Muted, offscreen checks cover 18 active/paused HUD renders at 1920, 1280 and
640-point widths, remaining action targets, scroll-bank clipping and visible
player/counter regions. The tvOS SDK modules and app entry point compile.
Native remote focus and physical controller delivery remain device checks.

Gameplay uses the shared controller bindings. One device owns the attempt
through pause menus until it disconnects or the attempt ends. Page changes
require neutral Select before another activation. Controller cycling locks an
actor ID; crossing neighbours cannot steal the target. A missing or offscreen
locked actor stays unavailable until deliberate aiming or selection.

Siri Remote aims through its directional pad and assigns with Click. Play/Pause
toggles planning/play; Back opens the pause menu. Game controllers use aim/pan sticks,
shoulders for skills and a TV action layer over the shared commands. Settings supports button
remapping, stick swapping, TV aim sensitivity and dead zone. The pause Game
controls page gives remote users skills, targeting, camera/zoom, speed, step,
rewind, applicable rate controls, retry and end/undo actions.

The TV default layout uses PlayStation names with their Xbox equivalents:

| Input | Action |
| --- | --- |
| Cross / A | Assign selected skill |
| Circle / B | Existing Back/reset-speed action |
| Square / X | Pause/play without opening the menu |
| Triangle / Y | Nuke/undo where supported, with the existing arming rule |
| L1/R1 or LB/RB | Previous/next skill |
| L2/LT | Hold rewind |
| R2/RT | Resume planning/rewind pause, tap fast-forward, hold temporary variable-speed boost |
| D-pad left/right | Minimum/maximum release rate where supported |
| D-pad up/down | Increase/decrease release rate where supported |
| Options / Menu | Open/close pause menu |
| L3/R3 | Entrance/goal |
| DualSense touchpad click | DJ shuffle |
| Create / View | Tap for controls help, hold for extra actions |

Create/View plus Cross repeats the last assignment. Circle focuses the last
assignment. D-pad up/down selects the previous/next eligible actor. L1/R1 steps
back/forward. D-pad left/right decreases/increases speed. Triangle opens hints,
Options retries, Square resets speed, R3 opens settings, and L3 shuffles music. Zoom/precision and
Lemmings 2 Fan mode remain on Game controls. Resume occupies its bottom-right
footer. Ready handovers still require the Ready action.

L2 leaves play paused when released. A fresh R2 press resumes from that point
and takes over even if L2 is still held. Release and press L2 again to rewind.
R2 also resumes an ordinary planning pause. Ready, interruption and menu screens
retain their explicit resume action.

Controller mappings, enablement, tap-speed and stick swapping belong to the
current player's profile. Aim sensitivity, dead zone and adaptive trigger feedback
also have separate TV profile preferences. Accessibility keeps UI size, song
notices, reduced motion and reduced flashes with that player. Settings pages,
native session input and Hot Seat turns resolve the same owner. Existing device
preferences seed each profile once. Personal edits retain the legacy baseline
for players who have not yet opened settings. Other device preferences remain
shared. These profile preferences currently persist locally in UserDefaults.

Audio settings offer DJ shuffle: Same track or All tracks. The default keeps the
composition and chooses another available recording or arrangement. All tracks
includes documented gameplay themes across the installed catalogue, including
seasonal themes. If no alternate version is installed, Same track falls back to
another available gameplay theme. The main TV bundle has only one version per
theme, so a manual shuffle still changes the music in an explicit main-scope build.
Normal TV builds bundle all soundtrack libraries, including alternate recordings
and remixes, so Same track can select those versions immediately.
Both modes exclude the current recording, unavailable files,
unverified identities and menu/result cues. Touchpad click and Create/View + L3
request the existing beat-matched crossfade during play. They do not change the
saved soundtrack choice, journey position or gameplay timeline. Muted music,
planning, handover and interruption states cannot start a shuffle.

Touchpad polling reads the named physical button before falling back to Sony's
controller profiles. It uses the shared release gate across menus and owner changes.

TV settings offer Adaptive triggers. On a detected DualSense, R2 resistance
rises with the variable-speed tier. The effect clears on menus, pause,
interruption, disconnect, disabled feedback and remapping R2 away from speed.
Tests suppress trigger effects. This uses Apple's
[adaptive trigger API](https://developer.apple.com/documentation/gamecontroller/gcdualsenseadaptivetrigger),
with physical Bluetooth/firmware acceptance still open. The controller also
exposes touchpad tracking, motion, and optional haptics/light/battery capabilities
through [Game Controller](https://developer.apple.com/documentation/gamecontroller/gccontroller).
This change implements touchpad click for shuffle and trigger resistance; it does not add
motion aiming or controller rumble patterns.

TV controller polling reads game settings once per sample. Cursor/camera input
defers full rendering until the display frame finishes simulation, reuses one
candidate query per render, and skips the hidden reticle count. The CRT playfield
uses at most one render pixel per point while menus/HUD retain native resolution.
The engine clock and physics ticks remain unchanged. Actual Apple TV frame-time
improvement has not been measured on hardware.

Planning pauses and pause menus retain the pointer position. Resume redraws it
at that position immediately. The square corner reticule stays at the input
position over terrain and HUD controls, including empty and unavailable targets.
Camera movement and actor tracking do not move it. Deliberate actor selection
places the pointer once, then the actor highlight follows the selected lemming.
Stick movement releases the actor lock and refreshes targeting while paused.
This shared path applies to Classic, Lemmings 2 and Lemmings 3. Headless engine
checks cover paused movement, resume position, actor-lock retention and unchanged
physics ticks. Eight bitmap checks verify centred square corners over empty,
eligible, unavailable and HUD states at 1x/2x. The shared tvOS UI and app entry
point compile against the TV SDK. Native UIKit/Game Controller delivery and
physical TV timing still need device validation.

Apple TV omits completion light: the golden border, scenery blur, rescued-sprite
auras and their animation timer. It also omits the separate speed/cinematic
explosion surface and extra explosion cores/flash masks. Original explosion
spray, selection and assignment feedback remain. These limits apply through the
shared playfield to Classic, Lemmings 2 and Lemmings 3.

TV starts CRT effects at balanced quality, or minimal on two-core devices.
Sustained CPU or GPU pressure lowers the shared budget. Minimal quality removes
all three CRT bloom passes and their scratch textures. A presentation target
below 60 Hz also disables bloom. Bloom returns only after measured recovery.
Thermal limits also remove bloom immediately. This is a
conservative TV presentation policy following reported completion-glow slowdown.
It is not physical-device performance acceptance. iPhone, iPad and Mac now use
only a faint pixel border for rescue feedback. Their other full-screen effect
policies retain their existing budgets. Jubilant music starts its same-composition
lift immediately when the rescue target is secured, subject to the player's
alternate-soundtrack preference and available arrangements.

Before assignment, TV refreshes the target for the actual selected/repeated
skill. Successful assignment, rewind and deliberate camera movement clear stale
actor locks. A lost locked actor still cannot silently redirect an assignment
to a neighbour. The reported intermittent Classic failure remains subject to
device confirmation after these changes.

The L2 pause page offers Fan/Skill mode. Assignment toggles blowing at the aim
point. Aim movement moves an active fan. Skill selection, planning and lifecycle
interruption release it. Fan events belong to the native input history and
survive checkpoints and rewind. L3 uses the shared eight-direction tool picker.
L2 and L3 do not expose release rate. L3 ends attempts without a nuke.

## Shared players and recovery

Profiles, collections, records and solo progress retain shared mobile ownership.
On Players, tap Select to switch players. Hold Select on a player to open Edit
player without switching the current player or Hot Seat. New player and Edit
player share the initials and portrait controls. Select Initials to open the
system keyboard. Edit player also offers Delete with a separate confirmation.
The last player and an owner of a running attempt cannot be deleted. Parked
solo checkpoints do not block deletion. Confirmed deletion removes the player's
solo checkpoints and backups, records, profile files and Hot Seat membership,
then requests cloud sync. Cloud deletion markers prevent an offline device from
restoring that player. VoiceOver offers an Edit player custom action.

Headless checks cover editor, creation, confirmation and disabled deletion
renders and target bounds at all three TV interface sizes. Checkpoint deletion
cases cover Classic, Lemmings 2 and Lemmings 3 envelopes and legacy ownership.
Physical Siri Remote/controller holds, keyboard return, VoiceOver activation
and live cloud deletion still need device acceptance.

Hot Seat shares its roster, house rule, history and campaign scope with iOS.
Every incoming turn waits at Ready, and failed saves block turn changes.

The upgrade imports the old TV profiles, portraits, selected player, completion
marks, sessions, exact turns and applicable preferences. It imports the surviving
checkpoint with its engine, tick, camera, owner and scope intact. It retains the
old data, respects existing shared saves and never recreates a retired run.
Unknown source progress stays in the original document. Historical scores or
achievements cannot be reconstructed from completion marks alone.

Small roster/session metadata uses UserDefaults. Larger files use TV Caches and
can be purged. Shared cloud-library linking/recovery routes synchronise their
supported progress and records. They do not yet back up complete checkpoint and
collection files. Cloud saves now offers Back up TV saves and Restore TV saves
as an off-device file equivalent. The `.lemmingstv` archive keeps checkpoint,
collection, playlist, learning, campaign and roster JSON plus applicable
preferences. Restore stages files and retains the previous folders. The archive
is bounded to 64 MiB and excludes game content, soundtracks, exported movies and
credentials. Players must download a backup before eviction and reimport
compatible game content when necessary. This is an explicit file backup,
not an automatic cloud checkpoint service. Physical purge/restore acceptance
remains open. Apple's [TV storage guidance](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/iCloudStorage.html)
explains the need for off-device recovery.

## File transfer and services

TV replaces the iOS document picker/share sheet with a temporary, token-protected
LAN transfer page. Another device uploads a game folder or recovery key, or
downloads a replay movie/key. Uploads stream into staging. The shared validators
install valid content. Cancellation closes connections and cleans staging.
The app declares its local-network purpose. Physical permission, transfer,
cancellation and recovery journeys remain unverified.

Game Center uses the shared adapter and a TV entitlement. Production app/board
configuration and signing still need validation. Shared community rankings,
consent, Play Insights and soundtrack downloads retain their iOS behaviour.
Audio uses the shared music director and native sound banks. Automated checks
remain silent; listening acceptance requires a separate explicit request.

## Build and validation

The aim cursor scrolls the camera near each playfield edge in Classic,
Lemmings 2 and Lemmings 3. Corners scroll both axes. Scrolling continues while
planning, with the cursor fixed and the simulation paused. The top and side
safe-area borders retain edge scrolling. HUD targets,
letterbox margins, menus, Ready handovers and suspended play do not scroll.
The shared frontend and historical diagnostic frontend use the same viewport
edge calculation. Muted headless checks cover all three engines, camera bounds
and target geometry. Physical remote/controller edge scrolling remains a
device check.

Open `Apps/UltimateLemmingsTV/UltimateLemmingsTV.xcodeproj` and build the
`UltimateLemmingsTV` scheme. Classic development content uses
`TV_LOCAL_CLASSIC_DATA_DIR`; packaged content uses `TV_BETA_CONTENT_DIR`.
The shared catalogue packager adds available official/fan content. Imported
sequel and NeoLemmix data use the same staging and validation as iOS.
Artwork uses `TV_MAC_ARTWORK_DIR`, effects use `TV_AMIGA_SOUND_DIR`, and soundtrack
scope uses `TV_MUSIC_SCOPE` (full by default, including all soundtrack libraries;
main is an explicit smaller-bundle override).

`Scripts/check-tvos-sdk.sh` compiles all shared dependencies, including
`LemmingsMobileUI`, then checks the TV application entry point.
`Scripts/check-tv-experience.sh` runs native checks through the offscreen, muted
runner and checks both historical and shared frontend bitmap states/targets.
The historical explicit-source TV controller remains available for diagnostic
fixtures; it is not the normal app frontend.

[Current parity register](../Apps/UltimateLemmingsTV/IOSParity.md) distinguishes
implemented routes from unverified behaviour. [Shared frontend evidence](ReleaseReadiness/TVSharedFrontend-2026-10-14/README.md)
records current checks. [Original TV evidence](ReleaseReadiness/TVExperience-2026-10-14/README.md)
remains historical. Native UIKit focus, physical remote/controller/VoiceOver,
signed installation, live services, 1080p/4K timing, memory, thermal behaviour,
audio and purge recovery are still acceptance requirements.
