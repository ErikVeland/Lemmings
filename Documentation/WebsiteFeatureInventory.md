# Ultimate Lemmix website feature inventory

Reviewed 19 November 2026 for candidate 2.4.2, build 108.
This register governs claims in `Website/content/`. It does not establish a
public release, Store approval or physical-device acceptance.

## Content contract

`Website/content/manifest.json` lists nine routes with their titles, descriptions
and HTML fragment filenames. The generator owns the document shell and h1.
Fragments use semantic sections, headings and root-relative internal links.

The manual has stable anchors: `get-started`, `controls`, `time-and-hints`,
`import-data`, `journeys`, `hot-seat`, `saves`, `presentation` and `desk-clock`.
Support uses `support#contact`. No form, download endpoint or public archive URL
has been invented. All prose uses Australian English.

## Current content and features

| Website claim | Status and boundary | Source |
| --- | --- | --- |
| Three included starter puzzles | Included in the clean Store profile. First Steps, Float to Safety and Over the Rise teach walking, floating and climbing. They are independently authored, not the original game campaigns. | `Sources/NxlvKit/OpenStarterContent.swift`; current Store submission README |
| Lix presentation | Selected Lix sprites, scenery, icons and six CC0 music tracks. The selected scope does not make all upstream files or fonts CC0. | `Resources/AlternativeAssets/lix-source.json`; `music-sources.json`; `THIRD_PARTY_NOTICES.md` |
| Project pixel lettering | Current clean profile uses project lettering. Original font assets belong in the separate import collection. Older personal-build font claims do not describe the Store package. | `Documentation/UltimateLemmix.md`, Store preparation section; submission README |
| Classic, The Tribes, Chronicles and NeoLemmix | Application paths exist. Original campaigns and community packs need compatible data. Chronicles and NeoLemmix remain Beta. No universal level-completion claim. | `Documentation/ReleaseNotes-UltimateLemmix-2.4.2-build108.md`; `Documentation/UltimateLemmix.md` |
| Restore original assets | Validated resource import retains supported media and level libraries. Raw game folders cannot supply absent interface or soundtrack assets. Executables are excluded as standalone payloads. | `Sources/LemmingsAppCore/Import/OwnedResourceLibrary.swift`; `Documentation/UltimateLemmix.md` |
| Resource folder transfer | Extract the prepared ZIP and select Resources. Mac and iOS use local selection; TV uses its temporary local-network page. | submission README; `Sources/LemmingsMobileUI/MobileLibraryViewController.swift`; `MobileTVFileTransfer.swift`; `TVGameImportServer.swift` |
| Original artwork selection | Uses restored source assets. The independent starter retains Lix without changing the saved choice. Some sequel Lix actions use neutral poses. | `Documentation/UltimateLemmix.md`; `Sources/LemmingsLocal/PlayfieldView.swift`; `Sources/LemmingsLocal/main.swift` |
| Pause, steps, rewind and fast-forward | Current shared controls. Rewind is recent attempt history, not an unlimited archive. No claim that every platform input method was exercised in this candidate. | `Documentation/PlaytesterControls.md`; `Documentation/PlatformFeatureParity.md`; `Sources/LemmingsLocal/PlayfieldView.swift` |
| Journey, collections and playlists | Retained application features using available installed content. The three starters do not imply a full bundled campaign library. | `Documentation/UltimateLemmix.md`; `Sources/LemmingsMobileUI/MobileLibraryViewController.swift` |
| Hot Seat | Shared roster, attempt ownership, house rules, paused Ready handovers and retained sessions are implemented. Ghosts are recorded, silent and separate from the live simulation. | `Documentation/HotSeat.md`; current platform parity register |
| Hints | 350 checked Classic identities exist in the retained catalogue. Exact level and engine identity must match. Other content receives labelled general coaching. Do not promise checked starter or sequel solutions. | `Documentation/LevelHints.md`; submission `ReplaySourceEquivalence.json` |
| Replays and rescue targets | Retained evidence covers 609 rescue witnesses and 350 hint entries. Source-equivalence migration did not create new replay results or broader solvability proof. These counts are internal evidence, not included-level totals. | `Documentation/UltimateLemmix.md`; submission `ReplaySourceEquivalence.json` |
| Local saves and recovery | Player, session and compatible checkpoint paths are implemented. Preserve existing saves during support work. A shared campaign is separate from solo progress. | `Documentation/HotSeat.md`; `Documentation/PlatformFeatureParity.md`; privacy notice |
| Automatic cloud library | Implemented provider-dependent sync. Includes profiles, completion records and journeys. Excludes imported media and mid-level engine checkpoints. Live service acceptance remains separate. | current `PrivacyNotice.md`; `Sources/LemmingsAppCore/Records/CloudLibrarySync.swift`; `CloudLibraryTransport.swift` |
| Optional counts and public records | General sharing consent can enable records for players without a separate choice. Explicit player choices remain independent. Removing shared records differs from stopping future submissions. | current `PrivacyNotice.md`; `Sources/LemmingsGameArt/MobileSettingsArt.swift` |
| Game Center | Implemented service integration. Mac/iOS compatible solo saves and TV cloud-library path differ. Provisioning or a visible setting does not prove live sign-in or leaderboard acceptance. | current privacy notice; submission `AccountAndServices.md` |
| Desk Clock, widgets and Top Shelf | App feature and extensions retained. Optional calendar event display stays local. Physical widget refresh and signed App Group behaviour are separate acceptance checks. | privacy notice; current Store submission README; `MobileSettingsArt.swift` |
| HD effects and accessibility reductions | Effects retained, with the deliberate TV budget. UI size, static Home, reduce motion, reduce flashes and separate audio controls are implemented. | `Sources/LemmingsGameArt/MobileSettingsArt.swift`; `Documentation/PlatformFeatureParity.md` |
| Accessible names and controller options | Source includes labelled native controls, targeting help and button remapping. No complete VoiceOver, Switch Control or conformance claim. | `Sources/LemmingsLocal/GameplayControlHelp.swift`; `GameSettingsHelp.swift`; `MobileSettingsArt.swift` |

