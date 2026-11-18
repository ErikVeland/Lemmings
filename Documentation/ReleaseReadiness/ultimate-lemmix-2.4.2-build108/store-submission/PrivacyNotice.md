# Ultimate Lemmix privacy notice

Draft for operator review. Not published. Prepared 18 November 2026 for version
2.4.2, build 108.

Before publication, confirm the deployed retention and hosting arrangements.
The contact address below was verified from the published GenErik DJ site on
19 November 2026. No public Ultimate Lemmix privacy URL was verified.
The retention details below describe the reviewed service source. Public health
responses cannot verify server configuration, backups or provider retention.

## About this app

Erik Veland develops Ultimate Lemmix. The app stores your local players, progress,
settings and imported game data on your device. Local play does not require a
separate hosted account.

Automatic cloud saves help restore progress across devices. Optional count and
record sharing supports play statistics and community rankings. These services
use `glasscode.academy`. Apple provides iCloud and Game Center services.

## Automatic cloud saves

The app synchronises saved progress automatically when a connection and a usable
provider are available. This includes player profiles, completion records, shared
campaign participants, turn ownership and saved journey information. The cloud
library does not include imported game media or mid-level engine checkpoints.

The app encrypts library contents before sending them to the hosted save service.
That service receives encrypted contents, a library identifier, device identifiers
and update information. It receives an authentication credential, which the
service stores as a hash. It does not receive the library encryption key or your
sync password in plaintext.

Library credentials remain in the device Keychain and can also use your private
iCloud storage. Private iCloud stores the identities needed to restore your
library, as well as encrypted saves. A device-link code or a shared sync password
can connect devices that use different Apple accounts. Anyone who receives a
working link or knows that password can gain access to the linked library.

Cloud synchronisation is separate from count-sharing consent. Turning off count
sharing does not turn off cloud saves. Removing the app does not by itself remove
copies already stored with a cloud provider.

## Optional play counts

The app sends play counts only after you choose to share counts and records.
These fixed events describe installation opt-in, active days, level starts and
outcomes, rescued characters and soundtrack choices. They do not include a player
name, email address, Apple account, device identifier, replay identifier or
imported file path.

The counter service combines events into totals. The shared rescue count is
public. Network providers still receive connection information, including your
network address, when delivering requests.

## Community records and replays

Choosing to share counts and records also enables public record sharing for
players without a separate record-sharing choice. You can control record sharing
for each local player. An explicit player choice remains separate from the
count-sharing setting.

Shared records include player initials, scores, run identifiers and gameplay
action replays. The service uses a separate random credential for each player.
It does not require your email address or Apple account. Other players can see
your initials and scores. Eligible leaderboard entries also make action replays
available to other players.

Action replays contain timed game commands and verification information. They
do not contain your imported level assets, calendar events or a video recording
in the current sharing flow.

Turning sharing off stops future automatic submissions. It does not remove
records already shared. Use **Remove shared records** to request removal of
that player's hosted records and replays. If the connection fails, the app keeps
the removal pending and retries it. Removing hosted records keeps local records.

## Game Center

When you use Game Center, Apple processes the sign-in and leaderboard data needed
for that feature. The app can display your Game Center name and scores. On Mac
and iOS, the app also uses Game Center saved games for compatible solo progress.
Apple TV uses the cloud library for saved progress instead.

Game Center and the community ranking service are separate. The community
service does not need your Apple account credentials.

## Calendar, widgets and local transfers

With calendar permission, Desk Clock reads the next relevant event and displays
its title and time. This data stays in the local calendar and display path.
The app does not add calendar events to its telemetry or cloud-library archive.
You can revoke calendar access in system settings.

The app and its extensions share local files for widget artwork and Apple TV
Top Shelf scenery. Apple TV can receive player-selected files through a temporary
local-network transfer page. That transfer does not send the files to the hosted
save or ranking services.

## Retention

The reviewed counter service keeps daily aggregate rows for 90 days. Lifetime
rescue and installation totals have no automatic expiry. These totals do not
retain a separate contribution that can be removed for an individual player.
Clearing local counts does not reset the shared totals.

Shared rankings and action replays have no automatic age-based expiry in the
reviewed service. The app can request removal of a player's hosted records.
An action replay can remain stored when it falls outside the public leaderboard
positions, and become available again if its ranking improves.

Hosted cloud saves remain available for recovery and synchronisation. Device-link
codes expire after ten minutes and can be redeemed once. The reviewed cloud
backup job retains the three most recent daily database snapshots. These backups
can temporarily retain earlier encrypted data. Apple controls retention for its
own services and device backups.

## Your choices

- Change **Share counts and records** in **Settings > Privacy**.
- Change record sharing for each player in the community ranking controls.
- Use **Remove shared records** to request removal from the community service.
- Clear local play counts without changing your saved games or public totals.
- Revoke calendar access in system settings.
- Keep device-link codes, sync passwords and recovery material private.

The app does not use an advertising identifier or an advertising SDK in this
candidate. Its privacy manifests declare no tracking for advertising. Apple and
network providers process data needed to operate their services.

## Contact

Developer: Erik Veland.

Privacy and support: [erik@veland.au](mailto:erik@veland.au).

Do not send passwords, recovery keys, private saves or other sensitive information
in public issue comments. The intended website is `https://lemmings.glasscode.academy`.
Its DNS, TLS and public privacy page are not yet verified live.
