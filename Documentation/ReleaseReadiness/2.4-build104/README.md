# 2.4 build 104 preparation

Status: preparation only, 31 October 2026. No 2.4 platform package has been published or submitted. Candidate version numbers are Mac 104, iOS 39 and tvOS 18; confirm the mobile numbers against App Store Connect before archiving. The previous published Mac source is `96dc81b8491dfdb58683f0e32025fc4c8137aa1c` (2.3 build 102). The candidate includes uncommitted changes and has not been frozen.

## Release scope and checks

Classic rewind history and seek behaviour changed since the published Mac source. The engine-change policy applies: run affected regression and replay checks on the frozen candidate, verify preserved fixture manifests and record affected-route evidence. The manifest checks on 31 October passed for 120 Classic solution fixtures, 322 campaign fixtures, 120 Lemmings 2 fixtures and 70 carry-over fixtures. Hash checks alone do not establish that routes still win.

The version-history check passed for 2.4 build 104 and `git diff --check` passed on the working candidate. Rendered Mac gameplay deck states and input targets remain unverified; see [platform parity](../../PlatformFeatureParity.md). The current source also records sequel panel layout gaps and device acceptance gaps. The new in-app release copy needs localisation review.

## Delivery

- **Mac:** Not built, signed, notarised or published. The release script dry run could not find a Developer ID Application identity. Complete affected engine checks, rendered-state and input verification, universal packaging, signing, notarisation, package integrity and feed verification on the frozen candidate.
- **iOS and Duo:** Not archived or submitted. Check App Store Connect build numbers and signing, then follow the existing distribution groups after Mac publication. Device acceptance remains open.
- **tvOS:** Not archived or submitted. Check App Store Connect build numbers and signing after iOS submission. Device acceptance remains open.
- **Sideloading:** Not delivered. Follow the channel register in [iOS distribution](../../IOSDistribution.md) after the higher-priority deliveries.

The local GitHub CLI authentication check failed, although the connected GitHub app responded. No release, tag, feed or remote branch was changed as part of this preparation.
