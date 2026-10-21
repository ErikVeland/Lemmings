# Lemming assessments

Implemented 21 October 2026. Classic, Lemmings 2 and Lemmings 3 share 128
complete authored stories in [LemmingAssessmentCatalogue.swift](../Sources/LemmingsAppCore/Records/LemmingAssessmentCatalogue.swift).
Each English story has exactly ten whitespace-separated words across the two
existing inspection fields. Names, statuses and action history are separate.

The voice follows the [narrative direction](NarrativeDirection.md): calm reports
of ordinary lives elsewhere, with small happiness, sadness and absurdity. Every
pair is written together. No fragments, emotional states or punchlines are mixed
at runtime. Some reports are reassuringly precise; others simply let affection
or disappointment remain. Nothing selects a sad story because an actor died.

## Stable assignment

The existing engine, initial-state hash and actor ID determine the personality.
The identity seed keeps its original `:1` namespace, preserving names. The
assessment catalogue is version 2. Its 128 entries, their order and their wording
are frozen and protected by a checksum regression. An odd-stride permutation
assigns every story once across actor IDs 0–127. Larger cohorts repeat after
128 IDs; there is no runtime random draw or dependence on current actor order.

Retrying the same starting state, rewinding, changing Hot Seat ownership and
restoring a checkpoint reproduce the same name and story. Starting-state
changes can identify a different cohort. There is no cross-level personal
continuity. Inspection never changes physics, save formats or turn ownership.

This implementation deliberately replaces the old twelve preference/want pairs
with the requested stories, including when an older saved run is inspected.
Those saves did not store personality text or a catalogue selector. Existing
names remain, and subsequent retries and restores use the same frozen version-2
story. This supersedes the audit's earlier suggestion to keep the old prose.
Do not silently revise or expand version 2 later. A future catalogue needs a
persisted version selector and a migration that retains this mapping.

The English ten-word limit counts contractions and possessives as one word.
Translations should preserve the meaning, restraint and layout, rather than
forcing unnatural phrasing to reach an English word count. All 256 lines are
extracted through `L10n.text`. Translations in the other eight bundled languages
are pending; those lines currently use the normal English fallback.

## Validation

Fourteen focused tests pass with muted audio and offscreen windows through
`Tools/UITestRunner/run.py`. They cover all 128 unique ten-word stories, the
frozen wording and assignment, read-only inspection, action history and rewind.
Fresh sessions for Classic, L2 and L3 retain complete individual records after
checkpoint restore and after retrying the same initial state.

All 128 stories render in the shared 320-point phone layout, the 640-point Mac
inspection page and the narrow paused hover panel. Bounds and input targets
pass. Sample captures were visually inspected. Separate fixtures cover all
three engines, empty hatches, active, saved and lost actors, history navigation,
Back and the inspection setting at multiple phone, tablet, TV and Mac sizes.
These are offscreen shared-renderer checks, not physical iOS or tvOS device runs.
Native host restore paths use the shared model; cross-build engine migrations
and changing the canonical starting state are outside this validation.

The English catalogue contains all 256 source lines, and this document matches
all 128 source pairs. The full localisation check remains incomplete because
the other eight languages lack these translations. The extractor reports the
first failure as `de.lproj: 256 missing texts`. Their English fallback remains
available. No public release build or translation-fit verification is claimed.

## Catalogue

The IDs below are frozen source indices, not visible labels or score values.

