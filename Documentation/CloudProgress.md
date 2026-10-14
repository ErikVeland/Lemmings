# Cloud saves

Ultimate Lemmings syncs a private player library across Mac, iPhone and iPad.
The library includes each player's name, portrait, progress, result records,
scores, times, achievements and saved Hot Seat campaigns. Classic, Lemmings 2
and Lemmings 3 use the same archive and merge coordinator.

## Player flow

Cloud saves are on by default in normal builds. Local saves finish first. Play
continues without connectivity, and saves retry when the app returns to the
foreground, after local changes and every 30 seconds. Preview builds keep a
separate local archive and restore the shared cloud library by default. An
existing choice to pause preview sync stays paused. Automated integration
builds keep sync off, and muted mechanical tests never start Apple transports.

Devices on the same iCloud account discover the library automatically. No
Game Center login is required for this library. Different Apple accounts use
**Players → Cloud saves → Link another device** on the existing device, then
**Enter device code** on the new device. The 12-character code works once and
expires after ten minutes. It gives access to the whole library, including all
players and shared campaigns. Linking combines existing libraries; it does not
discard either device's records.

**Save recovery key** exports a private `.lemmingssync` file. **Restore recovery
key** restores access after a device is lost. The key grants access to the whole
library and must be kept private. Without iCloud, a linked surviving device or
a saved recovery key, an account-free library cannot be recovered. There is no
email address or password reset.

Players remain separate even if their names match. A fresh installation restores
the existing primary player. Two installations that already have independent
progress retain both player identities when linked. There is no automatic
name-based consolidation of those players. Copied UUID profiles retain the same
cloud identity. Older cloud identities retain their original UUIDs, and copied
legacy profiles can recover identity from a shared immutable result ID. Empty
progress defaults do not stop a fresh testing build from restoring the primary
player. A participant can open a saved Hot
Seat hosted by another player; opening it restores its host, roster, turn and
turn rule. Sync never switches a device into Hot Seat by itself.

## Providers and credentials

`CloudLibrarySync` uses independent providers through
`AppleCloudLibraryTransport`:

- CloudKit private records in `iCloud.academy.glasscode.lemmings` share library
  keys and encrypted device snapshots across Mac, iOS and Apple TV. The custom
  `ULPrivateLibraryV2` zone uses fixed record names, bounded device manifests and
  atomic conditional writes. It does not require query indexes. Conflicts retry
  against the current manifest, so concurrent devices retain their own slots.
- iCloud Documents in `iCloud.academy.glasscode.lemmings` automatically discovers
  private library identities and encrypted snapshots. This requires an entitled
  and provisioned app with iCloud Drive available. Each device writes immutable
  content-addressed snapshots and retains its latest two generations.
  Mac and iOS retain this provider for existing saves. Their next successful
  CloudKit sync also publishes the existing keys and merged library there.
  Apple TV does not use the document-file provider.
- The HTTPS service at `https://glasscode.academy/lemmings-api/cloud` stores
  encrypted snapshots when iCloud is unavailable and links devices on different
  Apple accounts. A provider failure leaves the other provider usable.

The existing [Game Center progress service](GameCenterProgress.md) remains an
additional bridge for the signed-in player's solo progress. It does not own
other local players or shared campaigns. The Cloud saves switch pauses both
services. Developer ID Mac builds can use the hosted library without Game Center.
GameKit's `GKSavedGame` API is unavailable on tvOS. TV uses the shared library
providers for progress. Cloud-library snapshots still exclude mid-level checkpoints.

Each library has a random UUID, a 256-bit bearer credential and a 256-bit AES-GCM
encryption key. Keys stay in the device Keychain and the private iCloud identity
file or private CloudKit key record. Each device has a random installation UUID. The hosted service stores only
the hash of the bearer credential, opaque ciphertext, device slots and update
times. It has no player names, email addresses or game results in plaintext.
Device-link credentials are encrypted with a key derived from the code; the
server receives a separate, domain-separated lookup digest. That digest cannot
decrypt the credentials. Background Keychain access cannot display an
authentication dialog.

## Merge and safety

Every available snapshot is authenticated and validated before its provider can
receive an update. Unknown formats, unreadable local sync state, corrupt saves
and credential conflicts preserve existing data. A broken provider is not
overwritten through a successful provider. Hosted writes use per-device ETags
and conditional updates; concurrent devices cannot overwrite each other's slots.

Records and attempt events merge by immutable IDs. Completions and achievements
merge by union. Profile metadata uses a deterministic logical clock. Profile
deletion tombstones prevent an old offline device from restoring a deleted
player, including its original UUID when an older build assigned a cloud UUID.
L2 keeps a coherent survivor chain per tribe; it never combines survivor
counts from incompatible runs. L3 keeps the farther campaign cursor and best
completed survivor counts. Legacy counters without event IDs use the larger
observed count rather than guessing how many distinct attempts occurred.

A Hot Seat stores its roster, host, turn, rule and separate progress for all
three games. Each revision records its ancestry. A newer descendant replaces
its ancestor. Divergent offline revisions become separate saved campaigns with
stable IDs. Subsequent progress on either campaign remains independent.
When a copied save has no sync revision file, an identical Hot Seat state reuses
the existing revision. It then receives later descendants without creating a
duplicate campaign. Different states remain separate branches. iOS reads synced
Hot Seat learning progress from the shared session rather than the solo profile.