## Actual presentation evidence

The current dossier contains `MacPresentation.json` and
`MobilePresentation.json` under
`Documentation/ReleaseReadiness/ultimate-lemmix-2.4.2-build108/store-submission/`.

- Mac: the final arm64 candidate renders Home and a running First Steps level.
  Six Lix actors are visible with the saved Lix choice false. All 42 recorded
  target frames fit inside the window. Capture was muted, offscreen and isolated.
- iPhone, iPad and TV: actual Home screens from clean Debug simulator builds.
  These are not physical-device gameplay checks or Release-binary runtime proof.
- Raw captures remain outside the repository in the Store handoff root.
  RGB-only submission copies preserve every RGB pixel, dimensions and colour
  profiles. No marketing scene or platform screenshot was fabricated.
- Mac images: 2560 × 1600. iPhone: 1206 × 2622. iPad: 2064 × 2752.
  Apple TV: 3840 × 2160.

The current universal Mac build includes Apple silicon and Intel. The capture
exercised arm64 only. Mobile identifiers are being unified during the current
release work. Website content does not hard-code those identifiers or App Store
links. No minimum OS version is advertised without final release metadata.

## Privacy facts and publication checks

Primary notice:
`Documentation/ReleaseReadiness/ultimate-lemmix-2.4.2-build108/store-submission/PrivacyNotice.md`.
The notice is a reviewed implementation draft, not proof of deployed retention.

Privacy declarations also appear in:

- `Resources/UltimateLemmix/PrivacyInfo.xcprivacy`
- `Apps/UltimateLemmixIOS/PrivacyInfo.xcprivacy`
- `Apps/UltimateLemmixTVOS/PrivacyInfo.xcprivacy`

The website notice preserves these distinctions:

- Local play requires no separate hosted account. This does not mean every
  enabled feature is offline or that network providers receive no information.
- Cloud saves are automatic and independent of optional count-sharing consent.
- Encrypted library content differs from service-visible identifiers and
  authentication metadata. The service stores the authentication credential as
  a hash. It does not receive the plaintext sync password or encryption key.
- Optional aggregate events omit player names and device identifiers. Public
  records use initials, run data, replays and a per-player credential.
- Off switches stop future submissions. Hosted record removal is a separate
  action and can remain pending when offline.
- Daily aggregate rows older than 90 days are pruned when the service adds an
  event or serves a summary. This is not a timed deletion at exactly 90 days.
  Lifetime totals have no automatic expiry. Rankings and replays have no
  automatic age-based expiry.
- Device links: ten minutes, one redemption. Cloud backups keep the three newest
  successful snapshots. Daily success was not verified, so these are not described
  as three daily snapshots. Apple controls its own service retention.
- Website server logs are separate from app sharing preferences. The deployment
  owner verified that this site disables routine nginx access logs and has no
  analytics, tracking cookies or submission forms. Error logs rotate daily with
  14 rotated archives retained, with older files compressed. This is an archive
  count, not an exact 14-day deletion deadline. Journald has no explicit retention
  period. Operating-system
  logs can remain longer under system limits. Confirm this configuration remains
  true when the site is deployed.

