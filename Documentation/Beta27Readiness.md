# Beta 27 readiness

Version 0.1, build 27. Universal arm64 and x86_64; macOS 13 or later.
This remains a beta. It does not close the full Classic/fan or sequel 1.0 gates.

## Release status

The app is built and signed with Developer ID Application: Erik Veland
(54WU29TRTY), with hardened runtime and a timestamp. Strict signature validation
passed. Apple notarisation could not start because the current login keychain
has no `lemmings-beta` credential profile. The pending ZIP must not be sent to
testers. Restore the notarisation profile locally; do not paste credentials into
chat or source control.

`.build/beta27/finish-release.zsh` checks the release test logs before submission,
then staples Apple's ticket, extracts the finished ZIP, checks its signature and
Gatekeeper acceptance with quarantine set, and copies it into Downloads. It does
not rebuild the tested app.

The previously delivered beta 26 ZIP was extracted again for this review.
Gatekeeper accepted it as Notarized Developer ID, and its stapled ticket passed
validation. It remains the available tester download.

## Frozen inputs

The universal app was compiled from `1dc60d9`. Commit `c88b409` then replaced five
L2 proof asset identities after exact witness replay validation. No application
or engine source changed. Commit `a5d0f4a` corrects one test's backing-pixel
tolerance, with no application change. The frozen checkout is
`.build/beta27/source`; copied Content, Ports and Music directories isolate it
from edits elsewhere. The input hash inventory is `.build/beta27/input-manifest.json`.

The two app logs are `app-arm64.log` and `app-x86_64.log`. Sequel results are
`sequel-assets.log` and `sequel-ui.log`. `core.log`, `gates.log`, `launch-smoke.log`
and `notary.log` record the remaining checks and the actual credential failure.
All logs are under `.build/beta27`.

The archive includes the latest Classic solution viewer, Hot Seat readiness
fixes and full soundtrack assets. The cumulative release notes cover beta 18
through beta 27.

## Validation

- All 25 core/resource regression suites passed against the fresh engine build.
- All 120 Original Lemmings winning routes passed the strict completion gate.
- All 103 known Classic family routes passed. The gate also verified 16 L3
  levels and its rejection cases; 74 L3 levels still have no fixture.
- L2 runtime tests passed, including 64 recorded campaign completions.
- Fan library and embedded pack-artwork tests passed.
- The hint catalogue passed: 120 decks, 103 release-rate contexts, event ordering
  and spoiler boundaries. The proof catalogue passed all 166 maximum certificates,
  17 rescue records and witness hashes.
- Both full app journeys passed: Apple silicon and Intel under Rosetta. These
  include solution replay isolation and confirmation, all 120 hint decks, speed
  input, targeting, save recovery, Escape and Hot Seat ownership.
- The complete sequel artwork and UI suite passed, with the live bundled L2
  proof check enabled. Artwork validation covered 59,542 frames, 120 checked-in
  visual hashes and 214 level assets. This is artwork coverage, not winning-route
  coverage.
- The signed production executable stayed running through an eight-second
  startup check on each architecture. Strict signature validation passed again.
- Original bitmap menu fonts and the live solution-viewer render were inspected.
  No source or asset hashes changed during the final checks.

The first full app journey stopped on a test that required the hint scroll
origin to be exactly zero. AppKit aligned it 0.194 logical points from zero.
The check now allows at most one backing pixel, while retaining checks for
scroll reset, complete text and keyboard scrolling. The initial failed log is
kept as `.build/beta27/app-arm64-initial.log`.

All five bundled L2 proof recordings were replayed twice against newly packaged
assets. Inputs, witness bytes, rescue counts, terminal ticks and other conditions
matched exactly. Only the asset fingerprint suffix changed. See
[Trolley evidence](TrolleyVerification/beta27-l2-proof-refresh.json).

## Coordination and remaining scope

Claude was assigned a separate worktree for the L2 proof failure. Its CLI could
not authenticate because its OAuth token was revoked. Access through the Claude
app was unavailable while the Mac was locked. Codex requested access and completed
the bounded proof check locally. No Claude changes were merged during this pass.

The full Classic/fan audit still records 85 load/start failures and 5,878 level
identities without a verified winning route. All 120 Original levels have routes;
that does not certify every Classic expansion or fan level. L2 and L3 remain
previews. Physical Intel/minimum-macOS, controller, full VoiceOver and sustained
hardware-performance journeys remain open. See the
[cross-game parity record](ReleaseReadiness/CrossGameParity.md).
