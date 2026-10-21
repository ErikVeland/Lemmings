# Narrative copy audit and proposed rewrites

Reviewed 21 October 2026 against the working tree at `2c632f64`. The
[narrative direction](NarrativeDirection.md) is adopted. The individual assessments
are now implemented as a larger [ten-word catalogue](LemmingAssessments.md).
The other replacements below remain proposals. Original assets are unchanged.

The twelve individual proposals below record the intermediate editorial pass.
They informed the implemented catalogue, which adds the owner's ten-word limit,
more happiness and sadness, and enough distinct stories for ordinary cohorts.

The shared writing already has affection and several good jokes. The main gaps
are uniformly gentle character details, academic Trolley prose, result wording
that pressures another attempt, and original L2 commentary that blames the
player. Most instructions and status labels should stay literal.

## Coverage and limits

This is a source audit of English narrative and adjacent player-facing copy
across all three games. It follows shared definitions to their Mac and mobile/TV
presentation paths. The English localisation table supplied a searchable
inventory of 3,235 keys; that count includes diagnostics and technical labels,
not 3,235 narrative passages. Current source takes precedence over generated
catalogue references.

The original audit found all 24 personality lines missing from the English
catalogue. Implementation replaces them with 256 directly extracted story lines
in `LemmingAssessmentCatalogue.swift`. English extraction is now covered;
translation of those new lines into the other eight languages remains pending.

| Surface and source | Coverage and finding | Decision |
| --- | --- | --- |
| Shared [individual catalogue](../Sources/LemmingsAppCore/Records/LemmingInspection.swift) | The audit covered all 12 original preference/want pairs, names, statuses and action descriptions. Classic, L2 and L3 share the model. | Implemented: 128 complete ten-word stories. Names and observed history remain literal. See [the current catalogue](LemmingAssessments.md). |
| [Mac inspection](../Sources/LemmingsLocal/LemmingInspectionPage.swift), [hover](../Sources/LemmingsLocal/LemmingInspectionHover.swift), [shared inspection page](../Sources/LemmingsGameArt/LemmingInspectionArt.swift) and [mobile host](../Sources/LemmingsMobileUI/MobileGameViewController.swift) | The personality and recorded-action fields share an existing optional surface. | Reuse it. No live commentary or new overlay. |
| [Trolley affinity](../Sources/NxlvKit/TrolleyAffinity.swift) and [classification](../Sources/NxlvKit/TrolleyPhilosophy.swift) | All 14 archetypes, explanatory text and special titles. Some prose is definition-only rather than current visible copy. | Revise fictional summaries and specific misleading descriptions. Keep real philosophy summaries factual. |
| [Trolley awards](../Sources/NxlvKit/TrolleyHistory.swift), [award collection](../Sources/NxlvKit/TrolleyAchievementCollection.swift), [Arcade awards](../Sources/NxlvKit/ArcadeRecords.swift) and [campaign achievements](../Sources/NxlvKit/ClassicAchievements.swift) | Names and criteria across shared and campaign-specific awards. Existing humour includes “Do Not Disturb”, “Somehow, That Worked” and “Oh No! No More”. | Keep useful humour and exact criteria. Proposed name changes below. |
| [Celebration copy](../Sources/NxlvKit/TrolleyCelebration.swift), [retry targets](../Sources/NxlvKit/TrolleyLeaderboards.swift), [reward receipts](../Sources/LemmingsAppCore/Records/ResultAwards.swift) | Separates visible record receipts from generated next-goal/retry prose that has no current presentation consumer found in this audit. | Preserve receipts. Neutralise guilt and overclaims before reusing dormant prose. |
| Classic [briefing, result and campaign flow](../Sources/LemmingsLocal/main.swift) | Requirements, result overlays, repeat-play prompt and campaign endings. | Keep factual results; shorten the optimisation prompt. Original level titles remain intact. |
| L2 [native frontend](../Sources/LemmingsLocal/Lemmings2PlayWindow.swift), [introduction](../Sources/NxlvKit/Lemmings2Introduction.swift) and [ending](../Sources/NxlvKit/Lemmings2Ending.swift) | Modern result text and extracted original introduction, medal, ending and credits text. The fallback result selects MEDALS string 4. | Replace the fallback taunt in the edition's presentation. Preserve archival assets. Other original candidates are separated below. |
| L3 [native host](../Sources/LemmingsLocal/Lemmings3PlayWindow.swift), [story flow](../Sources/LemmingsLocal/Lemmings3StoryFlow.swift), [movie player](../Sources/LemmingsLocal/OriginalMoviePlayer.swift) and [media documentation](Lemmings3OriginalMedia.md) | Authored instructions, result gate, movie titles and media entry/return paths. | Keep operational text. Original movie pixels and audio still need a content review; do not invent a transcript. |
| [Hints](../Sources/LemmingsAppCore/Hints/LevelHints.swift), [learning journey](../Sources/NxlvKit/LearningJourney.swift), [short play](../Sources/LemmingsAppCore/Collections/ShortPlayCatalogue.swift) and [mobile hints](../Sources/LemmingsMobileUI/MobileGameHints.swift) | Checked-route language, general coaching, skill instructions and route names. | Keep helpful and literal. No jokes between a requested hint and its answer. |
| [Mac shared results](../Sources/LemmingsLocal/ResultCelebrationView.swift), [result actions](../Sources/LemmingsLocal/ResultLayout.swift), [Trolley pages](../Sources/LemmingsLocal/TrolleyResultView.swift), [mobile records](../Sources/LemmingsMobileUI/MobileRecordsPages.swift) and [shared frontend](../Sources/LemmingsGameArt/GameFrontEnd.swift) | Outcome, rescue facts, awards, player ownership and next actions. | No extra narrator line. Reuse shared text where the same field is presented. |
| [English catalogue](../Sources/NxlvKit/Resources/Localization.bundle/en.lproj/Interface.strings), [original L2 extraction](../Tools/Localisation/l2-original-text.json) and [caption translations](../Tools/Localisation/captions.tsv) | Inventory and provenance checks; original text is distinguishable from edition text. | Regenerate catalogues only when implementing. Other languages require a separate editorial pass. |

