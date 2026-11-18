# Mac source refresh

The universal Mac Store export passed on 19 November 2026. Handoff now contains the verified package from the refreshed source.
No upload or submission occurred.

| Item | Verified value |
| --- | --- |
| Version and build | 2.4.2 (108) |
| Architectures | Apple silicon and Intel |
| Package size | 42,622,656 bytes |
| Package SHA-256 | `124bacf89b97ef6bc39da05e19fdbe7fc10948b421413d5c7c3671de8fff2791` |
| Build source commit | `1ac19c638e3f62dd48f7d4dedf17b285b961b079` |
| Export verification commit | `6c1d19d9b2b6048de044fc04d2a6fd2243daebba` |
| Installer signer | 3rd Party Mac Developer Installer: Erik Veland (54WU29TRTY) |
| Apple export analysis | No product errors |

All 570 frozen build inputs match the export verification commit. Stable Xcode 27.1 built the app.
Both architecture builds reused verified NxlvKit core caches. The shared libraries, app and widget compiled successfully.
The final checks verified the distribution signatures, required entitlements, clean resources, exact package contents and both architectures.

The source change replaces a complex presentation expression with explicit loops for older Swift compilers.
All 9,600 generated artwork bytes remain identical, with SHA-256 `9483b3013bdaaaaafdebf56fced501c71cb8b4e99973f47c057241116ee28a78`.
No engine source changed. Test suites and notarization did not run under the Store release policy.

The first export failed while the Mac was locked. Xcode reported unavailable credentials.
After the user unlocked the Mac and signed into Xcode, an export-only retry passed. No further compilation was needed.
The failure did not establish account deletion. This packaging task did not change keychain entries.

The prior Handoff package remains in `UltimateLemmix-Store-20261119/Superseded/Mac before source refresh`.
Its SHA-256 is `9010fcb80bd8c905dbdb402e8b9c24c4c937aeb0f165936f00baf61cfd448920`.
The complete prior build also remains in `mac-before-ci-compatibility-20261119` under the 18 November output directory.

The [package receipt](mac-store-package.json) records signing and package checks.
The [refresh receipt](mac-source-refresh.json) records source equivalence, resolved credential access and retained artifact paths.
Apple upload, processing and review remain separate gates.
