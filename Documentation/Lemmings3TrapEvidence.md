# Native Lemmings 3 trap timing

The runtime reads trap timing from the original OBJ records. This replaces
the preview's fixed three-tick frame duration. It does not establish full
original-engine fidelity.

## Local reference

The inspected DOS executable is the user's local `L3CD.EXE`, SHA-256:

```text
5eef913b578fb642eef183d80404d91c4cbcb1f4c998e184962ce1f37f64f018
```

The resident EXEPACK image was unpacked with the development-only
[exepack tool](https://www.bamsoftware.com/software/exepack/), version 1.4.0,
revision `a42f2c8fb1018feeb2c32fc7f7b1f01240d824c4`. Capstone 5.0.9 decoded
16-bit x86 instructions. Neither the executable nor the unpacked image is
part of the application or repository.

The file contains a second overlay MZ header at file offset `0x3f000`.
Its header occupies `0xa00` bytes. Overlay offsets below are relative to the
body at file offset `0x3fa00`. Resident offsets are relative to the unpacked
MZ load image, after its header.

## Record fields and engine behavior

Overlay body `0x2c2b–0x2c73` copies OBJ fields into the live object:

| OBJ byte offset | Meaning | Live-object offset |
| --- | --- | --- |
| 10 | Frame count | `0x0c` |
| 11 | Initial frame | `0x11` |
| 12–13 | Animation control word | `0x14` |
| 2–3 | Object flags and trap subtype | `0x18` |

Overlay `0x2b5d–0x2bce` sets the initial frame and countdown. Control bits
0–6 give the frame delay. Bits 7–8 give the animation mode. Bits 9–15 give
the extra cycle pause. A trap starts inactive, with a one-cycle counter.

Resident `0x6280–0x630c` decrements the delay before advancing a frame. Each
frame therefore takes `delay + 1` updates. Frames wrap to 1, not 0. The extra
pause applies at the cycle boundary. All nine campaign trap definitions
start at frame 1 and use mode 1.

Overlay `0x3aa8–0x3b31` checks the trigger object's flags and active state.
An active mode-1 trap does not capture another lemming. A new trigger activates
the object and returns its subtype. Overlay `0x3b32–0x3b51` rearms mode 1
at the end of its animation. The native dispatcher at `0x4708–0x47a5`
handles subtypes 1–10, with 1 reserved for an exit.

## Native campaign values

| Style | Object | Subtype | Frames | Delay | Extra pause | Cycle updates |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Classic | 200 | 4 | 15 | 1 | 0 | 28 |
| Classic | 202 | 2 | 12 | 2 | 0 | 33 |
| Classic | 203 | 3 | 14 | 1 | 0 | 26 |
| Shadow | 994 | 5 | 15 | 1 | 0 | 28 |
| Shadow | 995 | 6 | 8 | 1 | 0 | 14 |
| Shadow | 996 | 7 | 3 | 0 | 24 | 26 |
| Egyptian | 102 | 8 | 14 | 0 | 0 | 13 |
| Egyptian | 103 | 9 | 29 | 0 | 0 | 28 |
| Egyptian | 104 | 10 | 25 | 0 | 0 | 24 |

For these records, a cycle takes `(frames - 1) * (delay + 1) + pause`
updates. The audit tool prints the raw values. Runtime tests use independent
expected cycle lengths, check every displayed frame, and test capture,
busy-state exclusion, and a later arrival after rearming.

## Remaining differences

The native trigger probe distinguishes object width and lemming states. The
preview still uses its earlier foot-cell probe. It also holds a victim until
the object cycle ends, rather than interpreting each subtype's lemming death
animation. These collision and death-timing details remain provisional.
The relative order of the native object and lemming updates still needs a
recorded frame comparison. Loading all 90 levels does not prove that all
90 can be completed.