No game was launched. Original movie captions, pixels and spoken performances
were not reviewed. Original/community level titles were treated as preserved
content, not rewritten individually. This pass does not certify translation
quality, rendered fit, audiovisual tone or every legacy path's reachability.

## Shared individual details

Original source: `LemmingInspection.characters`, now replaced by
`LemmingAssessmentCatalogue`. Each cell below contains the two fields in order
at the time of the audit. These describe fictional personality, never a measured mood or
an explanation of an outcome. Each assessment offers facts about an offstage
domestic life with unexplained precision and measured reassurance. The lemming's
name supplies the subject. Some facts remain quiet and affectionate.

| ID | Current pair | Proposed pair | Decision |
| --- | --- | --- | --- |
| I01 | Collects smooth stones. / Wants a striped one for the collection. | Owns seven smooth stones. / One is reserved for visitors. | Report a private hospitality arrangement with exact inventory. |
| I02 | Likes the sound of rain. / Would like a dry place to listen. | Enjoys the sound of rain. / Has described indoor rain as unnecessary. | Record a modest opinion as useful personal information. |
| I03 | Enjoys a good view. / Hopes to see the sea someday. | Has seen the sea on two occasions. / Recognised it the second time. | Give an ordinary competence the dignity of an achievement. |
| I04 | Likes company. / Would welcome a quiet place to sit together. | Is welcome in three kitchens. / May sit down in two of them. | Precise social standing, with an unexplained qualification. |
| I05 | Keeps bits of coloured string. / Wants to make something with them. | Keeps string in a designated drawer. / The drawer has received no complaints. | Offer reassurance about an arrangement nobody questioned. |
| I06 | Enjoys small discoveries. / Hopes to find a shell. | Owns a shell from an inland shop. / Accepts the shop's account of its origin. | Establish a tiny matter of trust without resolving it. |
| I07 | Likes a familiar tune. / Wants to remember how the next bit goes. | Is known to hum at home. / The tune has not been identified. | Let the report know too much and too little at once. |
| I08 | Has a soft spot for moss. / Would like a little patch of garden. | Has been consulted about moss. / Was given time to finish. | Treat being listened to as a quiet distinction. |
| I09 | Likes watching clouds. / Hopes the next one looks like a duck. | Recognises four kinds of cloud. / Prefers the one that came on Tuesday. | Let classification and personal recollection coexist without correction. |
| I10 | Enjoys the smell of toast. / Would like a warm breakfast. | Uses a different spoon on Sundays. / The food remains the same. | Present an inconsequential ritual with complete seriousness. |
| I11 | Collects interesting leaves. / Hopes to find a red one. | Has received a leaf by post. / Still thinks about the gesture. | Leave an odd, tender fact alone. |
| I12 | Likes a tidy shelf. / Needs somewhere for all these stones. | Owns a shelf of adequate depth. / Has been reassured about its width. | Imply a concern through the reassurance supplied. |

