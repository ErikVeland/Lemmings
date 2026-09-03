# DOS Lemmings audio data

This records what `ADLIB.DAT` and `TANDYSND.DAT` contain. It exists so the
audio work starts from measured facts, not from guesses.

Run the probe to reproduce every number here:

```sh
zsh Scripts/probe-audio.sh
```

## The files are programs, not data

Both files use the standard Lemmings DAT container. `ADLIB.DAT` decompresses to
22,125 bytes. `TANDYSND.DAT` decompresses to 21,702 bytes.

The decompressed content starts with x86 machine code:

```
22 e4   and ah, ah
75 03   jnz +3
e9 0e 01  jmp
fe cc   dec ah
```

The game loads the file and calls into it. The audio is therefore not a plain
asset that a loader can read. It is a driver with the music built in.

## What the driver holds

`ADLIB.DAT` is a standalone Ad-Lib driver with a test menu:

```
Ad-Lib Music/FX Driver - (c) 1991 Sound Images   Tel. 061 773 4541
```

| Offset | Contents |
| --- | --- |
| `0x0000` | x86 driver code |
| `0x0600` | OPL2 channel register table. The `b4`-`b8` values are OPL registers |
| `0x0660` | Banner and the test menu |
| `0x0828` | Scancode to ASCII table for the test menu |
| `0x08a3` | Logarithmic volume table, descending from `0x3f` |
| `0x0927` | Ascending 16-bit table, 110 entries from `0x02b2`. Probably pitch |
| `0x0e1a`-`0x55e3` | FM instrument patches and tune data |

## The tunes

The menu names 21 tunes and states that shifted A to Q play 17 sound effects.

| Key | Tune | Key | Tune |
| --- | --- | --- | --- |
| A | Awesome | L | Tim1 |
| B | BeastI | M | Tim2 |
| C | BeastII | N | Tim3 |
| D | CanCan | O | Tim4 |
| E | Doggie | P | Tim5 |
| F | Lemming1 | Q | Tim6 |
| G | Lemming2 | R | Tim7 |
| H | Lemming3 | S | Tim8 |
| I | Menace | T | Tim9 |
| J | Mountain | U | Tim10 |
| K | Ten Lemmings | | |

## Instrument patches

Patches are 16 bytes. The first 10 bytes are the FM voice. The remaining 6
bytes are a level followed by `00` padding, which makes `7f 00 00 00 00 00` a
reliable marker to find them.

```
b9 c9 05 06 01 00 00 02 0c 01 | 7f 00 00 00 00 00
99 59 09 02 01 01 01 03 00 0a | 7f 00 00 00 00 00
```

The 10 voice bytes follow the Ad-Lib layout. Bytes 0 and 1 hold the tremolo,
vibrato, sustain, envelope-scaling and multiplier bits for the modulator and
the carrier. Bytes 2 and 3 hold key-scale level and output level. Bytes 4 and 5
hold attack and decay. Bytes 6 and 7 hold sustain and release. Bytes 8 and 9
hold the waveform select.

`ADLIB.DAT` holds 74 patches. `TANDYSND.DAT` holds 15.

## What is still unknown

The tune pointer table has not been found. Without it, no tune has a known
start address. The sequencer byte format is also undecoded. Note streams are
visible from about `0x0a00`, where note values fall between `0x18` and `0x33`
and control bytes use the high bit, but the meaning of each control byte is not
established.

## What playback needs

Two separate pieces of work remain.

1. Decode the Sound Images sequencer format into note events.
2. Produce sound from those events.

Step 2 needs FM synthesis. The music is written for the Yamaha YM3812, so
faithful playback means implementing that chip's operators, envelopes and
waveforms. A general-purpose synthesizer does not sound the same. This is worth
stating plainly, because it is chip-level work even though the rest of the port
uses no emulation.
