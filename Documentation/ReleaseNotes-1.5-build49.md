# 1.5 test build 49

Snapshot source: `90404b525306f13be6bc3ef6500521fe439868d6`.
Later RC3 commits also use build 49. These notes do not cover those commits and
are not a public release draft.

- Use Return or keypad Enter to activate the focused dialog button.
- Navigate dialog controls with Tab, Shift-Tab and arrow keys. Nested dialogs restore focus when closed.
- Move backward and forward through hints with Left and Right. Full solutions still require confirmation.
- Use the normal mouse cursor on dialogs and help screens in all three games.
- Navigate replay and original-movie controls by keyboard or their accessibility actions.
- Keep H for hints and the rewind and step buttons introduced in build 48.

Local Apple silicon Game Center snapshot, development signed for registered Macs. Not notarised.

Accessibility checks cover exposed roles, names, focus targets and actions. A complete VoiceOver walkthrough and full campaign playthroughs remain outside this test build's validation.

Passed: dialog and native-sheet activation, held-key suppression, focus restoration,
hint navigation and confirmed solution replay, Classic flat/CRT rendering, and
Lemmings 2/3 toolbar input with paused hints. Playfield drawing tests also passed.

The signed app passed its 15-second fresh-preferences launch check. Its first
frame appeared in 3.568 seconds, before music started.
