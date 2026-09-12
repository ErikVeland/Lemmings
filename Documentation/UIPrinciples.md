# UI clarity

The user's requirement: icons and states must make sense without explanatory
sentences. Apply this to new UI and changes to existing UI.

- Use the game's bitmap artwork and pixel controls throughout game pages and HUDs.
  Do not mix system fonts, SF Symbols, rounded Aqua controls or modern gradients
  into game artwork. AppKit can supply input and accessibility beneath game rendering.
- Show each outcome once. A filled star already communicates an earned goal.
- Use familiar action symbols. Pause changes to Play. A reversible action changes
  to Undo. Do not leave a destructive symbol on a button that now undoes it.
- Distinguish state through shape as well as colour. Earned stars are filled;
  unearned stars are outlined. An unknown target uses a question mark.
- Keep one primary action per screen. Give it a stronger outline and a directional
  marker. Selection has an underline; keyboard focus has its own outline.
- Keep quantities and player identity visible. They explain the current situation.
- Keep concise names for actions without a familiar symbol. Do not replace a clear
  action name with an invented icon or an initial.
- Put criteria, records, award descriptions and instructions on their relevant
  detail/help pages. Do not repeat them below the main outcome.
- Preserve accessible names and keyboard help. Visible captions should not be
  needed to explain a familiar icon, and images must not exclude screen-reader users.
- Inspect actual renders for success, partial success, failure, active, inactive,
  selected, focused and unavailable states. Check mouse and keyboard hit regions
  after changing layout. A successful compile does not establish usability.

The shared result panel and Classic HUD now apply these rules. The changes cover
star states, compact result layout, primary/selected actions, transport icon
changes and removal of permanent HUD captions. This is not a claim that every
sequel screen or every novice-player journey has been validated.
