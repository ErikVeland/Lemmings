# 1.5 test build 46

- Open the title screen without a pause at launch. The game no longer decodes every saved run to find the newest one.
- Move through the title menu without a stall on each key press.
- Keep the file format of saved runs. Runs from earlier builds resume as before.

Includes the loading and transition work from build 45.

Measured with a copy of the 516 saved runs on the development Mac. At launch, the time to find the newest run fell from 6.1 s to 0.26 s. Each later lookup takes about 12 ms. The new lookup chose the same run as the old lookup for all 11 player and Hot Seat pairs.

Local Apple silicon Game Center snapshot, development signed for registered Macs. Not notarised. No public release or appcast update.
