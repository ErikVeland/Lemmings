# Macintosh 2.0.3 build 86 release

This maintenance release is based on public 2.0.2 build 85.
The language-picker fix is committed in `f5d1c4c5`. The release also refreshes
release metadata, translated notes, release checks and repository maintenance.
What's New now resolves its text when opened, so a language preview cannot
leave its cached subtitle and sections in the first language used.
See the [release notes](../../ReleaseNotes-2.0.3-build86.md).

## Scope

Mac language rows use rectangular native button tracking while retaining radio
accessibility roles, selected states and the shipped bitmap artwork. The fix
does not change simulation rules, content, saves or Hot Seat ownership.
Classic and The Tribes retain Complete classifications. Chronicles and NeoLemmix
remain Beta. Existing content and source-fidelity gates remain open.

## Source validation

The current focused check passes seven shared resolver tests and three Mac UI
tests, plus six catalogue-validator tests. The picker checks cover all ten language choices at two window sizes,
native cell hit regions, keyboard and accessibility activation, preview,
Back, Apply and reopening. Six English, French and Tamil captures retain the
original controls. Another eighteen captures cover What's New in all nine
languages at the same two sizes, including Continue activation and containment.
Representative German and Tamil renders were inspected after correcting the
cached text. All eight packs have 3,159 text keys and eight plural keys.

The data-independent shared source gate passes 335 Swift Testing cases across
61 suites. The release-tooling suite passes 88 Python tests, including the new
repository-maintenance checks. Rescue proofs retain 294 certificates and 315
targets. These checks do not close the stricter engine and content gates.

All eight translation packs remain AI-assisted drafts. Structural checks and
bitmap renders do not establish human language approval or VoiceOver acceptance.

The [repository maintenance record](repository-maintenance.json) lists the
validated file types, archived notes, removed caches and preserved local work.

## Distribution gates

The release is built from `b6b1ca19e5753efcf328c043d0e7ae6f4c21ec76`.
Both universal archives are signed, notarised and stapled. Quarantined copies
extracted from each ZIP pass code-signature, ticket and Gatekeeper checks.
The full archive is 2,054,422,043 bytes. The slim archive is 270,365,950 bytes.
See [distribution checks and checksums](distribution.json).

The [verified signed feed](appcast-candidate.xml) preserves all sixteen earlier
entries and adds build 86 with direct patches from builds 85, 84, 83, 82 and 81.
Every patch passes Ed25519 verification and reproduces all 18,558 target files,
including 649 music files, symlinks and file modes. Patched apps pass code-signature
checks. The build-85 patch is 473,790 bytes. See the
[five-base delta record](delta-verification.json).

Five shared libraries retain code from the signed public build 85 ZIP. Their
281 Swift source files match the frozen build 85 source, and the retained
library inputs match the public ZIP byte for byte. The changed artwork library
and Mac app were rebuilt. No campaign or source-fidelity closure is claimed.
The complete build-86 app audit was not rerun. The owner authorised publication
with existing engine evidence because engine sources and code are unchanged.
Existing music-resource
permission warnings and AppKit warnings are recorded in the distribution checks.

The owner authorised publication on 16 October 2026. The
[public release](https://github.com/ErikVeland/Lemmings/releases/tag/v2.0.3)
contains both archives and all five signed deltas. GitHub's asset digests match
the local SHA-256 values, and every public download URL resolves. All five
downloaded delta payloads match the verified local patches. The live update feed
matches the verified candidate byte for byte. See the
[publication receipt](publication.json) for asset IDs, URLs, hashes and checks.

Native mouse input, VoiceOver, physical controllers, Intel/minimum-OS hardware
and the signed app's launch and update/relaunch remain manual checks. The
shipping-app launch script requires the real desktop. Repository policy
requires a separate explicit request for that foreground check.
