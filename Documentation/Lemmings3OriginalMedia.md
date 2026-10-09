# Lemmings 3 original media

The native player connects six named voice samples from `AUDIO/GRAVIS`, alongside the
existing tribe module music. Names in the supplied assets identify the voices;
the current event bindings are:

| Original patch | Native event |
| --- | --- |
| `I_DOOR.PAT` | First hatch release |
| `I_LETSGO.PAT` | First hatch release |
| `I_OK.PAT` | Accepted assignment |
| `I_YIPEE.PAT` | New rescue |
| `I_LEMDIE.PAT` | Loss without a separate causal death sound, including bottom falls |
| `I_OHNO.PAT` | Accepted bomb activation |

Every rescue keeps its own `I_YIPEE.PAT` voice, including simultaneous arrivals.
Overflow layers preserve the chorus at normal gain when the spatial pool is
full. Generic loss cues keep their individual positions, with a brief gate for
nearby repetitions. Accepted assignments retain `I_OK.PAT`; rejected actions
on a real target use a separate short refusal cue. The shared sound player
applies volume and mute, records accepted playback, and clears pending voices
when restarting or suspending the game for a movie.

The 8 October development source adds short presentation supplements at the
engine's causal events:

| Event | Supplement |
| --- | --- |
| Tool pickup accepted | Rising pickup chime |
| Clock consumed and time added | Distinct clock flourish |
| Hadouken or grenade launched | Short rising launch effect |
| Bomb or grenade detonates | Positioned explosion |
| Brick placed | Quiet placement tick |
| Last three remaining bricks | Builder warning |
| Brick or spade work meets steel | Steel contact |
| Swimmer enters water | Water-entry splash |
| Drowning starts, including after swim supplies expire | Drowning effect |
| Trap captures a lemming | Trap trigger |

Pickup cues follow an actual transfer, not proximity. Steel cues follow the
work obstruction, and explosion cues follow detonation. Trap, drowning and
explosion deaths acknowledge their causal sound so removal cannot also replay
the generic death voice. Timer warnings use a separate sound from builder
warnings. The supplements use the shared spatial, volume, mute and replay
capture paths. They add no continuous work loops.

The decoder accepts only complete, one-instrument, one-layer, one-sample Gravis
patches with unlooped 8-bit PCM. It supports signed and unsigned samples and
uses each patch's declared sample rate. Header offsets and mode flags follow
the [SDL_mixer TiMidity instrument reader](https://raw.githubusercontent.com/libsdl-org/SDL_mixer/SDL2/src/codecs/timidity/instrum.c).
This is a voice loader, not a general Gravis synthesizer. Exact DOS event
timing, MIDI transposition and envelope behaviour have not been established.
The anonymous `SFX001` raw bank still needs validated sample boundaries and
event mappings. The new supplements are explicitly generated presentation
effects. They do not establish original DOS sample identity, event timing or
mix parity for traps, explosions and other environmental effects.

The pause menu's **Original movies** gallery plays `INTRO.FLI`, `C-LEV15.FLI`,
`SHA-WALK.FLI`, `E-LEV10.FLI` and `THE-END.FLI`. Streaming playback retains one
decoded frame, uses the original dimensions and timing, and stops before the
extra loop frame. Space or a click pauses; Escape or Return goes back. Gameplay
and its audio stop advancing during playback. Closing the game also closes
the movie without restarting its audio.

`INTRO.FLI` also starts when a player opens a fresh L3 title session. It uses
the packaged DOS OPL2 Intro recording, which matches the original opening cue
over the tested interval. The movie hands over to gameplay at its final frame.
Escape or **Skip** hands over early. Saved runs, direct level selection,
playlists and Hot Seat open without this movie. If the optional opening movie
is missing or unreadable, gameplay opens without an error page. The manual
gallery reports an error for the same file problem.

The original DOS executable requires a final result count of at least 50 for
each tribe. It starts `THE-END.FLI` when the third tribe meets that target.
The native campaign checks 50 saved plus reserve lemmings and opens the
ending after the last qualifying result. Finishing or skipping it returns to
the library or game menu; missing or unreadable automatic media follows the
same handover. Exact DOS carry arithmetic still needs a complete campaign
comparison. The manual gallery still reports a movie error.

`C-LEV15.FLI`, `SHA-WALK.FLI` and `E-LEV10.FLI` have no verified native story
trigger. The original Shadow entry shows a brief story screen, but the
available capture does not identify a `.FLI` movie. Original environmental
sample mappings, these story transitions and complete movie soundtrack timing
remain open.

`Lemmings3SoundTests` checks the real voice data, PCM conversion, invalid inputs
and runtime event selection. Muted regression checks also cover simultaneous
rescue voices, causal pickup, work, water, trap and explosive events, and
suppression of duplicate death cues. The sequel app tests check recording callbacks,
accepted and rejected actions, mute, movie pause, the final frame, return to the
gallery and closing the game during playback. The focused `l3-story` test checks
the opening policy, Skip target, automatic handover and missing or unreadable
movie behaviour. The focused story test also checks the three-tribe ending
threshold and ending handover. The existing FLIC suite decodes every frame
of all five originals.
