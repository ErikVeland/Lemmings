# Familiar names

Optional device-local naming for Classic, Lemmings 2 and Lemmings 3.
Open **Settings → Privacy → Familiar names** from the library or Mac settings.
Fictional names remain the default. No contact permission prompt appears at launch.

## Choosing names

Players can type given names separated by commas, semicolons or newlines.
Compound given names remain intact. The shared store trims whitespace, normalises
Unicode and removes blank and case-insensitive duplicate entries while retaining
the first spelling. It does not guess surnames from a typed name.

Mac and iOS offer the system contact picker. Mac selects one contact per visit;
iOS supports multiple selections. Only `givenName` is copied into the draft.
No contact identifier, surname, phone number, email, photograph or relationship
is retained. Contacts with no given name contribute nothing. Cancelling the
picker leaves the draft unchanged. Apply saves the previewed list. Back discards
unapplied changes. The six-name preview has Previous and Next controls.

Apple's limited permission selects *contacts*, not individual fields. There is
no first-name-only authorization scope. `keysToFetch` controls a store fetch,
not the permission grant. This feature uses `CNContactPicker` on macOS and
`CNContactPickerViewController` on iOS, without `CNContactStore`, an authorization
request or a Contacts entitlement. Picker display keys are presentation options,
not a claim of field-level permission. See [Apple Contacts](https://developer.apple.com/documentation/contacts)
and [contact pickers](https://developer.apple.com/documentation/contactsui/cncontactpicker).

tvOS offers manual entry through the system text-input flow. It has no ContactsUI
picker. It uses its own local names; another device's list is never imported by
sync. The mobile in-game settings omit this library-only editor. Hot Seat
ownership, Ready and pause behaviour are unchanged.

## Stable identity and deletion

The list is device-wide, including local Hot Seat players. On the first
inspection using familiar names, the ordered list is frozen for that engine and
canonical starting-state hash. Actor ID determines the stable choice within it.
Retries, rewind, session recreation and checkpoint restores on this device use
the same list. Smaller lists cycle across larger cohorts. Ten-word assessments
and gameplay remain unchanged.

Editing the active list affects cohorts without a retained familiar-name list.
Removing a name from the draft does not rewrite existing assignments. Applying
an empty list stops assigning familiar names to new cohorts. **Forget names**
removes the active list and all frozen lists, including saved-run assignments,
and returns those lemmings to fictional names. There is no undo backup.

The store is `Private Familiar Names/names-v1.json` under the app's support
folder. The directory is excluded from system backups and is separate from
records, checkpoints, profile preferences, Tester Sync and TV backup namespaces.
Directory and file permissions are owner-only. Only first-name strings and
level-scope keys are stored. A read or write error does not silently overwrite
retained data. Forget can remove a damaged store so the player can start again.

Local persistence means restoring a run on another device uses that device's
names. Uninstalling, deleting local app data, or tvOS cache eviction can remove
the name store. A changed canonical initial state can identify a different
cohort, as with the existing fictional identity contract. Exported gameplay data
contains no familiar-name list or assignments. Player-created screenshots may
still show visible names.

## Validation

Nine focused tests pass, using `Tools/UITestRunner/run.py` with muted audio and
offscreen windows. Coverage includes Unicode and case deduplication, unchanged
assessment text, retained lists after editing and relaunch, corrupt-file handling,
Forget, and retry/checkpoint restoration in all three real mobile engine sessions.
Checkpoint payloads and portable TV backups exclude names and assignments.
The macOS backup exclusion attribute is verified; `tmutil isexcluded` also reports
Excluded. This SDK's Foundation property readback incorrectly reports false.

Native editor checks cover English and all eight translation drafts at 640×480
and 1120×720, including privacy-text fit, field and button targets, preview paging,
Apply and Forget. Shared bitmap checks cover empty, populated, typing, error and
confirmation states at phone, landscape and TV widths. Representative captures
were visually inspected. English and Tamil sample captures show the complete
editor. Some repeated translated native captures, including French, omit unchanged
field/name pixels despite valid content and input targets. Full visual acceptance
for those states remains open; no foreground fallback was used.
New labels have complete draft translation coverage;
human language review and complete translated mobile journeys remain open.

Updated AppCore, MobileCore, TVCore, GameArt and MobileUI modules compile against
both the iOS and tvOS simulator SDKs. Full Xcode app assembly was blocked by
sandbox access to the SwiftPM manifest cache; SDK compilation does not claim an
installed app or physical-device test. Actual system contact pickers, cancellation
and TV keyboard presentation still require manual device verification. Automated
tests use synthetic contacts and never open or read a real contact library.

Names retain Unicode in storage and accessibility text. Visible names use the
existing Latin and Tamil bitmap alphabets; other scripts retain the renderer's
question-mark fallback. Extending font coverage is separate work.