Imports wait for a safe library menu. Live levels, Ready screens, result
handovers and native sequel sessions keep their current state. Sync cannot
start a level or unpause a handover. A revision check defers imports if local
data changed while a cloud fetch or merge was running.

## Scope limits

Mid-level checkpoints, active Learning Journey or playlist queues, replay movie
files, custom campaign files, imported paths and device settings remain local.
Learning wins and deferred lessons do sync. A new platform must implement the
same archive, encryption and HTTPS contract before it can join the library;
Windows, Android and web clients are not included in this change. Sync does not
add missing iOS L2/L3 gameplay presentation. The library supports eight players,
200 shared campaigns and 32 simultaneous branches per campaign. Hosted storage
allows 32 device slots, 8 MiB per snapshot and 64 MiB per library.

## Profile restoration validation — 14 October 2026

The local CI source gate passes 246 checks with muted audio and offscreen test
settings. The arm64 iOS 16 `LemmingsMobileUI` target compiles. New regressions
cover copied UUID players, original UUIDs from older cloud identities, copied
legacy results, identical Hot Seat revisions, newer shared progress across
Classic/L2/L3, shared learning isolation, preview restoration with empty defaults,
and deletion of original identities. Existing offline-fork and safe-menu checks
also pass. Logs are in `.build/profile-sync-source-gate.log` and
`.build/profile-sync-ios.log`.

These changes are source updates after the published 1.9.6 build 81. They are not
in that app or the exported iOS build 13. Live iCloud propagation still requires
device testing. Existing provider deployment and signing limits below apply.

## Service operations

`Tools/CloudSaves/server.py` runs as an isolated, hardened systemd service on
loopback port 8798. Its nginx route does not change the existing rankings or
telemetry routes. The service does not log request bodies, credentials or IP
addresses. Its SQLite database uses WAL and daily online backups with three
daily copies. Anonymous link requests, connections, payloads, worker threads and
aggregate storage are bounded. Aggregate save storage is capped at 2 GiB;
capacity failures leave games playable and local saves intact.

The installer in `Tools/CloudSaves/deployment/install.py` backs up nginx and
service configuration, checks nginx syntax and service health, then reloads
nginx. Failure restores the previous configuration. `Tools/CloudSaves/smoke.py`
checks the public endpoint with a temporary library and removes that library
afterward. The database, backups and library keys must not enter Git or a public
download. The authenticated API can delete a vault; an in-app whole-library
remote deletion control is not yet implemented.

## Deployment and validation — 13 October 2026

### TV follow-up — 14 October 2026

The hosted `/v1/health` endpoint returned HTTP 404. No service was deployed.
CloudKit support is now in source for all three platforms. The TV/iOS entitlement
files request CloudKit in the shared container. Mac signing enables it only when
the selected provisioning profile permits it. Unsigned Mac builds leave it off.

Before live acceptance, enable CloudKit for each app identifier, refresh the
profiles, and deploy the `ULPrivateLibrary` record type to the production container.
Its fields are `keys` (Bytes), `devices` (String List) and `snapshot` (Asset).
Development schema creation, production schema deployment, signed installations
and physical account/propagation tests have not been performed. These are release
gates, not results established by local compilation.

Twenty-one local cloud checks pass, including four new fake-database CloudKit
checks for discovery, legacy keys, concurrent identity/device writes, encrypted
assets and preservation of unreadable data. All TV SDK modules compile. The
cloud page now reports unavailable providers alongside successful providers.

### Earlier deployment record

The hosted endpoint is configured in both app plists. Its deployment package is
prepared locally; the service has **not been uploaded or deployed**. Automatic
approval review rejected upload to `glasscode.academy` pending explicit user
authorization for that destination. Until deployment, that provider reports
offline and the entitled iCloud provider remains available.

The installed iOS development profile allows the shared iCloud container. The
installed Mac development and iOS App Store profiles still need the container
enabled and refreshed. See the Game Center document for signing gates. Physical
Mac/iOS iCloud propagation, authentication and account changes still require
device testing; fake transports and compilation cannot establish those results.

Validation completed locally:

- 26 focused app-core checks cover the library, legacy Game Center bridge and
  profile identity. They include two devices, matching names, portraits, scores,
  achievements, offline results, deletion, safe-menu deferral, local mutation,
  all three campaign progress formats, shared turns, offline Hot Seat forks,
  encryption integrity and separated link keys.
- Two native UI checks run offscreen with muted test audio. They render eight
  states at four sizes and check 44-point targets, disabled actions, primary
  actions, keyboard input and accessibility code entry. Evidence is generated
  in `.build/cloud-ui-evidence`.
- Eight service checks cover authenticated reads/deletion, conditional writes,
  independent device slots, retry safety, expiry, one-use links, bounds and
  backup restoration.
- Fifteen existing-store and mobile Hot Seat checks cover saved-file round trips,
  participant access, imported turn rules and preservation of the selected mode.
- Mac sources and the arm64 iOS `LemmingsMobileUI` target compile. No simulator,
  foreground test window, audible test or public release build was used.

The privacy manifest declares library/device identifiers and gameplay content
for app functionality, linked to the private library with no tracking. The Mac
packager includes the same manifest. Before App Store distribution, align App
Store Connect disclosures and the published privacy notice with the hosted
storage. These categories follow [Apple's collected-data definitions](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype)
and [privacy manifest structure](https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest).
