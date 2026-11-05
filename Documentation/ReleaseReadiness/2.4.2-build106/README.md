# Mac 2.4.2 build 106 release

Mac 2.4.2 build 106 was published on 5 November 2026 at 17:10 AEST.
The tag identifies source `55f8f52703e04db6b6f9460fd7b962de81aab26f` from `main`.
See the [GitHub release](https://github.com/ErikVeland/Lemmings/releases/tag/v2.4.2).

Both ZIPs support Apple silicon and Intel on macOS 12.3 or later. Both pass ZIP
integrity, strict Developer ID signatures, notarisation ticket and quarantined
Gatekeeper checks after extraction. Both enable CloudKit in Production.
The slim package reuses the full package's universal binaries.

| Package | Soundtrack versions | Accepted Apple submission |
| --- | ---: | --- |
| Full update | 495 | `b14c018f-237a-4772-ab96-76aeb8382d31` |
| Slim download | 54 | `ef302a3c-227d-478c-8636-42492d47f32b` |

The app's public key verifies the full archive and five direct deltas from
builds 105, 104, 102, 99 and 98. Each patch reproduces all 18,943 files and links
in the signed target and passes strict signature verification.
The feed retains the 29 earlier entries.

The updater URL serves the verified feed with SHA-256
`0602d4259f07e98a4df43feb3fee035e20e3cde24681d1fc8d119a4b2c4c9990`.
The seven public downloads match the verified ZIP and delta bytes. GitHub
marks 2.4.2 as the latest release. See the [publication record](publication.json)
and [package checks](public-package-verification.json).

The source changes cover repository maintenance, build tooling and presentation.
Simulation and replay sources match build 105. The Mac non-engine release policy
and owner request skipped test suites and foreground launch checks.
iOS build 45 and tvOS build 20 are reserved for separate delivery.