These replace the earlier trait-and-wish proposals. The second field may be
another fact; it does not need to state a want. Present both with equal weight.
No quotation marks, narrator label or extra explanatory caption is needed in
the game. The quiet unease belongs in the information and its delivery.

Keep “Reached the exit”, “Lost”, “Recorded actions”, “No recorded assignments”
and the skill/action names. Do not replace a factual status with a quip or pair
a character's hobby with a death announcement.

The implemented mapping retains the original identity seed for names and uses
a frozen version-2 story catalogue. The owner's requested replacement applies
to older saved runs too: they stored no personality text or catalogue selector.
Subsequent retries and restores reproduce the new story. This is an explicit
one-time copy migration. See the [identity contract](LemmingAssessments.md) before
any future catalogue change.

## Shared Trolley voice

### Visible fictional summaries

Source: `TrolleyAffinity.philosophySummary`. The Mac popover actually displays
this field. Keep all nine named philosophers' factual summaries: Bentham, Mill,
Kant, Singer, Aristotle, Epicurus, Hobbes, Sartre and Popper. Their educational
role is useful and does not need a joke in every entry.

| ID | Style | Current | Proposed |
| --- | --- | --- | --- |
| T01 | Absurdist | A fictional play style for an unlikely rescue. Inspired by the tension between our search for meaning and an indifferent world. | A fictional play style for an unlikely rescue. The universe offers no explanation. The exit will do for now. |
| T02 | Humanist | A fictional play style centred on care for each lemming. Humanism places human welfare and agency at the centre of ethics. | A fictional play style centred on care for each lemming. The quota has a number. The crowd has names. |
| T03 | Bureaucrat | A fictional play style for meeting the minimum exactly. The Bureaucrat values a completed checklist. | A fictional play style for clearing at or just above the minimum. The form has no box for mixed feelings. |
| T04 | Trolley Operator | A fictional play style inspired by the trolley problem: whether sacrificing one person to save several can be justified. | A fictional play style for a recorded sacrifice that enabled other rescues. The arithmetic works. The argument continues. |

Keep the Fellow Traveller fallback: “A neutral play style for a run that does
not strongly match another style. It is not a score or an achievement requirement.”
It explains a state and avoids calling an ordinary attempt morally inadequate.

T03 also fixes a factual mismatch: the classifier permits a distance of one from
the requirement. T04 must remain behind causal evidence. Current engine adapters
do not establish that evidence; the new wording does not unlock the style.

### Observations and optional questions

Source: `TrolleyAffinity.affinityDescription`. Keep these observations distinct
from the fictional summaries. Most already do their job without added comedy.

