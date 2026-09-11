# Replays and movies

At the end of a classic, Lemmings 2 or Lemmings 3 run, press **V** to watch it or
**S** to save a movie. The result page offers **Watch replay**; the replay
controls include **Save movie**. The app menu offers **Replay Last Game** and
**Open Replay Movie**.

The replay viewer stays inside the game. It supports 0.25×, 0.5×, 1×, 2×, 3×, 4× and
8× playback, pause, restart and seeking. Use **Space** to pause, **−/+** to change
speed, and **S** to save. The movie export uses the selected speed. Escape closes
the viewer or cancels an active export.

Each simulation tick becomes one video frame, even during fast-forward. Normal
replay speed follows the game's clock. Time spent paused is omitted. Rewinds and
nuke undo appear as jumps back to the restored state in the recorded run. These
are visual recordings. They do not apply inputs to a simulation or change saved
campaign progress. The DOS engine's separate deterministic replay format remains
available to its tools.

Movies use H.264 video and AAC audio in an MP4 file. The recorder mixes game
sound effects and the selected music against the replay clock. Music uses native
modules or installed recordings. L3 records its bundled tribe modules, six named
original voices and warning beeps. Environmental effects remain unconnected. Export preserves audio at
the selected playback speed. Movies use SDR colour and do not encode the Metal
HDR overlays or CRT post-processing.

Recording starts when a level loads and keeps the latest run until another level
starts or the title closes. Save a movie to keep it. Open saved MP4 or MOV files
with **Open Replay Movie** to watch them again. Playback suspends the source
soundtrack so it does not overlap the movie audio.

Frames are drawn at a fixed size, up to 1280 pixels wide, without resizing the
live playfield. L2 records at its doubled artwork scale, up to 480 pixels high,
to reduce the cost during fast-forward. A serial encoder queue holds at most twelve waiting images.
Audio and video are encoded separately, then combined without another video
encode. Exports use a temporary file beside the destination and replace the
chosen file only after export succeeds. Cancelling a save preserves the existing
file.

Run `Scripts/run-replay-movie-tests.sh` to check frame count, image orientation,
module and effect audio, export duration, playback controls and source-audio
callbacks. The test saves example movies and a control-bar image under
`.build/replay-movie-tests`.

Replay playback stays in the main game window. **Back** returns to the result
page. Opening and saving movie files uses a sheet attached to that window.

Lemmings 3 also has an **Original movies** gallery in its pause menu. It plays
the five bundled FLIC movies inside the same window, separately from run
recordings. Space pauses and Escape returns to the gallery. These original
movies currently have no soundtrack; gameplay and its audio remain suspended
until the movie closes. Story-driven automatic playback remains unconnected.
