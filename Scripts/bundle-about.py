#!/usr/bin/env python3
"""Bundle current release notes and fallback credits for the Mac About page."""
from pathlib import Path
import plistlib
import re
import shutil
import sys


def bundle(destination, root=None):
    root = root or Path(__file__).resolve().parent.parent
    destination.mkdir(parents=True, exist_ok=True)
    with (root / "Resources/Info.plist").open("rb") as source:
        info = plistlib.load(source)
    version = info["CFBundleShortVersionString"]
    build = info["CFBundleVersion"]
    notes = root / f"Documentation/ReleaseNotes-{version}-build{build}.md"
    history = ""
    if notes.is_file():
        body = re.sub(r"(?m)^# .+\n?", "", notes.read_text(encoding="utf-8"))
        body = re.sub(r"(?m)^(?:Build|Platform builds|Release base|Release commit):[^\n]*\n?", "", body).strip()
        history = f"# {version} · Build {build}\n\n{body}\n"
    (destination / "VersionHistory.md").write_text(history, encoding="utf-8")
    shutil.copyfile(root / "Resources/About/Heritage.md", destination / "Heritage.md")
    shutil.copyfile(root / "Tools/Telemetry/contributors.md", destination / "Contributors.md")


if __name__ == "__main__":
    bundle(Path(sys.argv[1]))