| ID | Current | Proposed | Reason |
| --- | --- | --- | --- |
| T05 | Full rescue with no destructive skills or nuke. | Verified rescue maximum met without destructive skills or a nuke. | Kant's gate uses the verified maximum, which need not equal the entire population. |
| T06 | A high rescue rate, well above the minimum. | A high rescue rate, well beyond the requirement. | Retain the Humanist observation; the summary supplies the voice. |
| T07 | Level cleared with extensive skill use, nukes or rewinds. | Level cleared using several skill types, with a nuke or repeated rewinds. | The gate requires either a nuke, at least three skill types and sufficient intervention, or at least five rewinds and five skill types. The current list can imply that any one condition is enough. |

Keep the remaining descriptions: evidenced sacrifice for Bentham/Operator;
efficient rescue for Mill; resource use for Singer; balance for Aristotle;
little intervention for Epicurus; a clear despite losses for Hobbes; a documented
unusual route for Sartre; exceeding a target for Popper; minimum-adjacent clears
for the Bureaucrat; and no strong match for the Fellow Traveller.

The separate `TrolleyArchetype.interpretation` strings include “Consequentialist
optimisation with a strong rescue outcome” and “Measurable rescue benefit per
scarce resource.” No presentation read of that property was found. The analyser
stores `affinityDescription` as its explanation, and the popover reads that same
field. Do not claim to improve the visible game by editing `interpretation`.
Retire the unused prose in a later code cleanup if it has no external consumer,
or make any future presentation use the reviewed fields above.

### Award names and special titles

Keep stable award IDs, eligibility, thresholds and earned history. These are
display-name proposals only. Criteria stay literal beneath a playful title.

| ID | Source and current name | Proposed name | Reason |
| --- | --- | --- | --- |
| A01 | `TrolleyHistory.noLemmingLeftBehind`: No Lemming left behind | As many as possible | Its criterion is a verified maximum, not necessarily a full-population rescue. |
| A02 | `TrolleyHistory.moralSurplus`: Moral surplus | Beyond the quota | Extra rescues are observable; surplus virtue is not. Keep the 100-extra-rescues criterion. |
| A03 | `TrolleyPhilosophy.lastLemming`: One Lemming left behind | One short of the maximum | A gap of one does not prove that one identifiable actor was abandoned or died. |
| A04 | `TrolleyPhilosophy.pyrrhicVictor`: The Pyrrhic Victor | A qualified success | An outcome with losses can raise a question without assigning the player a moral identity. Definition-only title; no current direct title renderer found. |
| A05 | `TrolleyAchievementCollection.mill`: A Mill-ion Reasons | It adds up | Keep a dry observation; reduce dependence on a name pun. |
| A06 | `TrolleyAchievementCollection.bureaucrat`: Form 27B/6 | Filed under success | Let the institutional joke stand without recognising a borrowed reference. |
| A07 | `TrolleyAchievementCollection.humanist`: People, Not Percentages | Room for everyone | Let the title express care with less instruction to the audience. The criterion still describes a high-rescue style, not a claim that everyone survived. |
| A08 | `TrolleyAchievementCollection.targetScholar`: Beyond Reasonable Doubt | The argument continues | Matching best-known targets on ten levels does not prove optimality. |
| A09 | `ArcadeRecords.betterRescue`: ONE MORE HOME | MORE HOME | An improvement can exceed one. Keep the sincere celebration. |

Keep “Perfectly adequate”, “One more”, “Above and beyond”, “Small Budget, Big
Heart”, “Do Not Disturb”, “Somehow, That Worked”, “Still Thinking”, “Second
Thoughts”, “The Last Word”, “HANDS OFF” and “LESS IS MORE”. Keep “Kant Touch This”
as an occasional period-flavoured pun, not a template for every award.

The remaining collection, rivalry, mastery and campaign titles can stay. Keep
the campaign-specific “The Original”, “Oh No! No More”, “Twelve Tribes”, “A New
World” and “The Trilogy”, with their completion requirements. A new joke is not
automatically an improvement over a familiar name.

### Retry and near-miss wording

These are future-use corrections unless a renderer is identified. Source search
found `TrolleyRetryTarget` produced in reports and `nextGoal` produced by
`TrolleyCelebration`, but no current UI read of their prose. Do not add a visible
near-miss panel to justify the rewrites.

