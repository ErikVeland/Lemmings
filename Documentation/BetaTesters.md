# Beta tester devices

The Game Center build runs only on the Macs listed in the `Lemmings macOS
Development` provisioning profile. This file is the roster that profile must
match. The Developer ID build does not use this list.

Add a device here and in the Apple Developer portal at the same time. A profile
holds at most 100 Macs for each membership year, and a removed slot returns only
when the membership renews.

| Provisioning UDID | Mac | Purpose | Added |
| --- | --- | --- | --- |
| `00006040-001650D21A00801C` | Apple silicon, owner | Development and packaging | Before beta 13 |
| `00008103-000C65CE3C31001E` | Apple silicon, tester | Game Center | 11 September 2026 |

## Add a device

1. Ask the tester for the UDID. The tester opens **Apple menu > About This Mac >
   More Info > System Report > Hardware** and copies **Provisioning UDID**.
   That field is not **Hardware UUID**. The two look alike and sit next to each
   other. Apple rejects a Hardware UUID, and an Apple silicon Provisioning UDID
   always starts with `0000`.
2. Add the UDID to this table.
3. Register the UDID in the Apple Developer portal under **Devices**.
4. Edit the `Lemmings macOS Development` profile. Select the new device. Generate
   the profile again and download it.
5. Build the Game Center archive with `APPLE_PROVISIONING_PROFILE` set to the new
   file. See [beta testing](BetaTesting.md).

A tester whose Mac is not in the downloaded profile cannot open the Game Center
build. The Developer ID build still works for that tester, with local records only.

## Privacy

A provisioning UDID identifies one person's computer. Keep this file inside the
private repository. Do not publish it with the release notes or the archive.
