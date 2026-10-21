# Narrative direction

Adopted 21 October 2026. This is the writing direction for Ultimate Lemmings
across Classic, Lemmings 2 and Lemmings 3, including their shared interfaces.
The [copy audit and proposed rewrites](NarrativeCopyAudit.md) apply it to the
current source. The [ten-word individual assessments](LemmingAssessments.md)
are implemented; the other audit rewrites remain proposals.

**The universe is indifferent. These little idiots matter anyway.**

The player tries to care for people through a system that considers a certain
number of deaths acceptable. The game cheerfully supplies a percentage. The
player is allowed to notice what that means, laugh at it, and go back for one
more. No cosmic authority needs to certify that caring was worthwhile.

This is a funny game with an awareness of real horror. Its positive nihilism
allows tenderness, absurdity and dread to occupy the same scene. The world
offers no guarantee of meaning or fairness. People still make plans for Thursday.

## Creative compass

The owner's references are *Widow's Bay*, *Severance*, *The Good Place*,
*Theme Hospital*, *The Sims*, *SimCity*, and early 1990s LucasArts and Sierra
games. Use them as a shared creative compass, not a source of borrowed lines,
characters or a single imitation voice.

The repository's wider reference set also includes David Lynch, Monty Python,
*Monkey Island*, *Day of the Tentacle*, *Are You Afraid of the Dark*, *Riget*,
*Eerie, Indiana* and Roald Dahl. Leave room for the uncanny, strange local
customs, playful menace and absurd escalation as well as institutional satire.
The world may be unsettling without immediately explaining why.

Our reading of that brief is a cheerful surface over alarming arrangements,
ordinary people within absurd systems, philosophical questions made playable,
and confidence that the audience can recognise a contradiction without a speech.
The 1990s sensibility lives in timing, specificity, visual comedy and irreverence.
Period slang and references alone do not create it.

The comedy can be dark, sharp and uncomfortable. Let institutional certainty,
arbitrary quotas, managerial language and cheerful evasions expose the horror.
Avoid topical references that expire before the next release. The same joke
should make sense to someone who has never read the news item that inspired it.

## What the writing believes

- **Authority is confidently inadequate.** The rescue quota has been approved.
  Nobody checked whether that was reassuring. The joke targets the arrangement
  and its justifications, not the person struggling with the puzzle.
- **Individuals have small, specific lives.** A taste, a hobby, a petty opinion
  or a social misunderstanding makes a sprite worth noticing. Give them variety,
  including vanity, optimism, fussiness and quiet companionship.
- **The player is implicated and welcome.** Accepting a quota is part of the
  premise. Retrying, experimenting and continuing after an imperfect clear remain
  legitimate choices. The game does not diagnose the player's character.
- **Care needs no grand justification.** Extra rescue may be moving without a
  lesson about morality. Let kindness land without a punchline retracting it.
- **The world takes its absurdity seriously.** Its inhabitants have things to
  do. They do not all wink at the camera or know that they are in a game.

## Voices and comic range

The official voice is brisk, composed and occasionally revealing. Its forms,
targets and commendations are more certain than the world warrants. Use this
voice where the game already classifies, awards or reports. Do not invent a
named department, employer or governing organisation as established canon.

Every authored individual assessment uses the emotional arrangement of an innie
receiving facts about their outie in *Severance*: a composed voice supplies oddly
specific facts about an ordinary life elsewhere. The facts are presented with
measured warmth and complete confidence in their relevance. Nobody explains
why this information was collected or why it should be reassuring.

Push the facts towards the banal and absurd. Someone owns a second spoon.
Someone is welcome in three kitchens but may sit down in only two. An ordinary
possession receives a level of scrutiny that suggests a much stranger world.
Affection comes from the life glimpsed through the report. The speaker does not
announce the joke, invite a reaction or explain what the detail says about them.

Optional Trolley interpretation is curious and dry. It raises a question or
notices an absurdity without pretending that a score has solved ethics.
Descriptions of actual philosophers stay accurate and clearly distinct from
fictional play styles.

Practical help is direct and generous. A player who asks for help should receive
it. Navigation, accessibility, errors, recovery instructions, costs and reward
criteria use literal language. Their clarity is part of the game's kindness.

Vary the mechanisms: understatement, incongruity, bathos, an oddly specific
ambition, a straight-faced institutional response, an occasional pun and a
moment with no joke at all. A committee joke is one tool, not the whole voice.

## Individual assessment voice

This voice governs every fictional personality assessment in Classic, L2 and L3,
including the short inspection fields. The lemming's name supplies the subject.
Use brief declarative facts beneath it, as though someone has carefully selected
the information for the lemming's benefit. Address the fictional life, not the
real player. Keep recorded actions and statuses in their separate factual fields.

- Report possessions, domestic routines, minor reputations, modest permissions
  and inconsequential achievements with equal gravity.
- Use occasional exact counts, peculiar qualifications and unsolicited
  reassurance. The precision can be impeccable while its purpose remains obscure.
- Let a second fact quietly complicate the first. It can also stand alone.
  Do not make every pair a setup followed by a conspicuous punchline.
- Prefer a report of an ordinary event to a generic trait: “Has been consulted
  about moss” carries more life than “Likes moss”.
- Leave some facts tender or unremarkable. “Still thinks about the gesture”
  can carry the warmth without a joke retracting it.
