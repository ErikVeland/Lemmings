# Deployed telemetry privacy evidence

Checked 19 November 2026 through the existing `glasscode` SSH alias.
The inspection read service definitions, deployed program files and proxy
configuration. It did not read user logs, database records, credentials or
environment-file contents. It sent no telemetry events and changed no server
files or services.

## App Store linkage answer

The deployed app-managed counter service supports **Product Interaction →
Analytics → Not Linked to You → Not Used for Tracking**. It stores aggregate
counts without a user or device identifier. No join to cloud-library or ranking
identities exists in the reviewed collector.

This finding resolves the origin-service uncertainty in
[StoreAccountChecklist.md](StoreAccountChecklist.md). It does not establish that
Cloudflare retains no request metadata. Keep that provider limitation separate
from the confirmed counter design. No App Store Connect answer was saved by
this inspection.

## Verified origin configuration

| Item | Observed evidence |
| --- | --- |
| Service | `lemmings-telemetry.service` is active. It runs `/usr/bin/python3 -B /opt/lemmings-telemetry/server.py` on port 8796. |
| Deployed program | SHA-256 `4d7bb7b063b9f076d8df40bbf49c38f2d41491c2ae4f81e84aa4d11ac6c094c6`, identical to [Tools/Telemetry/server.py](../../../../Tools/Telemetry/server.py). |
| Proxy route | `/etc/nginx/sites-enabled/glasscode.academy.conf` includes `/etc/nginx/snippets/lemmings-telemetry.conf` in its HTTPS server. |
| Deployed route | SHA-256 `b8e315e32aade0c14d10453514f73402e5fa219f394d45c8347ac754ccb10e24`, identical to [nginx-location.conf](../../../../Tools/Telemetry/deployment/nginx-location.conf). |
| Logging | The telemetry location sets `access_log off` and `error_log /dev/null`. These override the parent server's normal request/error logs for this location. |
| Forwarded headers | `X-Real-IP`, `X-Forwarded-For`, `CF-Connecting-IP` and `Cookie` are set to empty strings. `Host` becomes `localhost`. |
| Upstream | Requests go to `http://127.0.0.1:8796/`. The collector binds only to localhost. |
| Rate limiting | `/etc/nginx/conf.d/lemmings-telemetry-limit.conf` uses `$server_name` for one aggregate bucket, not a client IP address. |

The service started on 14 November, after the deployed program's 19 October
modification date. Nginx started on 14 November, after the telemetry snippet's
8 October modification date. The read-only Nginx configuration check succeeded.

The deployed collector accepts only fixed event fields and known game/level
values. Extra payload fields are rejected. Its storage code writes:

- Daily totals keyed by day, event, game, level and mode.
- Lifetime rescue and installation totals keyed by event name.

It does not store individual event rows, supplied timestamps, IP addresses,
request headers, cookies, player names, device IDs or account IDs. This statement
describes the verified deployed code. The database contents were not inspected.
Daily rows expire through the 90-day pruning code. Lifetime totals have no
automatic expiry.

The collector suppresses `BaseHTTPRequestHandler` request logging. Its exception
handler emits only `Telemetry request failed`, without the client address or
request data. Systemd sends stdout/stderr to the journal, so service lifecycle
messages and that generic error can remain there. This is not a claim that the
host keeps no operating-system logs.

The app's [AnonymousTelemetry.swift](../../../../Sources/LemmingsAppCore/Privacy/AnonymousTelemetry.swift)
uses an ephemeral session without cookies. Event requests have the fixed
`UltimateLemmingsCounts/1` User-Agent and no Authorization header. The separate
dashboard request uses an administrative bearer credential, not a player
identifier in gameplay events.

## Header and provider limits

The proxy removes the four named headers. It does **not** implement a complete
header allowlist. Headers such as `Forwarded` and `CF-Ray` are not explicitly
removed by this snippet. The collector does not persist or use them to identify
players. Do not describe every possible identifying header as stripped.

Cloudflare receives traffic before these origin rules apply. Its documented HTTP
logging fields include client IP, request URI, timestamp and Ray ID. Configured
custom fields can include headers. Origin SSH access does not reveal this
zone's Cloudflare logging, export, security-event or retention settings.
No such settings were inspected, and no exact Cloudflare deletion deadline is
claimed. See [Cloudflare HTTP request fields](https://developers.cloudflare.com/logs/logpush/logpush-job/datasets/zone/http_requests/)
and its [data-processing addendum](https://www.cloudflare.com/cloudflare-customer-dpa/).

The policy can state that the app-managed counter data is unlinked. It must not
state that providers never process network addresses or that all network
requests are anonymous. If the final privacy declaration requires provider-wide
verification, inspect Cloudflare's account configuration without reading request
records. That is the remaining evidence boundary, not an unknown property of
the deployed counter service. Apple's [privacy guidance](https://developer.apple.com/app-store/app-privacy-details/)
also requires consideration of third-party processing.
