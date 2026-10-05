#!/usr/bin/env python3
"""Run one native UI test app at a time, with silent audio and offscreen windows by default."""
import fcntl
import os
from pathlib import Path
import subprocess
import sys
import tempfile

def test_environment():
    environment = os.environ.copy()
    environment.setdefault("NSUnbufferedIO", "YES")
    mode = environment.setdefault("LEMMINGS_TEST_WINDOWS", "offscreen")
    if mode not in {"offscreen", "secondary", "foreground"}:
        raise SystemExit("LEMMINGS_TEST_WINDOWS must be offscreen, secondary or foreground")
    audio = environment.setdefault("LEMMINGS_TEST_AUDIO", "muted")
    if audio not in {"muted", "audible"}:
        raise SystemExit("LEMMINGS_TEST_AUDIO must be muted or audible")
    if mode != "foreground" or audio == "muted":
        source = Path(__file__).with_name("WindowPlacement.m").resolve()
        audio_source = source.with_name("AudioSilence.m")
        build = source.parents[2] / ".build" / "ui-test-runner"
        build.mkdir(parents=True, exist_ok=True)
        library = build / "WindowPlacement.dylib"
        if not library.exists() or library.stat().st_mtime_ns < max(source.stat().st_mtime_ns, audio_source.stat().st_mtime_ns):
            subprocess.run([
                "xcrun", "clang", "-dynamiclib", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
                "-Wno-unused-parameter", "-arch", "arm64", "-arch", "x86_64",
                "-mmacosx-version-min=12.3", "-framework", "AppKit", "-framework", "AVFoundation",
                str(source), str(audio_source),
                "-o", str(library),
            ], check=True)
        libraries = environment.get("DYLD_INSERT_LIBRARIES")
        environment["DYLD_INSERT_LIBRARIES"] = str(library) + (":" + libraries if libraries else "")
    print(f"UI test windows: {mode}; audio: {audio}", flush=True)
    return environment


def main():
    if len(sys.argv) < 2:
        raise SystemExit("Usage: run.py command [arguments ...]")
    lock = Path(tempfile.gettempdir()) / f"lemmings-ui-tests-{os.getuid()}.lock"
    with lock.open("a") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        try:
            os.nice(10)
        except PermissionError:
            # A sandbox may deny priority changes while still allowing offscreen tests.
            pass
        environment = test_environment()
        command = sys.argv[1:]
        if Path(command[0]).name == "arch" and "DYLD_INSERT_LIBRARIES" in environment:
            # macOS strips DYLD variables when starting its protected arch tool.
            # Reapply the test library to the child with arch's own env option.
            library = environment.pop("DYLD_INSERT_LIBRARIES")
            command = [command[0], "-e", "DYLD_INSERT_LIBRARIES=" + library, *command[1:]]
        result = subprocess.run(command, check=False, env=environment)
        return result.returncode if result.returncode >= 0 else 128 - result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
