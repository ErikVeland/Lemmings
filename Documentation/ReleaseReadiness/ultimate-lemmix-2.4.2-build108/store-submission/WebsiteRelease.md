# Lemmix website release record

Checked 19 November 2026. The website is complete locally. Public deployment
remains blocked by DNS access. Do not treat this record as a live-site receipt.

## Public destinations

| App Store field | Intended URL |
| --- | --- |
| Marketing | https://lemmings.glasscode.academy/ |
| Support | https://lemmings.glasscode.academy/support |
| Privacy policy | https://lemmings.glasscode.academy/privacy |
| Privacy choices | https://lemmings.glasscode.academy/privacy/choices |
| Accessibility | https://lemmings.glasscode.academy/accessibility |

The public developer and privacy contact is `erik@veland.au`. The existing
GenErik DJ configuration and published support/privacy pages verify this address.
No telephone number or postal address was invented.

## Implementation

`Website` contains the complete static site, source assets, licence notices,
asset provenance, route checker, preview server and deployment procedures.
It uses the existing Glasscode publishing approach with a separate host and
release directory. It does not change the GenErik DJ domain or website.

Ten public routes cover the product, support, manual, privacy, privacy choices,
accessibility, terms, release notes, legal index and credits. Two error pages
provide missing-page and service-error responses. Every route includes a title,
description, canonical URL and social metadata. The sitemap uses the intended
public origin. Error pages request exclusion from search indexing.

The site uses the current Lemmix logo, licensed Lix sprites and genuine Mac and
simulator captures. It has no tracking script, external font request, embedded
service, contact form or fabricated App Store button. The optional script only
switches product captures. HTML retains text, navigation and direct capture
links when JavaScript is unavailable.

## Completed checks

- The generated twelve routes pass internal link, anchor, image, CSS reference,
  title, heading and canonical URL checks.
- Local HTTP checks return 200 for all ten public routes and 404 for an unknown
  path. The missing path renders the designed error page.
- Browser checks cover 320, 390, 768, 1024 and 1440-pixel widths. The 320-pixel
  overflow was corrected. All public routes and the missing-page view fit at
  390 pixels, with no broken images.
- The final desktop home capture has seven loaded images, no broken images,
  no horizontal overflow and no captured console warnings or errors.
- The checked text/background palette pairs exceed 4.5:1 contrast. This is a
  palette check, not a full accessibility-conformance claim.
- The manual has one contents index. The skip link targets a focusable main
  element. The screenshot buttons appear only after their script loads.
- Nginx route checks use an isolated loopback-only worker. They verify clean
  routes, redirects and error status without changing existing production sites.

The requested [Lighthouse CLI](https://github.com/GoogleChrome/lighthouse) ran
in a separate headless browser with muted audio. Mobile home scores are
97 performance and 100 accessibility, best practices and SEO. Desktop home
scores are 100 in each category. The manual scores 100 for accessibility, best
practices and SEO. Mobile simulated largest-content paint is 2.6 seconds, with
zero layout shift and zero total blocking time. These local measurements do not
establish public-network performance or complete accessibility acceptance.

The first audit found an oversized logo and low-contrast footer caption.
Responsive WebP versions preserve the logo artwork and proportions. The caption
now uses a darker text colour. The final audits include both corrections.
`Website/verification-summary.json` retains report hashes and measured values.

Browser evidence is in the local ignored `Website/verification` directory.
The route and build checks can be reproduced with Python's standard library.
The final interactive browser pass is incomplete: input stopped taking effect
in both the local preview and App Store Connect. Computer control then confirmed
that the Mac was locked. Repeat this pass after the owner unlocks it.
Do not count those attempts as
passed keyboard, gallery or Store-save checks. Earlier gallery selection worked,
but it does not replace the final interaction pass.

Safari, Firefox, assistive-technology, high-zoom and physical-device acceptance
remain unverified. No native game tests or audible checks ran for this website.

## Publication gate

The requested hostname returns no A record. Cloudflare manages the zone.
The owner sign-in handoff remains pending. The prepared DNS record is:

| Type | Name | Value | Mode |
| --- | --- | --- | --- |
| A | lemmings | 194.195.248.217 | DNS only |

No AAAA record is required for this deployment. The server has a dedicated
ACME bootstrap configuration, with no active site release. Publication requires
DNS resolution, a valid certificate and a committed source revision.

After publication, verify all public routes, HTTPS, redirects, canonical
metadata, social assets and the unknown-page response through the public host.
Then save the verified URLs in App Store Connect. Keep the previous release
available for rollback. Do not mark the app ready merely because its website
is online.