| ID | Current | Proposed | Source and condition |
| --- | --- | --- | --- |
| R01 | One Lemming left behind. Bring home `value`. | One more rescue would match the target of `value`. | `TrolleyRetryTarget.suggest`, one below a supported rescue target. |
| R02 | Reach 100% | Match the rescue target | Same function. A supported maximum may be below the total population. |
| R03 | Find a better way | Try another approach | Same function, fallback label. Avoid making another attempt a moral correction. |
| R04 | SO CLOSE! `gap` more to rescue for three stars. | `gap` more to rescue for three stars. | `TrolleyCelebration.nextGoal`; remove the conditional pressure prefix. |
| R05 | ALL THREE STARS! This level's rescue goals are met. | Rescue goals met. | Same field. If the stars already convey this, omit the sentence entirely. |

Keep the visible new-record receipts and factual reward reasons. Keep “Third-star
target unknown. Your clear still counts.” if that dormant field is later used:
it has a useful reassurance and does not invent a target.

## Classic

Classic's authored results are already restrained. “Not this time” gives failure
room without calling the player incompetent. The briefing provides actual
requirements. Original level names supply much of the game's wordplay.

| ID | Location and current text | Proposed text | Placement |
| --- | --- | --- | --- |
| C01 | `main.swift`, Classic and fan result overlays: R RETRY - SAVE MORE, USE LESS | R RETRY | Keep the shortcut; remove the unsolicited optimisation instruction. |
| C02 | `ArcadeWindow.swift`, shared empty career page: Your first rescue starts the story. | Every story starts somewhere. Usually near a hatch. | Replace the existing flavour line only. Shared across all games, not a Classic-only string. |

Keep “Level complete”, “Not this time”, rescued/needed counts, rank completion,
“Every rating is finished”, and Continue/Retry/replay instructions. Keep “Your
rescue story” as the achievements heading. No extra joke is needed on a result
that already has a strong image, music and clear next action.

## Lemmings 2

### Current edition result path

Source: `Lemmings2PlayWindow.swift`, `.results`. A read-only extraction of the
shipped `MEDALS.IFF` confirmed the selected fallback, `strings[4]`, below.
Other medal-bank taunts are not all selected by this native branch. The shared
Trolley result path also exists; verify both presentation paths before shipping.

| ID | Current | Proposed | Decision |
| --- | --- | --- | --- |
| L201 | Oh Dear. You seem to have made this tribe extinct! | This evacuation needs another plan. | Replace the native fallback presentation. Do not overwrite the original bank. |
| L202 | Click to continue. Your survivors will go on to the next level. | Your survivors continue to the next level. | Keep the carry-over fact. The existing Continue control supplies the action. |

Keep the medal name, actual saved count, Retry/Continue/Menu and “Oh dear!” where
it serves as the short no-medal heading. No new quip needs to describe the count.

### Original medal catalogue

The following are edition alternatives for original material, not a claim that
each line is currently displayed. Preserve the original text in its asset and
archival presentation. Use these only if that original selection path is used
by the edition's normal results, with the same factual outcome gates.

| ID | Bank index and original | Edition alternative |
| --- | --- | --- |
| L203 | 9: Uh oh. That was a feeble effort. | The evacuation plan needs work. |
| L204 | 10: You saved so few that they are going to be very lonely. | The survivors have arrived. The committee has questions. |
| L205 | 11: That wasn't very impressive was it? | The plan looked better on paper. |
| L206 | 12: That just wasn't good enough. They're relying on you. | The exit remains open to other ideas. |
| L207 | 13: Not bad, but not good either. | The report has settled on “mixed”. |
| L208 | 15: That was a passable effort. Must try harder. | A pass. The stamp is quite definite. |
| L209 | 16: Do you think those were acceptable losses? | The form calls this acceptable. |
| L210 | 18: You obviously had few problems there. | The report makes this look straightforward. |
| L211 | 20: Nice one! But can you give that extra bit of effort? | A good result. No further remarks. |
| L212 | 22: Excellent! A gold standard successful rescue attempt. | Gold standard. Officially. |

