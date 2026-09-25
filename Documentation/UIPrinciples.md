# UI clarity

The user's requirement: icons and states must make sense without explanatory
sentences. Apply this to new UI and changes to existing UI.

- Use the game's bitmap artwork and pixel controls throughout game pages and HUDs.
  Menu lettering must not depend on the selected level graphics.
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
changes and concise skill names beneath HUD counts. This is not a claim that every
sequel screen or every novice-player journey has been validated.

Assignment feedback follows the engine's actual eligibility rules. Grey means no lemming is under the pointer; yellow means the lemming cannot
accept the selected skill; green means the nearest target can accept the selected skill.
Successful assignments get a 100 ms green pulse, with local HDR brightness when
available. An existing assignment gets an 80 ms orange cue. An eligible neighbour
always takes priority over orange. Honour the reduced-flash setting.

## Typography

Use the shipped green and blue bitmap fonts for all interface text, including
in-game notices. Classic lemming explosion countdowns use white, bold system
digits for crisp, readable numbers above each lemming. Use large green lettering for page titles,
small green lettering for section headings and selected or primary actions,
and small blue lettering for body text, quantities and secondary actions.
Keep each row of peer controls at the same face and scale. Do not size individual
labels to fill their boxes. Use spacing and grouping to separate supporting
text from headings. Preserve accessible names and input targets.

## Gameplay pointer

Use four corner brackets at the input position, with strokes one pixel
wide at every zoom and no central crosshair. Place the selected skill sprite diagonally below
and right of the bottom-right corner, outside the reticle. Offer None, 1× and 2×
skill icon sizes in Gameplay settings, defaulting to 2×.
Offer a separate default-off lemming count below-left, aligned with the skill icon.
Count live sprite centres inside the reticule, regardless of skill eligibility.
Keep the count available when the icon is hidden.
Clamp the sprite to the playfield edge. Directional skills must use directional
artwork rather than falling back to a plain dot.

A selected lemming has a faint, soft halo with a small brightness shimmer.
Do not draw an outlined ring or an orbiting arc. Reduced motion keeps the halo
static. Classic, Lemmings 2 and Lemmings 3 use the same cursor and halo renderers.