- Keep the delivery calm. No exclamation marks, knowing asides, comic verdicts,
  therapeutic instructions or requests to appreciate the information.

The reports are authored fiction about life outside the attempt. They do not
establish an employer, surveillance mechanic, divided identity or hidden needs
system. Use original language and situations; the reference supplies the
relationship between speaker, listener and information, not dialogue to borrow.

Examples of the assessment voice:

> Owns seven smooth stones. One is reserved for visitors.

> Has been consulted about moss. Was given time to finish.

> Owns a shelf of adequate depth. Has been reassured about its width.

The existing `preference` and `want` field names are implementation details.
Neither line needs to be a wish or an instruction to fulfil one. Both may report
a fact. Keep the two-line budget and the same stable character across retries.

Each implemented English assessment is a complete ten-word story across those
two fields. Use a wide authored range of small happiness, sadness and absurdity.
Keep the deadpan assessment voice, including reports about a domestic life
elsewhere. Vary the situation and emotional turn so the catalogue does not read
like a collection of interchangeable nouns. See the full
[catalogue and identity contract](LemmingAssessments.md).

## Timing and placement

Use existing authored spaces: optional inspection, chosen Trolley details,
award names and appropriate briefing or campaign text. Replace weak copy before
adding more. A proposed briefing line needs a suitable existing space and a
reason to be there. This direction does not require a new caption on each level.

Keep the playfield quiet. No live speech bubbles, floating biographies, death
notices, compulsory narrator, additional pause or delay before Continue or
Retry. A bridge, an empty exit or the final frame can carry the subtext alone.
Follow [UI principles](UIPrinciples.md) and the shared controls.

Do not repeat a visible count, star, progress bar or outcome in a joke below it.
Use no more than one comic beat in a short text block. Leave some individual
details and celebrations entirely sincere. Repetition should not turn a good
line into a rebuke after the fifth attempt.

No joke belongs in a Hot Seat handover at the expense of player identity or the
Ready action. The handover remains paused. Apply the same restraint to saved-run
recovery, hints and retries across all three games.

## Truth and affection

Keep authored personality separate from observed events. A preference is
fiction. An assignment, exit, loss or reserve count is an engine observation.
Personality must not imply different movement, courage, skill acceptance or
survival behaviour. It creates no needs to tend and no reward obligations.

Never infer a voluntary sacrifice, friendship, rescue causality, loneliness or
player intent from a result. A builder did not necessarily save twelve friends.
A blocker did not necessarily choose to die. Rewind does not accumulate personal
tragedies. Unreleased lemmings and L3 reserves are not deaths.

Keep best known, best possible and unknown distinct. A formal clear can involve
losses. Matching a verified maximum need not mean everyone survived. Comedy may
question the institution's language, but the factual interface must stay honest.

Keep names and personalities stable through retry, rewind and recovery. Changes
to the character catalogue need a version and compatibility policy. Do not
silently give a remembered lemming a different personality after an update.

## Across the three games

| Game | Emphasis for new edition writing | Facts and original material to preserve |
| --- | --- | --- |
| Classic | Cheerful confidence in precarious infrastructure; small lives within a large flow of people. | Original level names, briefing requirements, skill rules, artwork and voices. |
| Lemmings 2 | The gap between a grand collective evacuation and what each tribe actually carries forward. Official congratulations can be awkward without scolding the player. | Original prophecy, Talisman and Ark material; distinct medal and survivor rules; original captions and credits in their archival assets. |
| Lemmings 3 | Practical problems after the grand story: tools, direction, reserves and the business of getting through the next place. | Original movies and voices; tool behaviour; the distinction between saved actors and reserves; tribe completion requirements. |

These are emphases, not three incompatible narrators. Shared awards, inspection
and Trolley text use one authored catalogue. Do not force a game-specific joke
into a shared field or promise an event that only one engine can observe.

Original material remains original. New edition wording can replace a modern
presentation's taunt without altering source assets or passing new prose off as
the original script. Do not add a new presentation mode just to carry a joke.

## Voice examples

These are examples of craft, not automatic additions to the interface.

> The safety committee has approved a smaller committee.

Use institutional absurdity in an authored setting. Do not attach this to a
loss counter as if casualties were an amusing efficiency improvement.

> He had no five-year plan. He did have plans for Thursday.

Ordinary life supplies the stakes. Never select this as a death notification.

> The bridge is temporary. This was also true of the previous bridge.

A possible authored scene line. It must not masquerade as a terrain prediction
or claim an observed earlier bridge without evidence.

> Please direct all existential concerns to the exit.

An occasional piece of world writing. The actual control remains **Exit**,
**Continue** or whatever action it performs.

> You went back for him.

An example of leaving sincerity alone. Current retry records do not prove this
individual act or its intention. Do not ship it as an automatic result message.

## Editorial acceptance

Before changing game copy, identify its speaker, placement and factual trigger.
Check that the line works without knowledge of the references, that its joke has
a target, and that the player can still understand the next action immediately.
Remove filler, repeated information and any moral judgement of the player.

Review shared text in Classic, L2 and L3. Preserve source assets, stable IDs,
stored history, localisation placeholders and clear accessibility names. Translate
the comic mechanism rather than requiring a literal English pun.

For implementation, inspect actual bitmap renders at supported sizes and check
input targets. Use muted, background checks under the repository's test rules.
A source review is not rendered acceptance. Record media, translation and
engine-specific gaps instead of calling an unreviewed surface complete.
