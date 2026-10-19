# About and supporter recognition

The Mac About page uses the shared stone tabs, bitmap labels and game page
navigation. About, Version history and Contributors share the coffee action at
the bottom-right. Back keeps the initial focus.

`Scripts/bundle-about.py` extracts the published release entries from
`appcast.xml` during resource bundling. Version history works offline and follows
the feed order. It does not include unpublished release-note drafts.

## Contributor list

The Mac fetches `https://glasscode.academy/lemmings-api/v1/contributors.md`
when About opens. The collector reads `/opt/lemmings-telemetry/contributors.md`
on each request. Editing that UTF-8 Markdown file updates credits without an app
release or service restart. The installer seeds a missing file and preserves an
existing file. Keep the file below 64 KiB. Separate paragraphs and headings with
blank lines. Use headings and plain names. Links display their labels, without
navigation or embedded HTML.

The last successful list stays in local preferences. If delivery fails, the
page retains that list, shows Offline and offers Retry. A bundled list supplies
credits before the first successful request. Closing About cancels its request.
This public credit request sends no game profile or telemetry credentials.

The endpoint was deployed to GlassCode on 2026-10-19 with explicit approval for
the backed-up source replacement and service restart. The preceding source is
at `/var/backups/lemmings-telemetry/20261019T070111Z-about/server.py` on the host.
The Markdown file is `/opt/lemmings-telemetry/contributors.md`.

The initial opted-in supporter credits were published on 2026-10-19. The prior
Markdown is retained at
`/var/backups/lemmings-supporters/20261019T084206102238Z-initial-credits/contributors.md`.
Internal and public HTTPS checks returned the exact prepared Markdown with the
expected content type, no-store and nosniff headers. The separate private ledger
passed its root ownership and `0700` directory/`0600` file checks. The saved-total
health check passed. This content update required no service replacement or restart.

The coffee button opens `https://coff.ee/generik`. Opening the link does not
establish a donation or award a badge.

Home also offers Donate beside its other footer actions on Mac, iPhone, iPad
and TV. It remains enabled without an installed game catalogue. Mac and iOS
open the same destination as About. TV shows a QR code and the address, with
Back returning to Home. iOS uses that page if it cannot open the browser.
The shared Home covers Classic, Lemmings 2 and Lemmings 3.
The QR page chooses a whole-pixel scale that keeps the code and Back together.
Opening it on TV preserves the initial library load.

## Donation tracking proposal

The chosen policy is **opt-in public names and ranking, private amounts**.
The Markdown list preserves server order. Donation sorting must occur privately
on the server before names are published.

Manual supporter records live in `/var/lib/lemmings-supporters/manual-supporters.json`
on the host. The directory is root-only and the ledger has mode `0600`.
It retains reported currency amounts, creator-confirmed consent and the recorded
conversion basis. The public Markdown contains only opted-in display names.
The bundled fallback keeps the same order.

The initial manual entries use reported gross amounts converted to AUD with
the [RBA reference rate](https://www.rba.gov.au/statistics/frequency/exchange-rates.html)
on the recognition date. Their donation dates were not
provided. Freeze that rate per entry, round to AUD minor units with half-up
rounding, and sort descending with a case-insensitive name tie-break.
Reconcile refunds and corrections manually. These notification records do not
verify provider identities or grant profile badges.

Buy Me a Coffee supports `donation.created` and `donation.refunded` webhooks.
Its [webhook documentation](https://help.buymeacoffee.com/en/articles/15743173-how-to-setup-and-use-buy-me-a-coffee-webhooks)
specifies HMAC-SHA256 verification over the raw request body and a unique event
ID. A separate supporter service should validate signatures, ignore test events,
deduplicate deliveries and adjust totals for refunds. Keep its signing secret
and donation ledger on the server, separate from anonymous play counts.

Aggregate donations by the provider's stable supporter identity. Compare integer
minor-unit amounts in a common currency with a recorded conversion policy.
Publish only opted-in display names, sorted by the resulting net total. Never
publish email addresses, payment IDs, amounts or claim secrets in the Markdown.
Use a stable tie-break so equal totals do not reorder with every refresh.

A private claim code or authenticated account link must connect a verified
supporter to the chosen game profile. A display-name match and a click on the
coffee button are insufficient. The app can then receive a verified entitlement
for a persistent pixel badge and a once-only Home celebration. Honour reduced
motion and reduced flashes, keep the effect silent, and leave all Home targets
usable. Store an acknowledgement so every launch does not repeat the effect.

Automated donation ranking, claims, badges, confetti and fireworks are not yet
implemented. They need the creator's webhook configuration and a private identity
link. The current Markdown route supports a manually maintained opt-in ranking.
The new About tabs are Mac-only. iOS and TV retain their existing information
pages. The count backup store is shared by all three platforms.

## Count recovery

The Mac Privacy reset uses the shared ARE YOU SURE? page, with Back focused.
Reset stores the preceding local count dictionary before clearing it. Restore
previous counts consumes that backup and adds counts earned since the reset.
Neither operation uploads counts or changes the global total. iOS and TV already
require confirmation and now use the same backup store, but their pages do not
yet expose Restore previous counts. The feature applies to counts from Classic,
Lemmings 2 and Lemmings 3, including solo and Hot Seat attempts.

## Validation

The arm64 Mac source compiles. `TEST_SCOPE=about` in
`Scripts/run-app-integration-tests.sh` runs through the default muted, offscreen
UI runner. It checks all three tabs at three page sizes, action bounds and hit
targets, the server cache and offline fallback, cancellation, confirmed reset,
recovery with newer rescues and a second recovery attempt. Fourteen captures
cover the tabs, reset confirmation and available/consumed recovery states.
Representative captures were visually inspected. The collector's six tests and
the published-history generation checks pass. Public HTTPS delivery returns the
exact deployed Markdown with `text/markdown; charset=utf-8`, `no-store` and
`nosniff` headers. The existing saved-total endpoint also passes its health check,
with 50,020 before and after the restart. Physical VoiceOver navigation and
browser opening were not exercised by the automated checks.

The Home donation checks verify Mac mouse, keyboard and accessibility actions
at three sizes, with callbacks substituted for browser opening. The muted,
windowless `LemmingsMobileMenuAudit --book-home` check passes 120 captures,
including Donate, footer scrolling and Duo hinge/camera clearance.
`--support` passes 54 phone, tablet and TV captures. It checks Home targets and
decodes the rendered QR preview at each interface size. Representative Mac,
phone, Duo and TV captures were visually inspected. iOS and tvOS GameArt/UIKit
modules compile.
Physical touch, remote focus, camera scanning and browser opening remain
manual checks.
