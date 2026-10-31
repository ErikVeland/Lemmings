# Public progress sync for 2.4

## Approved scope

Use automatic private CloudKit sync for devices on the same Apple Account.
Offer a one-use device code for other accounts or devices without iCloud.
Reuse the encrypted hosted service and the shared Classic, L2 and L3 merger.
Do not create accounts or join public users to the shared tester library.
Preserve separate player identities, saved journeys, rosters and paused handovers.
Mid-level checkpoints remain local.

## Implementation sequence

1. Separate Developer ID CloudKit signing from development Game Center signing.
   Require a distribution profile, installed matching identity, shared container
   and Production environment. Apply this to both public packaging scripts.
2. Add shared bitmap link states and Mac, iOS and TV input adapters.
   Keep codes in memory, use the existing 12-character code and 10-minute expiry,
   disable duplicate requests, and preserve actionable failures. Keep existing
   tester libraries separate from public linking.
3. Validate source builds and rendered controls with isolated saves and muted,
   background tooling. Follow the release policy for skipped test suites.
4. Record production provisioning, schema and two-device acceptance separately.
   Check new installs, independent profiles, offline/reconnect, used/expired
   codes, all engines and Hot Seat recovery before claiming public sync works.

## Release evidence

- Mac source build passed. iOS and tvOS SDK modules and app entry points passed.
- The muted, offscreen bitmap check produced 48 captures across Mac, phone,
  narrow phone, iPad, Duo and TV sizes. It verified minimum 44-point targets,
  hit-test agreement and at most one enabled primary action. Narrow-phone error
  and phone-code captures were inspected. Native keyboard and remote delivery
  remain physical-device checks. New copy uses English fallback pending localisation.
- Version-history, shell syntax, Python compilation and diff whitespace checks
  passed. No engine change belongs to this sync patch. Test suites were not run
  for this patch. The candidate's separate rewind changes retain their recorded
  engine replay requirements.
- Two installed Mac development profiles were decoded. Neither grants iCloud.
  The public signing preflight correctly stops without a suitable profile.
- The owner supplied an Apple Developer screenshot showing iCloud and Include
  CloudKit support enabled, with one assigned container. The App ID capability
  is already enabled. The downloaded profile still needs regeneration or a
  new Developer ID distribution profile. The screenshot does not show the
  assigned container identifier.
- CloudKit management access failed because no management token was configured.
  No production schema or live player data was changed. No app was published.

## Remaining release gates

1. Provisioning completed on 31 October. The installed Developer ID profile
   grants the shared CloudKit container in Production and matches an available
   signing identity. Recheck the selected profile when packaging.
2. Verify the production `ULPrivateLibrary` record type. It needs `keys` (Bytes),
   `devices` (String List) and `snapshot` (Asset). Keep access private to the
   owner. Back up the current schema before any deployment. No query indexes
   are required. The client creates the private `ULPrivateLibraryV2` zone.
3. Verify the actual signed package, including its embedded distribution profile,
   Production environment, CloudKit entitlement, calendar access and disabled
   Game Center catalogue. Complete normal notarisation and package checks.
4. Use isolated libraries on two devices. Verify first restore, independent
   existing profiles, offline results, reconnection and used/expired codes.
   Include Classic, L2, L3, supported fan completion, saved solo journeys and
   Hot Seat rosters, turn ownership and paused handovers. Preserve recovery
   evidence before repairing any real save.
5. Verify Mac keyboard/paste, iOS/iPad/Duo keyboard and TV remote entry. Repeat
   service and cross-device acceptance with the final signed candidate.

Production iCloud, hosted link propagation, account changes, native input and
physical-device acceptance remain open. Compilation and bitmap captures do not
establish these behaviours.

## Developer ID profile installed — 31 October 2026

The owner supplied `Ultimate_Lemmings.provisionprofile`. Its name is
**Ultimate Lemmings**, UUID `825c160c-59cc-462a-828d-d054815b9715`.
It authorises `54WU29TRTY.academy.glasscode.lemmings` on all Macs, grants
`iCloud.academy.glasscode.lemmings` in Production, and permits CloudKit and
iCloud Documents. It expires on 26 October 2044.

The embedded certificate matches the installed Developer ID Application identity.
The profile was copied to Xcode's user provisioning-profile directory. Both
explicit-path and automatic-discovery public signing preflights pass. Release
packaging can discover it without a `CLOUD_PROVISIONING_PROFILE` override.

This resolves the Mac profile blocker. Actual package signing, production schema
verification and physical two-device acceptance remain open. The profile remains
outside version control. No public release was built or published in this step.

## Production schema inspection — 31 October 2026

Management authentication succeeded for team `54WU29TRTY`. Both environments
were exported from `iCloud.academy.glasscode.lemmings` without querying player
records or changing either schema.

- [Production export](CloudKitSchema/production-2026-10-31.ckdb) contains only
  Apple's `Users` record type. `ULPrivateLibrary` is absent. Production CloudKit
  cannot yet store the app's library records.
- [Development export](CloudKitSchema/development-2026-10-31.ckdb) contains
  `ULPrivateLibrary` with `keys BYTES`, `devices LIST<STRING>` and `snapshot ASSET`.
  These match `CloudKitLibraryStore.swift`. `Users` is unchanged between exports.
- Development also defines query/search indexes on `devices` and query/sort
  indexes on `keys`. The app uses fixed record IDs and does not require these
  indexes. They were retained in the exported evidence.
- The exported grants allow creator writes, iCloud-user creation and world reads
  in the public database. CloudKit's role rules govern public databases. The
  app uses `container.privateCloudDatabase` and its owner-scoped
  `ULPrivateLibraryV2` zone, so these grants do not make its private saves public.
  See [Apple's database access model](https://developer.apple.com/icloud/cloudkit/designing/).

The management-access blocker is resolved. The schema check is complete and
found a deployment blocker. The next change is to deploy the development
`ULPrivateLibrary` definition to Production, then export Production again and
verify the fields. No deployment was performed during this read-only check.
Signed-app and two-device acceptance remain separate release gates.
