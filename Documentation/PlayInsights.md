# Play insights

Play insights are in the macOS app menu and in **Settings > Privacy**. The page
shows this Mac's counts without a service. Shared counts need an HTTPS service
and an owner access token. The app does not include a service address by default.
The home screen shows lemmings saved on this Mac and, when the player shares
counts and the service responds, a shared total. A dash means the shared total
is unavailable; it does not mean zero.

## What is counted

- **Active installs today:** opted-in installations that opened or started a
  level on the current UTC day. Each installation sends at most one active-day
  event per day. This is not a count of people online now or of unique people.
- **Level starts, wins and fails:** attempt events for Classic, Lemmings 2 and
  Lemmings 3. Hot Seat and solo starts are counted separately. A start without a
  later win can mean a failure, retry, exit, crash or an attempt still in progress.
  The dashboard ranks levels by failed or unfinished starts; it does not prove
  why a player stopped.
- **Lemmings saved:** the rescued number from each completed attempt, including
  retries, failed attempts and Hot Seat. The local home count is all-time and
  works without sharing. The global home count is the all-time sum received
  from opted-in installations. It can lag or miss offline attempts; it is not
  the number of distinct lemmings or players. These counters start with this
  feature; older saved runs are not backfilled.
- **All music:** installations that pressed Download with all available extra
  soundtracks selected, and installations that finished that download. Each
  count is recorded at most once per installation. Earlier choices are not
  uploaded when a player opts in later.

Official level identifiers are limited to the shipped title and level number.
Lemmings 2 practice has one `practice` bucket. All fan levels share one
`fan/all` bucket. Pack names, custom level names, paths, profile names, run IDs,
replay contents and device IDs are not sent. The telemetry code uses a run ID
in memory only to avoid counting one result twice. The app stores
local aggregate counts in UserDefaults. **Clear this Mac's counts** clears that
local display; it does not delete totals already sent to the service.

Counts are best effort. An offline or interrupted request can be lost. The
home totals are all-time, but the local total includes attempts made before
consent while the global total includes only successful uploads. The dashboard's
shared view covers 7 or 30 days. Do not use these counts as exact unique-player,
concurrent-player or completion-rate figures.

## Consent and privacy

Sharing starts off. A first-run page asks for consent only when the build has a
service address. The player can change the choice in **Settings > Privacy**.
Turning sharing off cancels pending uploads and prevents new uploads. No earlier
service totals can be removed for one person because the service has no
identifier that could find them.

The collector stores daily aggregate rows and one lifetime rescued total. It
has no request or IP-address column and disables its own HTTP access log. The
public `/v1/saved` route returns only that total; it does not expose the private
dashboard or level breakdown. Changes to a public total can still reveal an
individual session when few people are playing. Even so, the HTTPS endpoint and
reverse proxy can see the source network address while handling a request.
The host and proxy must not keep access logs for these routes. Review the
hosting provider's logs and retention before enabling a public build. This
design reduces identification risk; it cannot promise complete anonymity over
the network. Get privacy and security review before public collection.

## Set up shared counts

1. Choose a host and HTTPS name for the collector. Restrict the Python service
   to loopback behind a TLS reverse proxy. Disable the proxy's access logs for
   `/v1/event`, `/v1/saved` and `/v1/dashboard`. Apply request-size and rate
   limits there.
2. Create a random owner token of at least 32 characters. Keep it in a
   protected service environment file, not in the app, source tree or shell
   history. Set `LEMMINGS_TELEMETRY_ADMIN_TOKEN` in the service environment.
3. Start `python3 Tools/Telemetry/server.py --db
   /var/lib/ultimate-lemmings/counts.sqlite3 --port 8765` on the host. The
   database directory must be writable only by the service account. The service
   listens on `127.0.0.1`. Back up and protect the database as aggregate usage
   data. It prunes daily rows older than 90 days on event or dashboard access.
   The lifetime saved total remains until the service owner resets it.
4. Build the app with `LEMMINGS_TELEMETRY_URL=https://your-https-hostname
   zsh Scripts/build-local-app.sh`. The build adds the URL to `Info.plist`.
   Check that each release variant uses the same current source and contains the
   intended URL. Never put the owner token in the bundle.
5. Test opt-in, opt-out, retry, win, fail, Hot Seat, soundtrack selection and
   completion on a staging service. Check the JSON schema, TLS, proxy logs,
   dashboard token rejection and the database columns before publication.
   Repeat the visible and keyboard-accessible page checks in a bundled app.

Without steps 1–4, shared counts and the **Load shared** action are unavailable.
The home screen shows the local saved count and a dash for the global total.
No collector is deployed by this repository.

The event endpoint intentionally accepts fixed-schema requests without a player
identity or secret in the app. A caller can forge counts. Proxy rate limits can
reduce abuse but cannot establish authentic unique players. Treat the shared
dashboard as a product signal, not a financial or audit record.

## Developer checks

Run `python3 -m unittest discover -s Tools/Telemetry -v` for collector schema,
aggregation and access-control tests. Run the `AnonymousTelemetryTests` SwiftPM
filter for event encoding, local count and duplicate-result checks. A successful
source build or these tests do not validate an actual HTTPS deployment, rendered
Mac pages or gameplay with commercial data.
