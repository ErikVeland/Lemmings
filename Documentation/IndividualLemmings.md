# Individual lemming inspection

The 2.1 inspection feature gives released lemmings names, small fictional
preferences and wants, and a record of their accepted actions in the current
level. It is available in Classic, Lemmings 2 and Lemmings 3 while paused.

On Mac, pause and hover over a lemming. Its name, preference, want, current
activity and up to three recent recorded actions appear automatically. The
bitmap panel stays away from the pointer and passes all input through to the
playfield. Moving off the lemming or resuming play hides it. Skill eligibility
does not affect which lemmings can be inspected. Obvious and Modern selection
show a green pixel diamond above that same actor. Modern also retains its white
outline and green glow. Choose **None** under **Selection effect** to hide these
markers. The diamond is a presentation aid and has no effect on the game simulation.

For longer histories or keyboard/controller browsing, choose **Inspect** or
press **⌘I**, then use **Previous** and **Next**. L2 and L3 can also start with
the last assigned actor.
On iPhone, iPad and TV, open the pause menu and choose **Inspect lemmings**.
Use **Earlier actions** and **Later actions** for a longer recorded history.
**Back** closes inspection and leaves the game paused.

Inspection adds no live labels, automatic interruptions, sounds, skill modifiers,
needs meters or objectives. Preferences and wants are authored character details.
They do not describe a measured emotional state or change walking, targeting,
skill acceptance or survival. The action history comes from accepted inputs.

## Identity and history

Catalogue version 1 contains 96 names and twelve pairs of preferences and wants.
The same exact starting engine state and actor ID produce the same character.
Retries, rewind, checkpoint restoration and matching Hot Seat starting states
therefore retain the mapping. A number beside the name identifies the actor and
distinguishes repeated names in larger populations. A new level has its own
identity scope; a matching name does not establish cross-level continuity.

The inspector reads a frozen copy only when opened. It shows released actors,
including saved and lost individuals retained by the engine. Unreleased actors
and L3 reserves do not gain invented personal histories. Hot Seat ghosts are
outside this first inspection implementation; the inspector reads the current
attempt's actors and inputs only. Opening it cannot pass a turn or dismiss Ready.

Recorded actions include skill assignments and, in L3, walker, blocker, jumper,
tool-use and tool-drop inputs. Each history row names the skill or action and
its age in simulation ticks, such as **Builder: 42 ticks ago**.
Climber, Rock Climber, Floater and Parachuter assignments are small milestones:
**Became a Climber: 42 ticks ago**. They stay in the individual's history after
the actor returns to walking. These labels recognise an acquired ability without
inventing a successful ascent, landing or rescue. L3 retains its actual tool
names rather than treating its equipment as permanent Classic or L2 skills.
The most recent entry shows the last recorded use. Ages are zero on the assignment tick, stay
fixed while paused and follow the current timeline through rewind. For ongoing
work and permanent skills, the age starts at the accepted assignment; it does
not infer a task's completion time or the last animation frame of work. Current
activity and saved/lost status come from the actor state. An assignment does not
prove that a task finished or that an individual saved others. New L3 tool uses
record the tool before it is used, and retain that identity in checkpoints.
Older inputs without tool metadata keep a generic label; current equipment
cannot prove which tool was used earlier. Release-rate, fan, aiming and nuke inputs are not attributed
to individuals.

History follows the applied timeline. Rewind removes later actions from the
view; an abandoned branch does not become remembered deaths or extra rescues.
Legacy checkpoints can lack earlier inputs. **No recorded assignments** states
what is available and does not assert that no assignment ever happened.

## Implementation and limits

`LemmingInspection` in LemmingsAppCore adapts the existing engine states and
accepted command logs. It does not step an engine, change physics or write new
attempt records. Mac uses `LemmingInspectionHover` for paused hover, with a
cached snapshot that refreshes when the attempt changes. `LemmingInspectionPage`
retains full history browsing with the existing bitmap labels and stone buttons.
The mobile and TV frontend uses `LemmingInspectionArt` with
the existing shared menu, focus and accessibility machinery.

This first implementation supports paused browsing of the current level. It does
not add persistent individual biographies, actor selection inside old movies,
cross-level survivor tracking or NeoLemmix clone/preplaced identity support.
Characters are derived with catalogue version 1; retaining inspected histories
beyond the attempt will require storing that version and the identity mapping.
New copy uses the localisation layer, with English fallback where translations
are absent.

## Validation

Focused checks cover deterministic identities and unchanged state hashes in all
three engines, exclusion of future and unattributed inputs, empty hatches and
history pagination. Live mobile session checks cover rejected assignments,
checkpoint restoration and rewind across accepted actions for all three games.

Muted offscreen Mac checks exercise inspection navigation, Back, input targets
and state preservation. Hover checks cover immediate display, cache refresh,
pointer exit, running-state suppression, positioning and input pass-through.
Render fixtures cover empty, active, saved and lost
individuals at three Mac sizes, plus five shared phone, tablet and TV sizes.
iOS and tvOS simulator SDK source compilation checks the connected frontend.
Physical touch, remote/gamepad use, VoiceOver and character-writing tone still
need human acceptance. These checks do not close existing engine-fidelity or
device release gates.

The selection diamond uses the shared bitmap and Metal renderer across Classic,
L2 and L3. `Scripts/run-lemming-selection-tests.sh` passes muted offscreen checks
for normal, doubled and fractional zoom, full/half/zero opacity, playfield clipping
and exclusion from rescue illumination. Its synthetic bitmap preview was inspected.
Full native selection checks are currently blocked by the L3 replay initializer's
unsupported `tool:` argument. Metal is unavailable in the headless session, so
composited CRT and physical mobile/TV output remain unverified.
