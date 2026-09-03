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
| `0x0040` | Chip initialization. Loads the table at `0x6d` and clears the voice array |
| `0x0045` | `mov dx, 0x388`, the Ad-Lib base port |
| `0x006d` | Initialization table. 27 words that silence every voice |
| `0x00a6` | Ad-Lib card detection |
| `0x0559` | Register write helper |
| `0x0600` | OPL2 channel register table. The `b4`-`b8` values are OPL registers |
| `0x0660` | Banner and the test menu |
| `0x0828` | Scancode to ASCII table for the test menu |
| `0x08a3` | Base I/O port, holding `0x0388` |
| `0x08a7` | Logarithmic volume table, descending from `0x3f` |
| `0x0927` | Ascending 16-bit table, 110 entries from `0x02b2`. Probably pitch |
| `0x05ac` | Voice state array. Nine entries of 20 bytes |
| `0x0e1a`-`0x55e3` | FM instrument patches and tune data |

## How the driver writes registers

The helper at `0x0559` takes the register in `AL` and the value in `AH`:

```
push dx
mov  dx, [0x08a3]   ; base port, 0x388
out  dx, al         ; select the register
in   al, dx  (x12)  ; the chip needs a delay here
mov  al, ah
inc  dx             ; the data port is base + 1
out  dx, al         ; write the value
```

Callers load both halves at once, so `mov ax, 0x6004` writes `0x60` to
register `0x04`.

The initialization table at `0x006d` confirms the register model. It sets every
sustain and release register from `0x80` to `0x95` to `0x0f`, then clears every
key-on register from `0xb0` to `0xb8`.

The detection routine at `0x00a6` is the standard Ad-Lib test. It resets the
timers, reads the status port, runs timer 1, and reads the status again.

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

## Instrument patch records

Records are 16 bytes. Ten bytes carry the voice. The remaining six are
`7f 00 00 00 00 00`, which makes the records easy to find.

```
b9 c9 05 06 01 00 00 02 0c 01 | 7f 00 00 00 00 00
99 59 09 02 01 01 01 03 00 0a | 7f 00 00 00 00 00
```

`ADLIB.DAT` holds 74 records. `TANDYSND.DAT` holds 15.

The byte order inside a record is **not** established. The obvious reading is
the Ad-Lib order, where bytes 4 and 5 hold attack and decay for the modulator
and the carrier. That reading fails. Under it, every record in the file gives
an attack rate of 0, and the hardware renders an attack rate of 0 as silence.
A file of 74 silent instruments is not credible, so the order must differ.

`Tests/OPL2Tests/main.swift` records this as a test. If the test starts to
fail, a patch has decoded to a nonzero attack rate and the layout is solved.

## What is still unknown

Three things block playback of the original tunes.

1. The tune pointer table has not been found, so no tune has a known start
   address.
2. The sequencer byte format is undecoded. Note streams are visible from about
   `0x0a00`, where note values fall between `0x18` and `0x33` and control bytes
   use the high bit, but the meaning of each control byte is not established.
3. The patch byte order is undecoded, as described above.

## What playback needs

Two pieces of work. One is done.

1. **Done.** Produce sound from FM voice and note data. `Sources/NxlvKit/OPL2.swift`
   implements the Yamaha YM3812. It reproduces the hardware frequency formula
   to better than 0.3 percent across the register range, runs the envelope
   through attack, decay, sustain and release, and mixes nine channels without
   clipping. Run `zsh Scripts/run-opl2-tests.sh` to check it.
2. **Open.** Decode the Sound Images format so the driver's own tunes can feed
   that synthesizer.

Until step 2 is finished, the synthesizer can play any FM voice the port
supplies, but not the original Lemmings tunes.
