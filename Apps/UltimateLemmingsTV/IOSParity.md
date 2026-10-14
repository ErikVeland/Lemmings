# Apple TV / iOS parity acceptance gate

**Status: shared frontend connected; acceptance gate open.**

Baseline: the local iOS and tvOS source on 14 October 2026. The checkout has
uncommitted changes. This record describes the current implementation and its
validation boundaries, rather than a shipped TV release.

Full applicable iOS parity remains required. The normal TV entry point now uses
`LemmingsMobileApplication` and `MobileLibraryViewController`. It shares the
mobile game controller, native libraries, models, bitmap pages, settings,
collections, records, teaching, audio and service orchestration. Supplying
explicit `TVLibrarySource` fixtures still opens the original TV development
shell. That diagnostic path is not the normal application or the parity baseline.

## Current source coverage

| Area | Shared implementation and TV adaptation | Remaining acceptance |
| --- | --- | --- |
| Content | Shared official Classic releases, Holiday, Oh No, Oh Yes, fan catalogue and updates. L2/L3 and supported NeoLemmix Preview use the same player-owned import validation and native factories. TV imports folders through a temporary token-protected LAN transfer. | Physical import, unavailable data, update and full-pack journeys. A library requires compatible installed or bundled content. |
| Browsing | Shared search, progress, source identity, previews, favourites and playlist actions. TV carousel supports focused left/right selection and Select. | UIKit focus delivery, system keyboard and large catalogues on TV. |
| Learning and hints | Shared Journey, progression, techniques, saved-run lookup, actual progressive hints and matching verified Classic solutions. Hints no longer opens the old Controls deck. | Physical navigation and recovery. Journeys currently accept Classic entries, as on iOS. Sequel hints remain general coaching. |
| Collections | Shared favourites, recents, editable playlists, random/shuffle and queue resume, with the same profile/Hot Seat scope. | Complete controller-only editing and resume journeys. |
| Profiles and Hot Seat | Shared profile management, portraits, both house rules, saved sessions, restart, solo/shared switching, roster recall, attempt-owner records and paused Ready handovers. Save failures retain the transition screen. | Native focus, held-input transitions and physical cross-engine handovers. |
| Gameplay | Shared Classic, L2, L3 and supported NeoLemmix sessions, retry/continue, end/undo, supported rate, speed, step and rewind. A TV Game controls page exposes touch HUD capabilities to the remote. L2 has shared fan mode; fan inputs replay in checkpoints and rewind. L3 uses the shared eight-direction tool picker. | Full native game journeys, controller/remote precision and engine fidelity. L2/L3 expose no release rate. L3 has no nuke. |
| Targeting and ownership | TV retains its gameplay controller through pause menus. Deliberate actor cycling locks the actor ID until aiming or another deliberate selection. Missing/offscreen actors cannot silently retarget a neighbour. Held Select cannot accept a new page before neutral input. | Physical multi-controller and Siri Remote generations, including the virtual iPhone remote. |
| Pause/results | Shared frozen overview, counts, loss allowance, time, supplies, track identity, results, awards and named next actions. Resume remains pinned on the shared pause page. | UIKit scrolling/focus, result variants and VoiceOver. |
| Replay | Shared supported recording, read-only playback, skill-use history and movie export. TV exports movies through the LAN transfer instead of a share sheet. | Physical playback, movie download and cancellation. Sequel verified-solution/movie capabilities remain bounded by the shared session APIs. |
| Records/services | Shared records, achievements, community boards, Game Center adapter, telemetry consent and Play Insights. TV declares the Game Center entitlement. | TV App Store Connect/provisioning, production boards, account consent and live service journeys. No production account settings were changed. |
| Settings | Shared groups, presets, graphics, display/effects, accessibility, soundtrack and controller remapping. TV retains sensitivity/dead-zone choices. Standard/Large/Extra Large use distinct whole-pixel menu scales. New TV preferences select continuous skill changes. | Physical runtime effects, long menus and accessible focus. |
| Audio | Shared Adaptive DJ, soundtrack selection/downloads, native sound banks, track notices, pause/speed/rewind and interruption rules. | Audible comparison needs an explicit request. Engine/data limits remain shared with iOS. |
| Recovery/cloud | Shared owner/session-scoped checkpoints and session navigation. Legacy TV profiles, portraits, solo/shared completion, rosters, exact turns, preferences and the surviving checkpoint migrate once. Old data is retained, and an existing shared run is not overwritten. Shared cloud-library/recovery-code routes are available; TV transfers recovery keys over LAN. | Live cloud linking and purge recovery. Cloud library sync does not back up complete checkpoint payloads or all local collection files. TV adds an explicit off-device save backup/restore adapter; transfer and purge recovery need physical acceptance. |
| Accessibility/lifecycle | Shared accessible action names, interruption pause and explicit Resume. TV uses native focus over the same bitmap targets. Large transfer pages scroll to keep Back reachable. | Physical VoiceOver, system keyboard, background/termination/reconnect and sofa readability. |

## Storage and migration boundaries

The 14 October profile/cloud follow-up moves Edit into the player list, retains
native focus targets during redraws, and marks the Hot Seat host as locked.
Guests can be deselected before Choose a game starts or continues a session.
All engines use this shared roster flow. Shared cloud progress now has a CloudKit
adapter for TV, Mac and iOS. GameKit saved games are unavailable on TV. CloudKit
provisioning, production schema deployment and physical device sync remain open.
See [cloud progress](../../Documentation/CloudProgress.md) for the setup limits.

TV uses Caches for larger local files, including content, collections, records,
journeys, soundtrack downloads and checkpoints. Small profile/Hot Seat metadata
is retained in UserDefaults, with a bounded document size. tvOS may evict cached
files. A recovery key links cloud library progress; it does not restore every
local file or a mid-level checkpoint. Cloud saves also offers Back up TV saves
and Restore TV saves. The bounded `.lemmingstv` archive includes checkpoint JSON,
player/session metadata, collections, playlists, learning state, native campaign
records and applicable preferences. It excludes commercial data, soundtrack
files, exported movies and service credentials. Restore stages files, focuses
Cancel in its confirmation, retains the previous folders and recreates stores
only after the transaction succeeds. Backups are explicit and must be downloaded
to another device. They are not an automatic cloud checkpoint service. Reimport
compatible player-owned game data if TV evicts it before resuming. Do not promise
automatic or cross-device mid-level Resume without separate validation.

The old `tv.localState` defaults and original checkpoint files are retained.
Migration markers advance only after successful migration. A completed migrated
run cannot be reimported on the next launch. Existing shared-frontend preferences
and current runs take precedence. Old completion marks do not invent historical
scores, times or achievements. Unknown legacy source progress remains in the
retained original document. Corrupt/future checkpoints are kept and reported.

Apple documents TV storage in [iCloud Storage](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/iCloudStorage.html).

## Validation

See [shared frontend evidence](../../Documentation/ReleaseReadiness/TVSharedFrontend-2026-10-14/README.md).
The prior 94 core checks and 76 menu renders covered the original TV frontend.
They cannot close this gate. Current checks compile the shared UI and cover the
migration, input gates, actor lock, fan state and shared bitmap targets. They do
not dispatch native UIKit focus events or establish physical TV acceptance.

Use `Tools/UITestRunner/run.py` in offscreen, muted mode for native checks.
Do not launch a foreground/secondary-display test or audible playback as a
fallback. SDK compilation and the Xcode app build do not establish parity alone.
