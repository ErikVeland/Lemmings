#!/usr/bin/env python3
"""Require current candidate notes and a matching release-history entry."""

import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys


def fail(message):
    raise ValueError(message)


def validate_lemmix(root: Path):
    profile = json.loads((root / "Resources/Publishing/ultimate-lemmix.json").read_bytes())
    version, platforms = profile["version"], profile["platforms"]
    build = str(platforms["macos"]["build"])
    notes_name = f"ReleaseNotes-UltimateLemmix-{version}-build{build}.md"
    notes = (root / "Documentation" / notes_name).read_text()
    required = [f"# Ultimate Lemmix {version}", f"Build: {build}",
                f"Platform builds: Mac {build}, iPhone/iPad/Duo {platforms['ios']['build']}, Apple TV {platforms['tvos']['build']}"]
    if notes.splitlines()[0:1] != required[:1] or any(notes.splitlines().count(line) != 1 for line in required):
        fail("Ultimate Lemmix candidate notes must match its product version and platform builds.")
    bases = [line.removeprefix("Release base: ") for line in notes.splitlines() if line.startswith("Release base: ")]
    if len(bases) != 1 or any(line.startswith("Release commit:") for line in notes.splitlines()):
        fail("Ultimate Lemmix candidate notes must contain one release base and no frozen release commit.")
    subprocess.run(["git", "-C", str(root), "rev-parse", "--verify", bases[0] + "^{commit}"],
                   check=True, capture_output=True)
    index = "Documentation/UltimateLemmixReleaseNotes.md"
    subprocess.run(["git", "-C", str(root), "ls-files", "--error-unmatch", "--", index],
                   check=True, capture_output=True)
    history = (root / index).read_text()
    expected = (f"The current source version is **{version}** (Mac build {build}, "
                f"iOS build {platforms['ios']['build']}, tvOS build {platforms['tvos']['build']}).")
    if expected not in history or f"]({notes_name})" not in history:
        fail("Ultimate Lemmix history must link its current version and build notes.")
    info = plistlib.loads((root / platforms["macos"]["infoPlist"]).read_bytes())
    if info["CFBundleShortVersionString"] != version or info["CFBundleVersion"] != build:
        fail("Ultimate Lemmix Mac metadata differs from its publication profile.")
    for platform in ("ios", "tvos"):
        project = (root / platforms[platform]["project"] / "project.pbxproj").read_text()
        if (set(re.findall(r"MARKETING_VERSION\s*=\s*([^;]+);", project)) != {version}
                or set(re.findall(r"CURRENT_PROJECT_VERSION\s*=\s*([^;]+);", project)) != {str(platforms[platform]["build"])}):
            fail("Ultimate Lemmix mobile metadata differs from its publication profile.")
    welcome = (root / "Sources/LemmingsLocal/ReleaseWelcome.swift").read_text()
    if f'static let lemmixNotesVersion = "{version}"' not in welcome:
        fail("Ultimate Lemmix welcome notes must match its release version.")
    return version, build, notes_name


def validate(root: Path, edition="ultimate-lemmings"):
    if edition == "ultimate-lemmix":
        return validate_lemmix(root)
    with (root / "Resources/Info.plist").open("rb") as source:
        info = plistlib.load(source)
    version = info.get("CFBundleShortVersionString")
    build = info.get("CFBundleVersion")
    if not isinstance(version, str) or not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", version):
        fail("Resources/Info.plist must contain a stable numeric marketing version.")
    if not isinstance(build, str) or not re.fullmatch(r"\d+", build):
        fail("Resources/Info.plist must contain a numeric Mac build number.")

    notes_name = f"ReleaseNotes-{version}-build{build}.md"
    notes_path = root / "Documentation" / notes_name
    if not notes_path.is_file():
        fail(f"Missing current candidate notes: Documentation/{notes_name}")
    # Candidate notes are commonly still untracked while a local build is in
    # progress. Validate their contents above, but require the shared history
    # index to be committed before allowing the build.
    relative = "Documentation/ReleaseNotes.md"
    tracked = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--error-unmatch", "--", relative],
        capture_output=True, text=True, check=False,
    )
    if tracked.returncode:
        fail(f"Version history must be tracked before a build: {relative}")
    notes = notes_path.read_text()
    if notes.splitlines()[0:1] != [f"# Ultimate Lemmings {version}"]:
        fail(f"{notes_name} must start with '# Ultimate Lemmings {version}'.")
    if notes.splitlines().count(f"Build: {build}") != 1:
        fail(f"{notes_name} must identify build {build} exactly once.")
    bases = [line.removeprefix("Release base: ") for line in notes.splitlines()
             if line.startswith("Release base: ")]
    if len(bases) != 1 or not bases[0]:
        fail(f"{notes_name} must identify exactly one release base.")
    base = bases[0]
    if any(line.startswith("Release commit:") for line in notes.splitlines()):
        fail("Candidate notes must not contain a frozen release commit.")
    result = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--verify", f"{base}^{{commit}}"],
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        fail(f"Release base does not resolve in this repository: {base}")

    platform_builds = {}
    for name, relative in (
        ("iOS", "Apps/UltimateLemmingsIOS/UltimateLemmingsIOS.xcodeproj/project.pbxproj"),
        ("tvOS", "Apps/UltimateLemmingsTV/UltimateLemmingsTV.xcodeproj/project.pbxproj"),
    ):
        text = (root / relative).read_text()
        marketing = set(re.findall(r"MARKETING_VERSION\s*=\s*([^;]+);", text))
        builds = set(re.findall(r"CURRENT_PROJECT_VERSION\s*=\s*([^;]+);", text))
        if marketing != {version}:
            fail(f"{relative} marketing versions must all match {version}; found {sorted(marketing)}.")
        if len(builds) != 1 or not next(iter(builds)).isdigit():
            fail(f"{relative} must use one numeric build number across its targets.")
        platform_builds[name] = next(iter(builds))

    history = (root / "Documentation/ReleaseNotes.md").read_text()
    current_line = (f"The current source version is **{version}** "
                    f"(Mac build {build}, iOS build {platform_builds['iOS']}, "
                    f"tvOS build {platform_builds['tvOS']}).")
    if current_line not in history or f"]({notes_name})" not in history:
        fail("Documentation/ReleaseNotes.md must link the current version and build notes.")
    platform_line = (f"Platform builds: Mac {build}, iPhone/iPad/Duo {platform_builds['iOS']}, "
                     f"Apple TV {platform_builds['tvOS']}")
    if notes.splitlines().count(platform_line) != 1:
        fail(f"{notes_name} must identify all platform build numbers exactly once.")

    welcome = (root / "Sources/LemmingsLocal/ReleaseWelcome.swift").read_text()
    if f'static let notesVersion = "{version}"' not in welcome:
        fail(f"ReleaseWelcome.swift must use the current version {version}.")

    return version, build, notes_name


if __name__ == "__main__":
    try:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("--edition", choices=("ultimate-lemmings", "ultimate-lemmix"),
                            default=os.environ.get("LEMMINGS_PUBLICATION_EDITION", "ultimate-lemmings"))
        args = parser.parse_args()
        version, build, notes_name = validate(Path(__file__).resolve().parents[2], args.edition)
        print(f"PASS current version history: {version} build {build} ({notes_name})")
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)