| ID | First line | Second line |
| --- | --- | --- |
| 000 | Owns seven smooth stones. | One is reserved for overnight visitors. |
| 001 | Enjoys the rain. | Has described indoor rain as largely unnecessary. |
| 002 | Has seen the sea twice. | Recognised it the second time. |
| 003 | Is welcome in three kitchens. | May sit down in two. |
| 004 | Keeps string in a designated drawer. | No complaints were received. |
| 005 | Owns an inland shell. | Accepts the shopkeeper's account without reservation. |
| 006 | Is known to hum at home. | The tune remains unidentified. |
| 007 | Has been consulted about moss. | Was given time to finish. |
| 008 | Recognises four kinds of cloud. | Prefers the one from Tuesday. |
| 009 | Uses a different spoon on Sundays. | The food remains unchanged. |
| 010 | Received a leaf by post. | Still thinks about the gesture. |
| 011 | Owns a shelf of adequate depth. | Its width was approved. |
| 012 | Bought two cups after meeting someone. | Still uses them alternately. |
| 013 | Keeps a birthday candle ready. | Nobody needs to know why. |
| 014 | A neighbour remembers their favourite biscuit. | This has helped considerably. |
| 015 | Has a photograph of an empty chair. | Remembers the afternoon. |
| 016 | Learned to cook for someone. | Continues making the smaller portion. |
| 017 | Has finally received an invitation. | Keeps checking the correct year. |
| 018 | Once won a small raffle. | Still visits the winning towel. |
| 019 | Their apology arrived before the argument. | Both parties felt prepared. |
| 020 | Keeps the ugly vase. | Someone chose it with great care. |
| 021 | Their window faces another window. | Occasionally both lamps stay on. |
| 022 | Grew a tomato successfully. | Invited three people to witness lunch. |
| 023 | Their last letter contains no news. | It was welcome anyway. |
| 024 | Makes excellent soup for one. | Owns a reassuringly large ladle. |
| 025 | Someone remembered their name today. | They had brought identification anyway. |
| 026 | Has a coat for special occasions. | Wore it buying bread. |
| 027 | Their garden contains one flower. | Visitors are shown it individually. |
| 028 | Once received unexpected praise. | Can still recall the exact wording. |
| 029 | Keeps a spare chair ready. | The cat understands the arrangement. |
| 030 | Took the scenic route home. | Nothing especially scenic was required. |
| 031 | Has stopped expecting a reply. | Still recognises the postman's footsteps. |
| 032 | Their friend moved somewhere warmer. | The spare blanket remains folded. |
| 033 | Enjoys being asked about the weather. | Prepares several possible answers. |
| 034 | Knitted a scarf for someone taller. | It reached them eventually. |
| 035 | Made a friend during a queue. | Sometimes misses the queue. |
| 036 | Their houseplant has grown another leaf. | No announcement was necessary. |
| 037 | Saved the last biscuit for later. | Later was unexpectedly pleasant. |
| 038 | Has forgiven the broken teapot. | Keeps the handle somewhere safe. |
| 039 | Their neighbour plays the same song. | It has become company. |
| 040 | Has been described as dependable. | The reference concerned a kettle. |
| 041 | Can distinguish three kinds of silence. | Recommends the one upstairs. |
| 042 | Was authorised to choose a cushion. | The decision remains respected. |
| 043 | Their handwriting improves on envelopes. | Nobody has formally requested this. |
| 044 | Owns a remarkably ordinary hat. | Its absence has been noticed. |
| 045 | Has permission to rearrange the biscuits. | Exercises this power sparingly. |
| 046 | Their umbrella was returned by someone. | Rain now seems friendlier. |
| 047 | Is considered good company during peeling. | The vegetable was unspecified. |
| 048 | Has never disappointed a borrowed ladder. | Its owner agrees broadly. |
| 049 | Their attendance at breakfast is consistent. | This reflects favourably overall. |
| 050 | Owns six identical buttons. | Can explain the difference if asked. |
| 051 | Has received favourable comments about sitting. | Standing remains under consideration. |
| 052 | Their curtains are regarded as adequate. | They found this comforting. |
| 053 | Is trusted with the larger scissors. | The responsibility feels manageable. |
| 054 | Was thanked for noticing a draught. | Keeps the written confirmation. |
| 055 | Their preferred bench faces a wall. | Finds the view reliable. |
| 056 | Has an excellent memory for porridge. | Several breakfasts remain vivid. |
| 057 | Is known to return borrowed containers. | Sometimes containing different things. |
| 058 | Their opinion of pears is available. | No appointment is required. |
| 059 | Owns a small decorative bell. | Its silence has been satisfactory. |
| 060 | A stranger once waved at them. | They waved back correctly. |
| 061 | Has been selected to hold something. | Still awaits further particulars. |
| 062 | Their toast preference is well documented. | The toast seems unconcerned. |
| 063 | Can identify their own slippers reliably. | Even when positions change. |
| 064 | Has a favourite corner of Tuesday. | Keeps it mostly free. |
| 065 | Their clock runs slightly ahead. | They appreciate the extra warning. |
| 066 | Bought a notebook for important thoughts. | Enjoys its present condition. |
| 067 | Their neighbours disagree about the fence. | Both appreciate the beans. |
| 068 | Has successfully declined a second pudding. | Retains no supporting evidence. |
| 069 | Their collection contains one missing item. | Talks about it fondly. |
| 070 | Enjoys waiting for bread to rise. | Calls this shared ambition. |
| 071 | Their favourite joke was told badly. | Remembers the laughter anyway. |
| 072 | Keeps tickets from an uneventful journey. | Would happily go again. |
| 073 | Their first cake leaned considerably. | Nobody asked it to stand. |
| 074 | Has a drawer for useful things. | Opens it for reassurance. |
| 075 | Their painting resembles somewhere they miss. | The actual place disagrees. |
| 076 | Has named the draught under the door. | Welcomes it politely. |
| 077 | Their guest towel has hosted nobody. | Remains prepared without complaint. |
| 078 | Made enough jam for the winter. | Summer visitors proved enthusiastic. |
| 079 | Their shoes squeak in different keys. | Walks home with accompaniment. |
| 080 | Has a tiny balcony. | The outside world makes regular appearances. |
| 081 | Their favourite shop closed last spring. | Remembers where everything was. |
| 082 | Keeps a shopping list from happier times. | Mostly ordinary groceries. |
| 083 | Their old address appears on something. | Paused before correcting it. |
| 084 | Has found a reason to celebrate. | Uses the everyday plates. |
| 085 | Their new friend dislikes the same chair. | A promising beginning. |
| 086 | Was invited back without asking. | The walk home felt shorter. |
| 087 | Their neighbour left a light on. | It helped with something. |
| 088 | Has learned the name of a bird. | Uses it privately. |
| 089 | Their family recipe includes an unexplained pause. | Observes it faithfully. |
| 090 | Owns a modest collection of keys. | Several doors remain hypothetical. |
| 091 | Their surname was misspelled on an award. | Displays it anyway. |
| 092 | Has kept one promise to themselves. | It concerned fresh sheets. |
| 093 | Their favourite jumper has become a cushion. | Affection remains unchanged. |
| 094 | Knows when the bakery opens. | Finds this knowledge quietly sustaining. |
| 095 | Their map shows a vanished pond. | Still takes visitors there. |
| 096 | Has two favourite mugs. | One enjoys a slightly greater confidence. |
| 097 | Their annual holiday includes a familiar bench. | Usually sits down. |
| 098 | Was asked to judge a cucumber. | Found in its favour. |
| 099 | Their letter of complaint received sympathy. | Kept the sympathetic envelope. |
| 100 | Has strong views about napkin storage. | Friends remain broadly supportive. |
| 101 | Their contribution to the picnic was shade. | Everyone fitted underneath. |
| 102 | Once mistook a meeting for lunch. | Remembers it as lunch. |
| 103 | Their coat pocket contains a shopping token. | Feels suitably equipped. |
| 104 | Has acquired a second opinion about turnips. | Prefers the first. |
| 105 | Their neighbour borrowed a little sugar. | Returned with a cake. |
| 106 | Has a place in somebody's address book. | Under their name. |
| 107 | Their favourite bowl survived the move. | Breakfast resumed almost normally. |
| 108 | Has become accustomed to a distant train. | Notices its absence. |
| 109 | Their handkerchief bears unfamiliar initials. | Wishes those people reasonably well. |
| 110 | Was complimented on an ordinary sandwich. | Has cautiously repeated it. |
| 111 | Their house smells pleasantly of oranges. | There is an explanation. |
| 112 | Owns a book nobody has borrowed. | Has prepared a recommendation. |
| 113 | Their scarf was recognised from a distance. | Felt briefly famous. |
| 114 | Has remembered where the spare key is. | Feels less temporary. |
| 115 | Their spare room is no longer spare. | The company suits. |
| 116 | Received a postcard from quite nearby. | Displayed it facing outward. |
| 117 | Their favourite photograph includes a thumb. | Knows whose it was. |
| 118 | Has made peace with the uneven table. | Keeps the coaster. |
| 119 | Their name was included in the thanks. | Read it twice. |
| 120 | Has been invited to inspect some beans. | Takes this seriously. |
| 121 | Their nicest plate is chipped. | Still brings it out first. |
| 122 | Bought flowers without an occasion. | The room accepted them readily. |
| 123 | Their friend kept the dreadful drawing. | Has drawn another one. |
| 124 | Has nothing planned for tomorrow. | Someone has offered to visit. |
| 125 | Their lost glove returned after winter. | They welcomed it nonetheless. |
| 126 | Has a favourite sound at home. | Someone putting water on. |
| 127 | Their ordinary day went mostly as expected. | Would recommend another. |
