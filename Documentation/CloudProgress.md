# Cloud saves

Ultimate Lemmings syncs a private player library across Mac, iPhone, iPad, Duo and Apple TV.
The library includes each player's name, portrait, progress, fan-level completion
identities, result records, scores, times, achievements and saved Hot Seat campaigns. Classic, Lemmings 2
and Lemmings 3 use the same archive and merge coordinator.

## Player flow

Cloud saves run automatically in normal builds. Local saves finish first. Play
continues without connectivity. Saves retry on foreground activation, local
changes and every 30 seconds. Returning to a safe menu applies incoming progress.
Normal startup retires the old manual pause preference. Automated integration
builds keep sync off, and muted mechanical tests never start Apple transports.

Devices on the same iCloud account discover the library automatically. No
Game Center login, code, recovery file or manual sync action is needed.

### Public device linking in 2.4

Open **Ultimate Lemmings → Cloud Saves…** on Mac or **Settings → Privacy →
Cloud saves** on iPhone, iPad, Duo or Apple TV. Choose **Link device** on the
first device. Choose **Enter code** on the second device, enter the 12-character
code, then choose **Link device**. The code expires after ten minutes and works
once. Both devices retain their existing player identities and progress.
Incoming progress waits for a safe menu. Linking does not select a player,
start gameplay or unpause a handover. Mid-level checkpoints remain local.

The public page has no shared tester join action. Existing tester credentials
remain readable. A tester library displays its separate status and cannot
create or redeem a private device link. The legacy tester API remains available
for controlled testing; it must not become the public setup path.

Local saves finish before uploads. Launch, foreground activation and local
changes request sync. Mac quit allows up to 20 seconds for a final pass.
Mobile and TV request system background time. Force-quit, network failures and
expired background time can prevent completion; the next load retries.

Public Mac packaging now requires a Developer ID profile with the shared
CloudKit container and Production environment, independently of Game Center.
The owner supplied a production Developer ID profile on 31 October. It grants
the shared container and matches an installed signing certificate. Explicit and
automatic profile checks pass. Management access now works. The 31 October
schema export found `ULPrivateLibrary` in Development but absent from Production.
Production schema deployment remains required. See the
[2.4 sync release gates](ReleaseReadiness/2.4-build104/CloudSync.md).
These source changes do not establish public iCloud availability.

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

Keychain and iCloud account access run on a background actor. Cloud snapshot
decoding, encryption and file persistence run in background tasks. Credential
writes merge existing keys so an older discovery cannot erase a newly saved
password link. Profile and Hot Seat imports retain their safe-menu checks and
paused handovers.

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
decrypt the credentials. A sync password derives a library identity with
PBKDF2-SHA256 (600,000 rounds) and then HKDF. The server receives the derived
vault UUID and the bearer credential. It never receives the password or the
encryption key. The device stores the derived identity in the Keychain next to
its own library key. Background Keychain reads, updates and additions suppress
authentication dialogs. On macOS, `BackgroundKeychain` also disables interaction
with the file-based login Keychain. `LAContext.interactionNotAllowed` alone does
not cover that Keychain. The process-wide flag is serialised across cloud saves
and community records, then restored after each operation.

Ad hoc Mac builds have a different code identity after each rebuild. A login
Keychain item authorised for an earlier build can therefore refuse access.
Developer ID releases retain a stable signing identity across updates, but
background access must still handle locked or inaccessible credentials without
prompting. Refused access preserves existing keys and local saves. It never
creates replacement credentials for an unreadable item.

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
Journey queues, their current position and Mac L2 carry-over snapshots now travel
with that same session. Completed/cleared queues carry a timestamped empty state
so an older device cannot resurrect the map. Mac keeps solo and each Hot Seat's
lesson progress separately. Previously mixed Mac lesson history cannot be
reliably assigned back to old sessions and remains in the legacy solo history.

Home and Journey actions resolve only the selected session. They never fall
back to another solo run or saved Hot Seat. A current non-journey run hides the
Journey Map; saved sessions remain reachable through explicit saved-session
navigation. Opening a map never starts a new solo session. Context changes cancel
pending journey preparation and invalidate callbacks from the previous session.

Imports wait for a safe library menu. Live levels, Ready screens, result
handovers and native sequel sessions keep their current state. Sync cannot
start a level or unpause a handover. A revision check defers imports if local
data changed while a cloud fetch or merge was running.

## Scope limits

The 2.1.2 work captures mobile L2/L3 campaign files even when no learning file
exists. Solo and Hot Seat campaigns use separate storage scopes. Opening a
sequel merges imported shared progress through the existing whole-chain rules
before loading the campaign. Source checks do not establish live device sync.
See the [shared checklist](ReleaseReadiness/2.1.2Checklist.md).

