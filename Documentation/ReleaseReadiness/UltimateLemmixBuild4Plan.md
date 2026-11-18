# Ultimate Lemmix build4 plan

## Agreed design

Restore the developed frontend and common menus. Separate resource permission
from feature availability. Keep the running build3 review app unchanged.

Use the verified unchanged build3 NxlvKit library and modules. Compile changed
Mac frontends only. A complete core rebuild adds no value while its 162 source
files remain byte-identical. New test identities would separate player saves,
so canonical identities stay stable. Progress migration remains root-owned.

Player imports use one existing BYOIntegration instance per content-addressed
installation. Validate a staged import before deriving its key from its typed
file manifest. Preserve legacy single-install folders and enumerate them first.
Importing identical verified content returns the existing installation.

Package an exact allowlist of authored feature JSON, recovery fingerprint and
replay witnesses after checking their structure for embedded game payloads.
Restore the requested project icon with separate provenance and an explicit
character-rights review gate. Retain font and CC0 media notices separately.
Enable sandbox network client access. Do not invent Game Center signing proof.

## Implementation plan

**Goal:** Restore imports and feature data without changing the shared engine.

**Architecture:** `OwnedGameLibrary` owns staged multi-install imports and legacy
enumeration. AppDistribution exposes those locations. Import UI delegates to
the library. Resource tools retain exact membership, hashes and rights records.

**Tech stack:** Swift 6, Foundation, CryptoKit, existing BYOIntegration, Python
standard library and existing ImageMagick. No additional dependencies.

### 1. Multi-install imports

- [x] Add failing tests for two distinct Classic installs, duplicate content,
  legacy compatibility, rejected imports and linked/corrupt entries.
- [x] Add `OwnedGameLibrary.init(root:limits:fileManager:validator:)`,
  `directories(for:) -> [URL]`, and `install(directory:game:) -> Installation`.
- [x] Add AppDistribution.ownedDirectories(for:) and retain ownedDirectory(for:).
- [x] Pass the library to OwnedGameImportWindow without putting import rules in
  the view. Root connects the common library and Add Game navigation.
- [x] Run the focused synthetic import suite and a real local Classic fixture.

### 2. Feature data, icon and networking

- [x] Inspect the authored schemas and record an exact path/hash allowlist.
- [x] Add failing resource tests for required metadata, omitted game payloads,
  changed icon bytes and accurate mixed-rights declarations.
- [x] Include approved feature data, project icon provenance and notices in
  clean, mobile and personal resource preparation.
- [x] Add network.client to the Mac sandbox entitlements.
- [x] Run focused resource/icon/import tests and prepare build4 resources only.

### 3. Build and verification after root freeze

- [x] Recheck every core filename/hash, library archive bytes and target modules.
- [x] Compile each Mac frontend slice once and record code/source proof.
- [x] Sign canonical apps ad hoc without hardened runtime and verify exact
  resources, identities, dependencies and archives. Do not launch them.
- [x] Run common-menu/import/feature-data tests offscreen and muted. Verify
  stable profile IDs and preserve existing saves and the running review bundle.

## Review focus

Duplicate imports must not replace other releases. Legacy roots must stay
discoverable. Failed validation must preserve every previous import. Restored
metadata must not contain game assets. Source/rights records must not imply
that the project icon or original personal assets have distribution clearance.

## Verification record

The Mac frontend slices compiled once against the archive-verified unchanged
build3 core. Clean and personal code, resources, signatures and archive bytes
passed their separate audits. The manual copy uses clean resources and the
existing review identity; the earlier review bundle is unchanged.

The focused import suite passed synthetic rejection, duplicate, repair, legacy
and unsafe-entry cases, plus native-reader imports of local Classic and Oh No
fixtures. The 17 native scopes passed offscreen with muted audio. Live file-picker
permissions, fullscreen menu reveal and device acceptance remain manual checks.
See [build4 evidence](ultimate-lemmix-0.1-build4/feature-validation.json).
