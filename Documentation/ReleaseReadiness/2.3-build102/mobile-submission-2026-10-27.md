# Mobile 2.3 submission status — 27 October 2026

The version-history gate passes for Mac build 102, iOS build 36 and tvOS build 15.
The working tree includes uncommitted mobile menu changes. Their rendered Duo
states and touch targets have not been accepted on a physical device.

App Store Connect lists iOS 2.3 build 36 as Ready to Submit in TestFlight, with
the internal Lemmings group. This session did not upload that build and has not
verified whether it contains the current uncommitted menu changes. The existing
iOS App Store draft still identifies version 2.2.1 and its older build 21.
Neither App Store review submission nor public availability is established.

The tvOS platform was added to the existing Ultimate Lemmings App Store Connect
record for bundle `academy.glasscode.lemmings`. Its version 2.3 draft contains
basic description, keywords, support and marketing URLs, and copyright text.
It has no selected build or screenshots; review contact and content rights remain
open. It has not been submitted for review.

A fresh iOS build 36 attempt staged and validated game content, but its archive
failed before compilation because Xcode could not write SwiftPM's user cache.
The command-line session also reported inaccessible developer credentials. A
fresh tvOS build 15 archive attempt failed at the same package-cache step. These
failures do not establish that the signed-in Xcode account or its certificates
are invalid outside this restricted session. Logs are in the ignored candidate
build directories.

App Store Connect displays a notice requiring the account holder to review the
updated Apple Developer Program License Agreement and Paid Applications
Schedule before App Store submissions. The notice was not accepted. Actual
content rights must be established independently; a fan-port disclaimer does
not grant rights to bundled game assets. Apple processing, review, device checks
and public availability remain separate from upload.

Later on 27 October, iOS 2.3 build 36 was added to the existing iOS Private
Beta external group and submitted for Beta App Review. App Store Connect shows
Waiting for Review. Automatic tester notification is enabled. The group showed
240 testers at submission; availability follows Apple's approval. The upload's
coverage of the uncommitted menu changes remains unverified.

The tvOS TestFlight build list and upload history show 2.2.2 build 12 as the
latest upload; no 2.3 build is available to submit to the TV Private Beta group.

Xcode subsequently uploaded the signed tvOS 2.3 build 15 archive to App Store
Connect on 27 October at 20:39 Brisbane. App Store Connect showed the upload as
Processing; the TV Private Beta group could not yet select it. The archive was
created at 15:06 from the separate 2.3 release checkout, so inclusion of later
uncommitted menu changes is not established. This upload supersedes the earlier
no-upload status above.

Apple finished processing tvOS 2.3 build 15. It was added to the existing TV
Private Beta group (29 testers) and submitted for Beta App Review. App Store
Connect shows Waiting for Review, with automatic tester notification selected.
Tester availability requires Apple's approval. This supersedes the earlier
processing-only state.

## Corrected menu builds — 28 October 2026

The menu scrolling fixes were verified and committed as
`f8038d81bded50aafff51853677a2dd411c058ea`. The corrected iOS build is 2.3
build 37. Stable Xcode 27.1 created and exported the archive. The IPA is
208,619,724 bytes with SHA-256
`fc7208fb22b51ead0942c7f49f980cad7ed6af404473347e3704a18b4fa639e0`.
The app is `academy.glasscode.lemmings.ios`; its code signature passed strict
system-level verification. App Store Connect finished processing the upload.
Build 37 was added to the existing internal Lemmings and external iOS Private
Beta groups. The existing beta review was submitted with automatic tester
notification enabled; App Store Connect shows the build as Testing. The
external group retains its existing audience (248 testers at the time checked).
External access remains subject to Apple's beta review.

The corrected tvOS 2.3 build 16 was archived and exported from the same source
commit with stable Xcode 27.1. App Store Connect accepted the upload on 28
October at 11:49 Brisbane and finished processing it. Build 16 was added to the
existing TV Private Beta group. The group still has 29 testers, and the group
build list shows build 16 as Testing. Automatic tester notification remained
selected during beta review submission. Tester access follows Apple's review.