Mid-level checkpoints, non-journey playlist queues, replay movie files, custom
campaign files, imported paths and device settings remain local. Journey lesson
queues, positions, wins and deferred lessons sync in their owning solo or Hot Seat
scope. Both devices need the updated archive reader for journey snapshots.
The mobile journey adapter still plays Classic steps only. Sequel steps and
Mac L2 carry-over data are retained, and an unavailable step never switches to a
solo session. Native sequel playback and live device propagation need manual
verification. A new platform must implement the
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

### Live deployment — 21 October 2026

The encrypted-save service is deployed at
`https://glasscode.academy/lemmings-api/cloud`. Public health returns version 2
with status `ok`. Eight server checks pass. The public smoke check verifies
opaque-byte round trips, authentication, conditional writes and one-use links,
then removes its temporary vault. The smoke client sends an application user
agent and removes a vault only after creating it successfully.

The installer retained nginx and service configuration under
`/var/backups/lemmings-cloud-configuration/20261021T073143Z`, validated nginx
syntax and enabled the isolated systemd service. Existing rankings and telemetry
routes retain their configuration. The earlier hosted-service deployment gate
below is superseded by this deployment. Physical-device propagation and iCloud
entitlement gates remain separate.

Canonical-save maintenance archives retired checkpoints outside the active save
folder and clears only saved-run pointers. It preserves result records, replay
files, completion histories and settings. Imported Classic completions whose
assets changed can retain their original hashed source namespace and exact
`passed:Rank#position` identity in learning history. These identities preserve
completion evidence without granting a win on a different current asset revision.
They contain no imported filesystem path.

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

At this earlier gate, the hosted endpoint was configured in both app plists and
its deployment package was prepared locally. The service had not been deployed. Automatic
approval review rejected upload to `glasscode.academy` pending explicit user
authorization for that destination. The hosted provider remained offline until
the authorised 21 October deployment above.

The installed iOS development profile allows the shared iCloud container. The
installed Mac development and iOS App Store profiles still need the container
enabled and refreshed. See the Game Center document for signing gates. Physical
Mac/iOS iCloud propagation, authentication and account changes still require
device testing; fake transports and compilation cannot establish those results.

Validation completed locally:

- 26 focused app-core checks cover the library, CloudKit transport and
  profile identity. They include two devices, matching names, portraits, scores,
  achievements, offline results, deletion, safe-menu deferral, local mutation,
  all three campaign progress formats, shared turns, offline Hot Seat forks,
  encryption integrity and separated link keys.
- Four native UI checks run offscreen with muted test audio. They render eight
  tester states at four sizes and check 44-point targets, disabled/enabled states,
  primary actions, keyboard input and accessibility targets. Evidence is generated
  in `.build/cloud-ui-evidence`.
- Eight service checks cover authenticated reads/deletion, conditional writes,
  independent device slots, retry safety, expiry, one-use links, bounds and
  backup restoration.
- Fifteen existing-store and mobile Hot Seat checks cover saved-file round trips,
  participant access, imported turn rules and preservation of the selected mode.
- Mac sources compile. The edited iOS/tvOS controller sources parse for their
  device targets. Full device SDK compilation and live propagation remain
  unverified for this change. No foreground window or audible test was used.

The privacy manifest declares library/device identifiers and gameplay content
for app functionality, linked to the private library with no tracking. The Mac
packager includes the same manifest. Before App Store distribution, align App
Store Connect disclosures and the published privacy notice with the hosted
storage. These categories follow [Apple's collected-data definitions](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype)
and [privacy manifest structure](https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest).

## Tester library validation — 19 October 2026

Muted offscreen checks verify one-button setup, persistence across relaunch,
identical `test99` library identities, all-player capture while another profile is
selected, and two saved Hot Seats with different hosts and turns. The fake-server
round trip includes Classic completion, fan flags, L2 carry-over progress and L3
progress without selecting either saved session. Existing Journey queue, offline
branch and safe-menu tests remain in the focused check set. Live iCloud/hosted
propagation and tester-device activation still require updated installed builds.

## 2.0.8 delivery states

Tester Sync displays the coordinator's delivery status separately from its
stored On state. Back is the primary action after setup. A partial library read
or upload stays pending. Saving progress or linking another library during an
upload also stays pending and requests another pass. The last successful sync
time advances only after a complete safe-menu pass.

Focused fake-transport checks cover partial read/write recovery and progress
saved during upload. Native and shared bitmap checks cover offline, pending,
syncing and synced states. See the
[2.0.8 source record](ReleaseReadiness/2.0.8-build92/README.md) for exact scope
and the remaining live-service and device checks.
