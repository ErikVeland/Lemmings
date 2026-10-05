# Lemmings 3 original media

Beta 12 connects six named voice samples from `AUDIO/GRAVIS`, alongside the
existing tribe module music. Names in the supplied assets identify the voices;
the current event bindings are:

| Original patch | Native event |
| --- | --- |
| `I_DOOR.PAT` | First hatch release |
| `I_LETSGO.PAT` | First hatch release |
| `I_OK.PAT` | Accepted assignment |
| `I_YIPEE.PAT` | New rescue |
| `I_LEMDIE.PAT` | New loss during simulation |
| `I_OHNO.PAT` | Accepted bomb activation |

Simultaneous rescues or losses produce one voice per event kind per tick.
Rejected assignments produce no voice. The shared sound player applies volume
and mute, records accepted voice playback, and clears pending voices when
restarting or suspending the game for a movie.

The decoder accepts only complete, one-instrument, one-layer, one-sample Gravis
patches with unlooped 8-bit PCM. It supports signed and unsigned samples and
uses each patch's declared sample rate. Header offsets and mode flags follow
the [SDL_mixer TiMidity instrument reader](https://raw.githubusercontent.com/libsdl-org/SDL_mixer/SDL2/src/codecs/timidity/instrum.c).
This is a voice loader, not a general Gravis synthesizer. Exact DOS event
timing, MIDI transposition and envelope behaviour have not been established.
The anonymous `SFX001` raw bank still needs validated sample boundaries and
event mappings. Traps, explosions and other environmental effects remain open.

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
available capture does not identify a `.FLI` movie. Environmental effects,
these story transitions and complete movie soundtrack timing remain open.

`Lemmings3SoundTests` checks the real voice data, PCM conversion, invalid inputs
and runtime event selection. The sequel app tests check recording callbacks,
accepted and rejected actions, mute, movie pause, the final frame, return to the
gallery and closing the game during playback. The focused `l3-story` test checks
the opening policy, Skip target, automatic handover and missing or unreadable
movie behaviour. The focused story test also checks the three-tribe ending
threshold and ending handover. The existing FLIC suite decodes every frame
of all five originals.
