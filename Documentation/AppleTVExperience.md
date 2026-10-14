# Apple TV experience

Ultimate Lemmings has a native tvOS app target for playing from the sofa with a
Siri Remote or game controller. Classic has a playable development flow. The
shared controls also run against the native Lemmings 2 and Lemmings 3 sessions.
Their TV campaign libraries and complete renderers remain release gates.

## Presentation

The TV interface uses the shipped Macintosh lettering, portraits and stone
controls. UIKit supplies focus, activation and accessibility over the exact
bitmap control rectangles. Focus has a white outline, selection has an
underline, and the primary action has a green rim and forward marker.
Disabled actions remain visible and dimmed.

Menus reserve space around their edges for focus outlines and cropped TV edges.
Controls use whole pixel scales. Large menu text preserves the same lettering
across peer actions. Result buttons separate the action from the incoming
player's name when large text needs more room.

The library opens by game, rank and level. A briefing frames the playable area
and shows the native rescue requirement and time limit. Start or Ready begins
the shared 3–2–1 countdown. Saved runs wait at Resume and skip the fresh countdown.
Pause or single-step cancels automatic start. App interruptions hold it.

The playfield has a compact skill strip, a larger selected skill name, rescue
and time counters, player identity and a minimap. Native Macintosh gameplay
artwork is the default. The level's own renderer and assignment rules remain
authoritative.

## Controls

Menus use native tvOS focus. Gameplay uses the existing console bindings.
One physical device owns gameplay until the attempt ends or the controller
disconnects. Held buttons cannot accept a new page or assign on a handover.

| Input | Gameplay action |
| --- | --- |
| Left stick or remote directions | Aim with a dead zone and a curve for fine movement |
| Right stick | Pan the camera |
| Primary controller button or remote click | Assign the selected native skill or action |
| Shoulders | Previous or next available skill |
| D-pad left and right | Cycle eligible lemmings |
| Secondary face buttons | Repeat the last skill or focus the last assignment |
| Menu or remote Play/Pause | Pause, or resume after planning |
| Remote Back | Open the paused controls |

The shared extended-controller modifier bindings retain speed, stepping,
rewind, retry and end-run actions. See [Controller QoL](ControllerQoL.md).
Stick swapping and aim sensitivity are available in Settings. Pause on skill
change is optional and off by default.

Cycling locks the chosen actor ID. A crossing lemming cannot replace it.
If that actor disappears or leaves the view, assignment stays unavailable
until the player aims again or chooses another actor.

The pause menu gives remote users access to skills, target cycling, camera
movement, entrance and exit, speed, stepping, supported rewind and release
rate, retry and end-run actions. Choosing a skill returns to a paused playfield.
Camera adjustment cannot assign a skill. Destructive actions focus Cancel.
An active nuke changes its action to Undo nuke.

## Players and recovery

Profiles use the shared player IDs and portraits. The native TV keyboard edits
names. Hot Seat results name the next player, and every incoming turn waits
for Ready. The shared house rule currently uses Every level.

Each checkpoint retains the run ID, native engine and level fingerprints,
simulation tick, selected control, camera, solo owner and Hot Seat scope.
Encoding happens on a worker after the live state is captured. Checkpoints
save periodically, on pause and when returning to the library.

A new attempt saves before it replaces the previous turn. Completed and
replaced runs retire so late writes cannot restore them. App inactivity,
audio interruption and loss of the active controller pause play. Recovery
requires an explicit Resume.

Profile and turn metadata use UserDefaults. Native run payloads use Caches,
which tvOS can purge. Durable cloud recovery must be added before the app
promises persistent or cross-device Resume. Apple describes these storage
constraints in [Explore tvOS development](https://developer.apple.com/videos/play/wwdc2023/10256/).

## Engine support

| Feature | Classic | Lemmings 2 | Lemmings 3 |
| --- | --- | --- | --- |
| Native tick, assignment, checkpoint and Ready gates | Implemented | Core checks pass | Core checks pass |
| Default TV campaign and gameplay artwork | Implemented | Library and renderer pending | Library and renderer pending |
| Release rate | Native | Unavailable in native session | Unavailable in native session |
| Rewind and backward step | Native history | Unavailable in native session | Unavailable in native session |
| End attempt | Nuke and undo | Native nuke | Native end attempt, no nuke |
| Extra native controls | Classic skills | Fan controls need TV integration | Carried tools and directions need TV integration |

The application can register each native library through `TVLibrarySource`.
Unregistered games are disabled in the game picker. Core fixture checks do
not establish complete sequel campaigns or visual acceptance.

## Development and release gates

Open `Apps/UltimateLemmingsTV/UltimateLemmingsTV.xcodeproj` and select the
`UltimateLemmingsTV` scheme. Debug builds use the local Classic development
data. Distribution content uses `TV_BETA_CONTENT_DIR`. Artwork and original
sound banks use `TV_MAC_ARTWORK_DIR` and `TV_AMIGA_SOUND_DIR`.
Soundtrack packaging defaults to the main catalogue. `TV_MUSIC_SCOPE=full`
opts into the larger catalogue.

Run `Scripts/check-tv-experience.sh` for the shared core and rendered-state
checks. It uses the offscreen, muted native test runner. Set
`TV_EXPORT_ASSETS=1` to regenerate the layered app icons and static Top Shelf
artwork from native pixels. `Scripts/check-tvos-sdk.sh` compiles a frozen
source snapshot against the tvOS Simulator SDK.

The current evidence is in [TV validation](ReleaseReadiness/TVExperience-2026-10-14/README.md).
Before release, complete physical Siri Remote and controller trials, sofa
readability checks, VoiceOver and system keyboard checks, 1080p and 4K frame
timing, memory and thermal tests, and signed device installation. Native
UIKit focus events still need automation. Device-specific button prompts,
the remapping editor, teaching flows, broader saved-session navigation,
dynamic Top Shelf Resume and durable cloud recovery remain follow-up work.
Resume currently shows the latest checkpoint's owner. A full saved-session
history and Hot Seat roster summary still need TV pages. The controller's
Hints shortcut opens Controls until the shared learning flow reaches tvOS.

Apple's [focus guidance](https://developer.apple.com/documentation/uikit/adding-user-focusable-elements-to-a-tvos-app),
[controller guidance](https://developer.apple.com/videos/play/wwdc2021/10081/)
and [layered asset format](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/BrandAssetsType.html)
govern the platform integration. The game's [UI principles](UIPrinciples.md)
govern the rendered controls.
