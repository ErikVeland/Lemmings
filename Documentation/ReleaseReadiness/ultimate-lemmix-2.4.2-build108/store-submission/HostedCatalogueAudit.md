# Hosted catalogue audit

The catalogue gap does not block the clean starter release. The live catalogue remains unchanged to preserve existing star awards.

Checked 19 November 2026. This audit read catalogue data and source code. It did not query production player records.

## Exact comparison

The counts describe exact-condition entries, not unique levels. Population variants can produce multiple entries for one level.

The live catalogue has 512 entries for 501 level identities. The current catalogue has 609 entries for 558 level identities.

| Comparison | Entries |
| --- | ---: |
| Same conditions | 438 |
| Same conditions and target | 429 |
| Same conditions, higher target | 9 |
| Added Lemmings 2 conditions | 85 |
| Added Lemmings 3 conditions | 86 |
| Removed Lemmings 3 conditions | 74 |

All 74 removed entries use `l3-native-preview-v1`. Seventy have replacements with the same conditions except the ruleset and physics version.
These replacements use `l3-native-preview-v2`, as recorded in `Tools/TrolleyVerification/rule-changes.json`.
Four old levels have no current winning target: Shadow 7, Egyptian 6, Egyptian 13 and Egyptian 29.
The new Lemmings 3 entries also cover 16 additional level identities.

The 85 added Lemmings 2 entries cover 45 additional level identities.
They contain 44 entries with population 60, 38 with population 1, two with population 2 and one with population 4.
All other campaigns retain their existing exact conditions and targets.

## Current evidence

All 609 current entries passed the static catalogue validator. All witnesses report completion and a win. All witness file hashes match.
The catalogue contains 294 population-bound proofs and 315 attained rescue records. A rescue record does not prove an absolute maximum.
The current engine fingerprint matches `c9abe4e0aab0410ab43923a4c9b8c5cced89f3e0792f091740b97b5be9c99d93`.
The release already records the reviewed source-equivalence migration. This audit did not rerun engines or change app source.

## Starter behaviour

Neither catalogue contains First Steps, Float to Safety or Over the Rise. Their required rescues are 6/6, 3/3 and 4/4.
The starter generator supplies no cloner skill. Each successful clear therefore saves the full finite population.
`TrolleyRescueGoals` awards three stars for that result without a verified target. The hosted server applies the same population fallback.
The catalogue does not control level availability, unlocks or the engine pass condition. No catalogue update is needed for starter stars.

## Existing star impact

The server recalculates stored stars at startup for every matching catalogue condition. These nine unchanged Lemmings 2 conditions have higher targets:

| Level | Target before | Target now |
| --- | ---: | ---: |
| Mr Lemmy Lives Next Door | 1 | 13 |
| Quad Quirks on the Quay! | 29 | 42 |
| Audex Powder | 47 | 59 |
| This Is The Pits ! | 2 | 57 |
| The Egypt Cottage! | 1 | 3 |
| LEMMING OF NOTTINGHAM | 1 | 2 |
| Swing/Roundabout Theory | 2 | 17 |
| Lem Me Out ! | 26 | 60 |
| Ice Ice Lemy | 1 | 7 |

Each listed condition has population 60 and a pass requirement of one. A run at the old target can lose its third star.
At one rescue it becomes one star. At two or more rescues below the new target it becomes two stars.
Newly added targets can instead promote matching runs that previously used the population fallback.
Replacing the catalogue does not delete old runs. Removed v1 conditions would retain their stored stars but lose their explicit target for future submissions.
The exact number of affected player records is unknown. This audit did not inspect them.

## Follow-up plan

Keep the live catalogue for this release. Treat Lemmings 2 and Lemmings 3 target coverage as a separate preservation follow-up.

1. Review the nine raised targets and define a policy that preserves earned stars.
2. Retain the 74 legacy v1 condition targets for old-client submissions. Do not apply them to v2 runs.
3. Validate current witnesses and source fingerprints before preparing the merged server catalogue.
4. Check migration and future submissions with synthetic old and new condition records.
5. Stop the service and verify a private cold backup before any approved catalogue activation.
6. Verify public service health and synthetic records after activation.
7. Keep current state during rollback. Do not restore an old database after accepting new writes.

A union of the current 609 entries and 74 legacy conditions contains 683 exact-condition entries.
That union alone does not prevent the nine target increases from reducing stored stars. Review the star policy before changing it.

The [JSON receipt](hosted-catalogue-audit.json) lists every added and removed condition hash and all nine changed targets.
Live catalogue SHA-256: `cef047ee50ba55776d52c07cd9d93edd8920160119a83e22f768392b856a9f61`.
Current catalogue SHA-256: `a9c3db008b71e43895fcbd6d5a23245e55dfbf5e51a27795caf3ae6faaefa9a9`.