L204 requires actual survivors. L208 and L209 require a native pass. These
alternatives move the unease to the reporting institution. They must not be
selected indiscriminately after a failure or added beside existing result prose.

Keep bank 14 (“A little practice might be what you need”), 17 (“That was a
reasonably good go”), 19 (the grade A line) and 21 (“That was a sparkling
performance”) as serviceable original material. They do not all need replacement.

### Original story and ending

The prophecy/Ark story already puts a grand existential threat next to the
practical work of evacuation. Preserve the Story-Keeper dialogue and the
Talisman/Ark plot. Do not retroactively turn every character into a bureaucrat.
The credits' mock-grand titles and mundane development anecdotes already provide
the desired contrast. Keep the original credits intact.

Two further edition alternatives are useful if these ending texts are adapted:

| ID | Original | Edition alternative |
| --- | --- | --- |
| L213 | You have indeed proved to be the one predicted in the prophecy. But if you were to do it all over again, could you do any better? | The prophecy was right about you. It was rather vague about the paperwork. |
| L214 | Why not revisit some tribes, save a few more Lemmings and then be rewarded by watching them leave the Island to their new land. | Revisit tribes to improve their survivor counts and qualify for the Ark departure. |

L213 is a closing beat for a completed story, not a request to replay it. L214
is functional guidance and deliberately has no joke. Keep the separate exact
requirement of at least half of each tribe plus a full gold Talisman wherever
that original ending route requires it. Do not imply that any extra rescue
automatically earns the departure.

## Lemmings 3

The native host's new writing is mostly operational. Keep “Need 50 survivors to
complete this tribe”, “That lemming cannot use this action now”, the brick/spade
direction instruction, restored-run guidance and the End run warning. In
particular, retain “Rescued lemmings and reserves will be retained”: reserves
are neither rescues nor deaths.

L3 receives I01–I12, applicable Trolley revisions and shared award changes
through the shared models. No engine-specific narrator needs to be invented
just to give the audit a third set of replacements.

The five original movies are `INTRO.FLI`, `C-LEV15.FLI`, `SHA-WALK.FLI`,
`E-LEV10.FLI` and `THE-END.FLI`. The source exposes movie names and playback
policies, not a line-by-line narrative script. Keep their titles, Skip/Pause/Back,
original voices and story triggers. A silent frame review and transcript check
remain necessary before proposing changes to their content. This audit does
not certify the media's tone or complete mobile/TV movie parity.

The original-media documentation also records unverified triggers for three
intermediate movies. Writing cannot close that engine/media validation gap.

## Boundaries for implementation

1. Apply agreed wording in shared definitions, not separate copies for each
   engine. Preserve original data and stable record/award identifiers.
2. Preserve the frozen assessment catalogue and original name seed. Future
   catalogues need a persisted version selector before changing retained runs.
   Keep stored attempt explanations intact.
3. Keep evidence gates. Bentham, Sartre, Trolley Operator and unsupported
   sacrifice achievements must not become available because their copy improved.
4. Preserve functional text: controls, accessibility, error recovery, save status,
   Hot Seat ownership and Ready. Keep handovers paused. Do not rename Retry or
   Continue to an in-world joke.
5. Regenerate localisation from source with the existing tooling. Review the
   other eight bundled language tables for timing, idiom and placeholder parity.
   A literal translation of “Kant Touch This” is not required.
6. Inspect the rendered states and input targets before declaring any UI change
   complete. The Mac affinity popover has fixed text areas; shorter English alone
   does not prove translated fit. Check Classic, L2 and L3 on the supported hosts.

Original audit validation: document links, whitespace and 45 source quotations
passed; the 49 review rows have unique IDs. The character quotations now describe
the superseded catalogue. Implementation validation is recorded with the
[current assessments](LemmingAssessments.md).
