# Lemmix website release record

Checked 19 November 2026. The website is live at
https://lemmings.glasscode.academy with valid HTTPS. The deployed source is
`6c1d19d9b2b6048de044fc04d2a6fd2243daebba`.

## Public destinations

| App Store field | Verified public URL |
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
The live browser pass verified pointer and keyboard gallery selection, Tab
navigation and the skip link. The skip link focuses the main content. The live
page has no horizontal overflow or captured console warnings or errors.

Safari, Firefox, assistive-technology, high-zoom and physical-device acceptance
remain unverified. No native game tests or audible checks ran for this website.

## Published release

Cloudflare now serves the DNS-only A record `lemmings` → `194.195.248.217`.
The certificate covers the public hostname and expires on 16 February 2027.
The existing Certbot timer is active. A certificate-specific renewal dry run
passed and ran the host's existing Nginx reload hook. No duplicate hook remains.

The immutable release is `/var/www/lemmings/releases/6c1d19d9b2b6048de044fc04d2a6fd2243daebba`.
The current link selects that release. The previous configuration and deployment
receipt remain available for recovery. Other Glasscode sites are unchanged.

[Live verification](WebsiteLiveVerification.json) records ten HTTPS routes,
deployed file hashes, canonical metadata, redirects and the designed 404 page.
HTTP redirects to HTTPS. Directory and index aliases redirect to clean routes.
The server returns Content Security Policy and Strict Transport Security headers.

The Handoff website folder retains the publication log, renewal dry-run log,
DNS screenshot and live home capture. Mac support and marketing URLs are saved
in App Store Connect. Remaining Store URL fields still need verified saves.
Website publication does not complete the app submission gates.