The root task supplied these verified live retention facts on 19 November 2026.
They supersede the earlier source-only daily-backup wording in the draft app
privacy notice. Both website privacy pages now use the verified limits.

`erik@veland.au` is the contact supplied by the root task after checking the
existing `/Users/veland/GenErik DJ/website/site.json`. The deployment agent also
verified the address on `https://dj.generik.au/support` and `/privacy`. The
fragments use this real address for support and privacy, not an invented mailbox.

Apple Standard EULA reference:
`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`.
The terms page points to that agreement and adds no custom legal conditions.
It does not claim that a licence for app code covers imported media.

## Rights and credit boundaries

`Documentation/HeritageCredits.md` supports the historical creator roles.
`Resources/AlternativeAssets/music-sources.json` supplies all six current Lix
track titles and authors. The pinned upstream copying notice scopes CC0 media.
Third-party font notices retain their own terms. Do not call all fonts CC0 or
claim that all lettering is the original game's artwork.

The owner confirmed redistribution permission for the separate restoration
collection. Supporting records are pending attachment and review. The ZIP has
not been publicly hosted. These pages offer no restoration download and do not
present compatibility or attribution as permission to redistribute.

## Not promoted as completed

- Public release, App Store approval or store availability.
- A universal App Store purchase or cross-platform entitlement promise.
- Physical iPhone, iPad, Duo or TV gameplay and input acceptance.
- Live cloud recovery, Game Center or leaderboard acceptance for the new product.
- Every imported level being compatible, completable or supplied with a solution.
- A fully bundled original campaign library, original fonts or remix collection.
- Complete screen-reader access or WCAG conformance.
- Planned narrative rewrites from the copy audit. The direction is a tone guide;
  it is not evidence that every example is an implemented feature.

## Checks performed

Read source and current product-specific release evidence. Wrote only the owned
content directory and this inventory. Checked fragment structure, route metadata
and internal anchors. No app source, resource or publication manifest changed.
No tests, UI launch, browser, deploy or upload ran for this content task.
Rendered website and keyboard acceptance belong to the generator integration.

## Privacy completeness check — 19 November 2026

Reviewed the current fragments again before adding diagnostics, support
correspondence, family choices, data requests and policy changes.

- `Package.swift` and `Package.resolved` list Sparkle as the remote package.
  Searches of app targets and source found no dedicated crash-reporting SDK or
  diagnostic-upload path. The public statement is limited to this candidate.
  It does not claim that Apple or the operating system never collects diagnostics.
- A diagnostic file voluntarily sent to support becomes correspondence. The
  policy asks users to review files before sending them. It does not state a
  mailbox retention period or promise automatic deletion.
- Support email is voluntary and is used to reply and investigate the request.
  Access, correction and deletion requests use the verified contact. No new
  legal entitlement, response deadline or universal deletion guarantee is claimed.
- Family guidance explains public initials, scores and eligible replays. It
  asks parents and guardians to review general and per-player sharing choices.
  No age restriction, children's-privacy certification or legal conformance is
  asserted.
- `Sources/LemmingsLocal/SettingsWindow.swift` provides **Clear this Mac's counts**
  in Privacy, with a **Clear counts** confirmation.
  `Sources/LemmingsGameArt/MobileInformationArt.swift` and
  `Sources/LemmingsMobileUI/MobileInsightsPages.swift` provide **Clear local
  counts** in Play Insights and the confirmation route.
- `Sources/LemmingsAppCore/Privacy/AnonymousTelemetry.swift:216` saves existing
  counts to a local recovery backup before clearing the current counts. Both
  pages now explain that reset can retain earlier counts. It is not complete
  local-data erasure, and it does not remove public records or cloud saves.
- Saved-game and imported-data removal instructions do not tell users to delete
  files blindly. They direct recovery questions to support and preserve sources.
- The notice has its 19 November 2026 date and a policy-change section. No promise
  of an email notification or retrospective consent mechanism is added.

## Hosted action replay transport — 19 November 2026

The deployment agent reports that hosted action replay transport was deployed
and checked on 19 November 2026, Brisbane time. A temporary player uploaded a
bonus-skill replay through public HTTPS. The download matched its SHA-256.
Score authentication, movie compatibility and removal of the temporary player,
records and both replay files passed.

Server source SHA-256:
`3ccaf3390ddf7dcdeede16754ea00cb5b673d2cb813c80217b36e4cb361cb443`.

The live catalogue remains at 512 levels while the app catalogue has 609.
This service-code update does not close that catalogue gap. No app engine code
changed. The deployment receipt is `HostedActionReplayRelease.md` in the current
Store submission dossier. This scoped service evidence does not establish live
Game Center, every leaderboard or full cross-device cloud acceptance.
