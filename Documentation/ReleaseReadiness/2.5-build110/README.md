# Ultimate Lemmings 2.5 build 110

Status: Published on 25 November 2026.

Release source: `e2f29e52ac9af9747b040087d53753e4a9a697aa`  
Release tag: `v2.5`  
Scope: macOS 12.3 or later, Apple silicon and Intel.
GitHub release: https://github.com/ErikVeland/Lemmings/releases/tag/v2.5  
Sparkle feed commit on `main`: `f0344f4410c2fdfd4b6a0f5c44a0e737d29decad`

Ultimate Lemmings ships Mac builds only. No iOS, iPadOS, Duo, tvOS or App Store
package is part of this release. App Store updates are for Ultimate Lemmix.

## Public Mac packages

| Package | SHA-256 | Apple notarization | Verification |
| --- | --- | --- | --- |
| Full Sparkle update, `UltimateLemmings-2.5-build110.zip` | `f2ab4887a6e4abff00f800b9824e3ce4bc2e9023efeaee1ff90e417d66a024fa` | Accepted with the standard app, `aca33c70-17ed-4127-92f0-4560213052f3` | Stapled app; ZIP integrity passed |
| Slim fresh install, `UltimateLemmings-2.5-build110-slim.zip` | `1b4566f8dcc6cc849da871c8fd662f77bb1f5b8459d9eea2a8f1b9f309bc34ec` | Accepted, `5c2bafc9-087e-4947-8b0d-338e2d37f082` | Stapled; extracted app passed Gatekeeper as Notarized Developer ID |

The Sparkle feed has 32 entries. Build 110 contains signed direct deltas from
builds 109, 106, 105, 104 and 102. The slim package is not listed in the feed.

| Delta base | SHA-256 |
| ---: | --- |
| 109 | `65799efb76ba27bb53989c66d9725d7ab9ce77d15699031acaf7e5ba05bbdfd4` |
| 106 | `b7c0c39e391aa5e9ecc8434b87b99f13441b45f3dcd9e874119951cf3daada4b` |
| 105 | `ca137c7d4b046c7cfac65f0f80b144199d610bf65e236d540af3c8cd73374e96` |
| 104 | `4b97d3073696538fc463897de342be777df25f448a6ffe183f62e6a76a2cbafd` |
| 102 | `246d514a319a6ec7354735ac11c8ee250ce9fda1a7fbe50def623a34fdc30b34` |

Appcast SHA-256: `f5103d822e8bb443e48559caa358a21d3c75bccac44642e659a31bd6a6aff3b1`.

## Release checks

- `Scripts/check-release-inputs.sh` passed, including release history, feed signatures, delta coverage, HTTPS URLs and current What's New version.
- `Scripts/publish-github-release.sh --check` passed for the frozen source, full updater, slim download and signed deltas.
- Both public ZIPs passed archive integrity checks. The slim app passed Gatekeeper after extraction.
- Engine code did not change. Release policy therefore skipped automated tests and test-running launch audits. Physical UX-15 audio listening remains open and is not a Mac publication gate.
- A Developer ID signature guard was added to the notarization path after packaging. It checks every nested Mach-O code object before creating a notarization submission. The guard passed against the accepted slim app.
