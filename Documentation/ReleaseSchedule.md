# Release schedule

Adopted 26 October 2026, Australia/Brisbane.

Use this order for each release. Ship each platform as soon as its package is
ready. Later platforms and stores can follow the Mac release with their own
delivery receipts. Do not wait for every platform before publishing Mac.

| Priority | Release | Scheduling rule |
| --- | --- | --- |
| 1 | Mac | Get the release out quickly. Skip tests unless the candidate changes an engine. |
| 2 | iOS: iPhone, iPad and Duo | Prepare and deliver after the Mac release. Retain existing distribution groups and settings. |
| 3 | tvOS: Apple TV | Prepare and deliver after iOS submission. Track Apple processing and review separately. |
| 4 | Sideloading stores, catalogues and installers | Include every channel in the distribution register. Cut these releases after the higher-priority platform work. |

External processing or review can overlap later work. A pending Apple review or
store response must not hold the queue idle. Return to higher-priority work when
it becomes actionable. Lower-priority work must not delay an earlier release.

## Mac release path

Compare the candidate with the last shipped Mac source and record whether engine
behaviour changed. Engine changes include simulation, movement, collision,
terrain, skills and replay execution, plus engine input changes that can alter
outcomes. Presentation, menus, artwork, documentation and release metadata alone
do not trigger engine tests.

If there are no engine changes, skip automated tests and release audits that run
test suites. Carry forward existing engine evidence with its source limits.
Record the checks as skipped under this policy, never as passed.

If an engine changed, run the affected engine regression and replay checks.
Use the [release replay policy](ReleaseScope.md#release-replay-policy) to select
affected routes or the full campaign gate. Keep automated tests headless,
offscreen and muted under [repository instructions](../AGENTS.md).

Build the actual release packages. Retain required signing, notarisation,
package-integrity, checksum and updater-feed verification. Publish Mac without
waiting for mobile archives, store onboarding or a broad acceptance matrix.
Public release architecture and packaging requirements remain in force.

## Sideloading release queue

The [distribution register](IOSDistribution.md) supplies each channel's current
evidence, submission route and next action. All channels below are priority 4:

- AltStore Classic, SideStore, Feather and SideStore Community Source.
- AltStore PAL, Aptoide, AppArena, Epic Games Store, Skich Store and Onside.
- appdb and Signulous, including their separate catalogue and IPA-import routes.
- Sideloadly and LiveContainer.
- Scarlet, ESign, GBox, KSign, TrollStore and newly identified installers or catalogues.
- mobivention, subject to its consumer-game eligibility decision.
- Setapp Mobile remains recorded as closed. Do not schedule an unavailable service.

For accepted channels, update the existing listing or source for each release.
For new channels, complete onboarding and submission in this lower-priority
queue. Reuse the matching released iOS IPA where the channel accepts it. Use
the required notarised package for marketplaces. Preserve the stable Classic
source URL and all downloads in the canonical repository.

An unavailable account, eligibility decision, device check or store review leaves
that channel open. Record its blocker and continue with other ready channels.
Do not hold Mac, iOS or tvOS for sideloading completion.

## Release records

For each version, record Mac publication, iOS submission and availability, tvOS
submission and availability, and each sideloading channel's delivery state
separately. Include package identities, skipped tests, engine-change scope and
remaining blockers. A submission alone does not establish store availability.

This schedule supersedes older delivery orders and routine Mac test requirements.
Historical release receipts remain unchanged. Product acceptance and feature
work retain their recorded limits without becoming new non-engine Mac test gates.

## Version-history build gate

Every Mac, iOS and tvOS app build must pass
`Scripts/check-release-history.sh` before compilation. The gate requires a
tracked notes file for the exact Mac version/build, a matching current-candidate
entry in `Documentation/ReleaseNotes.md`, a resolvable release base, matching
mobile marketing versions and build numbers, and the same version in the Mac
What's New page. Release-input checks repeat this gate before package
verification. A stale or missing version history stops the build.
