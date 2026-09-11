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

Movies currently have no soundtrack and do not trigger automatically during
campaign progression. The gallery provides access to the original artwork;
it does not claim to recreate the original front end or story sequence.

`Lemmings3SoundTests` checks the real voice data, PCM conversion, invalid inputs
and runtime event selection. The sequel app tests check recording callbacks,
accepted and rejected actions, mute, movie pause, the final frame, return to the
gallery and closing the game during playback. The existing FLIC suite decodes
every frame of all five originals.
