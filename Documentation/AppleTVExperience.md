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

## Presentation and input

The app uses the shared bitmap fonts, portraits, stone controls, native game
renderers, HUD, pause overview and result pages. Native UIKit focus supplies a
white outline over the exact bitmap action targets. Standard, Large and Extra
Large menu sizes use 2x, 3x and 4x whole-pixel scales. Long pages scroll. Pause
keeps Resume pinned. Transfer pages also scroll so Back remains reachable.

Menus use native TV focus. Carousel left/right selects a level and Select opens
it. Back returns through the shared navigation. The system keyboard supplies
search, player names, playlist names and cloud linking codes.

Gameplay uses the shared controller bindings. One device owns the attempt
through pause menus until it disconnects or the attempt ends. Page changes
require neutral Select before another activation. Controller cycling locks an
actor ID; crossing neighbours cannot steal the target. A missing or offscreen
locked actor stays unavailable until deliberate aiming or selection.

Siri Remote aims through its directional pad and assigns with Click. Play/Pause
opens pause; Back opens the pause menu. Game controllers use aim/pan sticks,
shoulders for skills and the shared modifier actions. Settings supports button
remapping, stick swapping, TV aim sensitivity and dead zone. The pause Game
controls page gives remote users skills, targeting, camera/zoom, speed, step,
rewind, applicable rate controls, retry and end/undo actions.

The L2 pause page offers Fan/Skill mode. Assignment toggles blowing at the aim
point. Aim movement moves an active fan. Skill selection, planning and lifecycle
interruption release it. Fan events belong to the native input history and
survive checkpoints and rewind. L3 uses the shared eight-direction tool picker.
L2 and L3 do not expose release rate. L3 ends attempts without a nuke.

## Shared players and recovery

Profiles, collections, records and solo progress retain shared mobile ownership.
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

Open `Apps/UltimateLemmingsTV/UltimateLemmingsTV.xcodeproj` and build the
`UltimateLemmingsTV` scheme. Classic development content uses
`TV_LOCAL_CLASSIC_DATA_DIR`; packaged content uses `TV_BETA_CONTENT_DIR`.
The shared catalogue packager adds available official/fan content. Imported
sequel and NeoLemmix data use the same staging and validation as iOS.
Artwork uses `TV_MAC_ARTWORK_DIR`, effects use `TV_AMIGA_SOUND_DIR`, and soundtrack
scope uses `TV_MUSIC_SCOPE` (main by default; full includes optional libraries).

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
