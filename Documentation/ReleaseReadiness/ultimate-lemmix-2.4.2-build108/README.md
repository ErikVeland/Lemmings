# Ultimate Lemmix loaded-asset parity — build 108

The owner requires a complete owned asset pack to restore the full Ultimate
Lemmings experience. The application uses the full 2.4.2 baseline at
`b294d3b7c298f549aad5faa36f92ba9bf23b7529`. NxlvKit remains unchanged, with
fingerprint `9a246f97fd42930d53c273a4bb9c45800f0379fd7326f7c65518d484ebfeeea5`.

## Corrected behaviour

- Complete resource import selects Original artwork and replaces a saved Lix music choice with Original media.
- Original controls use recovered native Amiga pixels, including transparency, Macintosh reconstruction and monochrome conversion.
- All seven Classic campaigns retain their historical progress and catalogue identities, including Oh Yes.
- Exact L2/L3 asset sets retain their legacy save identities after unused DOS drivers are excluded. Changed data still rejects old checkpoints.
- Live resource activation refreshes catalogue counts and retains the imported fan-update feature.
- Complete reimport repairs damaged retained files. Cold restoration verifies the saved resource tree.
- Desk Clock shares selected owned artwork with its separate widget process through the declared App Group.

Application branding, installation identity, distribution updates and service
provisioning remain specific to the separate Lemmix build.

## Evidence

| Boundary | Result |
| --- | --- |
| Complete source pack | 17,740 retained source files match exact bytes and hashes. Two pinned cursors are recovered separately. Total: 17,742 owned files, 2,265,742,871 bytes. Exactly 32 unused executable, driver or Finder metadata files are omitted. |
| Import and repair | Seven focused checks pass after five failures were reproduced. Complete import, cold verification and base rebase pass. |
| Save identities | Nine focused checks pass after four failures were reproduced. Actual native-reference L2/L3 checkpoints restore the imported data. Modified asset sets remain distinct. |
| Original control rendering | 67 exact pixel comparisons pass across colour, transparency, Macintosh, monochrome and multiple scales. The initial comparison found 54 differences. |
| Native lifecycle | Reference resources, live import and a separate cold process pass the same checks. Seven screen captures and their control contracts match across all three phases. A separate restored-run capture is retained. |
| Content | All seven Classic campaign IDs and revisions match. Three NeoLemmix packs and all 794 catalogue entries match. One available Neo level has matching native pixels and typed state. |
| Recovery | Cold Classic recovery retains tick, state, run ID and pause. Hot Seat retains the roster, next turn, session and archived queue position. Home resolves that saved queue. Neo restores by canonical identity with its old path removed. L2/L3 native frames and host checkpoints match. |
| Desk Clock resource sharing | 18 exact native raster comparisons pass using an injected group directory. All 1,402 artwork files and fonts match, totalling 22,619,285 bytes. Clear, fallback, no-op, failed publication and unsafe-path checks pass. |
| Mac packaging | Current-architecture arm64 candidate is in Downloads. Strict deep ad hoc signature verification passes after the final copy. The app and widget both report 2.4.2 (108). |
| Mobile compilation | Separate iOS and tvOS 2.4.2 build 108 device-SDK outputs compile. Desk Clock and Top Shelf remain included. Outputs are unsigned. |
| Review | Independent reviews found no Critical or Important issue in the parity corrections or widget bridge. |

The retained [Mac receipt](mac-manual-build.json),
[native comparison](native-import-reopen.json), [iOS receipt](ios-device-sdk.json)
and [tvOS receipt](tvos-device-sdk.json) identify the completed outputs and limits.
Raw logs, source snapshots and 22 native captures remain under
`.build/ultimate-lemmix-asset-parity` and the focused `.build/asset-parity-*`
directories. The current import content ID is
`145686716edb83924d1e56dbeaa2b37b3311ae69aecc10546a5f3eb1b1bbc8ac`.

## Scope and remaining acceptance

The native lifecycle comparison runs the current full frontend against reference
and restored resources. It does not run the unmodified published executable.
The control matrix compares current builds with the Store condition disabled
and enabled. Unchanged engine code and exact asset bytes provide the underlying
game-rule equivalence.

All native checks ran offscreen with muted audio and isolated preferences,
records and queues. Folder-picker controls were captured. Import used the real
library and completion path without the system picker. No broad corpus or
release audit ran.

UIKit, physical input, audible audio, live cloud services and signed WidgetKit
access remain separate acceptance checks. The widget test uses an injected
directory, not the production App Group. Store signing and provisioning must
associate the app and its widget with the declared group. Asset and icon rights
review remains open for public distribution.

Production builds retain the existing local save location. Quit the earlier
manual build before opening build 108. Tests did not use that production location.
The existing build 107 application was left unchanged.
