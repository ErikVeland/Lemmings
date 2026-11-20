# Hosted service readiness

> Historical record — status clarified 19 November 2026. This document retains
> the earlier investigation, service checks or separate-mobile-ID packages.
> It is not the current gate list. Use the [current handoff](README.md),
> [unified mobile identity evidence](UnifiedListingMobile.md) and
> [website release record](WebsiteRelease.md) for current status.
> All main apps now use one listing. The website is live with valid HTTPS.
> Earlier missing-signing or separate-ID findings are retained
> as history, not current package blockers.

Checked 18 November 2026 at approximately 12:42 UTC. Requests used HTTPS GET,
without credentials, player identifiers, vault identifiers or request bodies.
No data was created, changed or removed.

| Public endpoint | HTTP result | Response |
| --- | --- | --- |
| `https://glasscode.academy/lemmings-api/v1/saved` | 200 | Public aggregate `saved=128848` |
| `https://glasscode.academy/lemmings-api/cloud/v1/health` | 200 | `version=2`, `status=ok` |
| `https://glasscode.academy/lemmings-api/rankings/v1/health` | 200 | `version=1`, `status=ok` |

All three responses were JSON and declared `Cache-Control: no-store`.
Their server header identified Cloudflare. Detailed receipts are in
[hosted-service-readiness.json](hosted-service-readiness.json).

The telemetry source has no separate health endpoint. Its public aggregate GET
was used instead. No administration endpoint or individual leaderboard row was
read. No synthetic player, library, save or replay was submitted.

These results confirm public routing and service responses at the recorded time.
They do not verify authenticated save writes, restores, removal, cross-device
propagation, installed server code, retention jobs or hosting-provider logging.
Game Center and private CloudKit acceptance require separate checks.

## Public privacy notice discovery

The reviewed repository metadata did not identify a public Ultimate Lemmix
privacy-policy URL. Targeted web searches did not locate one. The GlassCode
homepage returned HTTP 200, but its returned page contained no privacy or Lemmix
link. This is a discovery limit, not proof that no policy exists anywhere.

[PrivacyNotice.md](PrivacyNotice.md) is an unpublished draft. Before publication,
verify a monitored contact, current service retention, backups and provider
processing. The known developer name is Erik Veland. A dedicated Lemmix privacy
mailbox or contact page was not verified.

## Retention evidence and limits

| Area | Source-backed behaviour | Live acceptance limit |
| --- | --- | --- |
| Telemetry | `Tools/Telemetry/server.py` expires daily rows after 90 days. Rescue and installation lifetime totals have no expiry. | Public GET does not expose retention configuration. |
| Rankings | `Tools/Rankings/server.py` supports player deletion. Documentation records no automatic replay eviction. | No private data or deletion endpoint was exercised. |
| Hosted cloud | `Tools/CloudSaves/server.py` permits one-use links for 600 seconds and retains three daily database snapshots. | Health does not verify backup execution or deployed retention. |
| Request logging | Checked-in nginx routes suppress API logs and strip client identity headers and cookies. | Current proxy/provider logging was not inspected. Cloudflare delivery is observable. |
| Cloud activation | `CloudLibrarySync.start()` enables automatic sync in normal builds and retires the old manual pause setting. | Physical-device behaviour remains separate from source review. |

The privacy notice must not describe cloud saves as opt-in or promise a persistent
pause switch. The older wording in `Documentation/CloudProgress.md` predates the
current automatic-sync implementation. Count and record sharing remain distinct
consent-controlled features.

## Mobile profile review

Both archive logs were inspected during compilation under
`/Volumes/Games/CodexBuilds/UltimateLemmix-Store-20261118`.
At the final 12:45 UTC check, both archives had failed in the resource-copy phase.
Each phase looked for the manifest under the checkout
`.build/publication-resources/ultimate-lemmix` instead of the prepared external
resource directory. No signing error was reported. The explicit Store xcconfig
overrode the supplied command-line resource setting. Root removed that override
and moved fallback settings into the publication entry point. The iOS retry uses
`ios-archive-retry.log` and `mobile-resources-final`. Retry completion is separate
from this initial failure receipt. See
[mobile-signing-log-check.json](mobile-signing-log-check.json).

Newly generated development profiles authorise the expected capabilities:

| Target | Profile UUID | Capabilities verified |
| --- | --- | --- |
| iOS app | `6f79991b-e76f-4697-9c70-ae31f068389b` | Shared app group, Game Center, shared iCloud and ubiquity containers |
| iOS widget | `86cc6919-8b86-4eb0-8cf5-9cb3fe510a78` | Shared app group |
| tvOS app | `1b0a5f0f-dc21-4a85-9fa6-558fdf1a5c32` | Shared app group, Game Center, CloudKit, development push notifications |
| Top Shelf | `8bc3cf73-de34-4581-a6a2-13f3bfdbe7d6` | Shared app group |

All four profiles expire on 18 November 2027. The iOS profile includes the shared
app group despite the initial invocation omitting `REGISTER_APP_GROUPS=YES`.
Store exports must replace development signing and verify production cloud and
push environments. This profile check does not establish completed archives.
