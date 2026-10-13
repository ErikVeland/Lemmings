# Cross-device progress

Mac and iOS share a GameKit saved-game archive in
`iCloud.academy.glasscode.lemmings`. This is private progress storage, separate
from Game Center leaderboard submissions and the opt-in hosted rankings.
GameKit requires an authenticated Game Center player, an iCloud account and
[iCloud Drive](https://developer.apple.com/documentation/gamekit/saving-the-player-s-game-data-to-an-icloud-account).
Both devices must use the same Game Center and iCloud accounts.

## Scope and ownership

The first authenticated account links to the device's main local player. Cloud
archives use a SHA-256 hash of the persistent Game Center `teamPlayerID`, which
is shared by the two apps under team `54WU29TRTY`. Device-specific profile IDs,
initials, portraits and replay paths are removed from the archive. Other local
players do not upload into that account. Existing account bindings remain after
profile deletion, preventing the deleted player's save from entering a guest
profile. Switching accounts cannot transfer the previous player's progress.

The archive includes completed levels, campaign unlocks, achievements, records,
attempt statistics and Learning Journey wins and deferred lessons. Native
campaign progress covers Classic, Lemmings 2 and all three Lemmings 3 tribes.
Mac and iOS Classic menus share completion indices for official releases.
The Mac converts those indices into rank unlocks with the actual campaign data.
Older Mac Learning Journey history enters the archive when its journey or
playlist store is opened; subsequent journey results update it immediately.

Unfinished level checkpoints, active Learning Journey queues, saved playlists,
Hot Seat rosters, turns, campaign sessions, replay movies, imported campaign
paths and device settings stay local. This version does not resume an unfinished
level on another device. Native L2/L3 gameplay presentation on iOS retains its
existing engine limits; storing their progress does not add that presentation.

## Merge and recovery

Local writes complete before upload. The service fetches and validates every
cloud version before writing a replacement. GameKit conflict callbacks retain
all versions for the next merge and `resolveConflictingSavedGames` replaces them
with the combined archive. Failed fetches, malformed data, unknown versions and
owner mismatches never overwrite the cloud save. Cloud archive encoding and merging
run away from the main actor. Local revisions and the account are checked again
before an import or upload.

Completed levels and achievements merge by union. Immutable result, start and
attempt UUIDs suppress duplicates. Modern attempt counts use the union of events;
older counters without event history retain the larger observed legacy count.
That conservative rule cannot reconstruct distinct old attempts on two devices.
Skips merge by level, with cleared levels removed from the skip set. Concurrent
spending cannot create extra skip credits; the local balance remains clamped at
zero when those spends exceed the available credits.

L2 survivor carry-over is one coherent chain per tribe. Merge selects the farther
chain, then its final surviving population, medals and total rescues, with a
stable tie break. It does not combine incompatible starting populations from
different runs. Alternative result records remain available in the history.
L3 keeps the farthest campaign cursor and best completed survivor counts.
Learning wins take precedence over deferred visits. Ordered achievement cursors
remain independent of unordered completed levels.

Cloud imports wait until the library or a safe menu. A live level, results-to-next
handover, paused Ready screen and native sequel session keep their local state.
Authentication UI also waits for a safe menu. Upload failures retry after 30
seconds; app activation, authentication changes and local saves trigger another
attempt. Tests with `LEMMINGS_TEST_AUDIO=muted` disable real GameKit access and
system authentication UI.

## Signing and deployment gates

Both bundle IDs must authorize the same container with iCloud Documents:

- Mac: `academy.glasscode.lemmings`.
- iOS: `academy.glasscode.lemmings.ios`.

The app entitlements request `CloudDocuments` and the shared iCloud and ubiquity
container identifiers. The iOS Xcode target enables iCloud. The Mac capability
signer enables `LemmingsCloudProgressEnabled` only if its selected profile allows
these entitlements. Other Mac builds keep cloud progress disabled. The iOS archive
and export checks require the container in both the signature and provisioning
profile. A Developer ID Mac build retains local progress because Game Center is
an App Store service.

On 13 October 2026, the installed iOS development profile authorized this shared
container. The installed Mac development and iOS App Store profiles did not.
Refresh those profiles after enabling iCloud Documents and assigning the shared
container to both App IDs. Verify the finished signatures before distribution.
The use of `teamPlayerID` also requires the corresponding App Store Connect
privacy disclosure; see [Apple's scoped identifier guidance](https://developer.apple.com/documentation/gamekit/protecting-the-player-s-privacy-using-scoped-identifiers).

## Validation

Focused checks use a fake saved-game transport through the offscreen, muted
`Tools/UITestRunner/run.py`. They cover two devices with different local player
IDs, conflicting saves, repeated receipt, offline recovery, deferred import,
account switching during a fetch, corrupt/future/wrong-owner saves, read-only or
externally changed local files, deleted linked players, local mutations during
merge, preference whitelisting, Classic unlocks, L2 chain coherence, L3 results
and Learning Journey queue preservation. All 20 focused cloud, online-service and
store round-trip checks pass. Mac and arm64 iOS sources compile.

Live Apple authentication, iCloud propagation and conflict callbacks still need
a provisioned Mac and a physical iOS device. Check a first restore, independent
offline completions, reconnection, account changes, iCloud Drive disabled, and
native sequel restoration against real bundled campaigns. These checks cannot
be established by fake transport tests or a successful build. No live cloud save
or Apple-side provisioning change was made during this implementation.
