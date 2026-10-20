#!/usr/bin/env python3
"""Bundle published version history and fallback credits for the Mac About page."""
from html.parser import HTMLParser
from pathlib import Path
import plistlib
import re
import shutil
import sys
import xml.etree.ElementTree as ET


class NotesText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []
        self.hidden = 0

    def handle_starttag(self, tag, attrs):
        if tag in {"style", "script", "head"}:
            self.hidden += 1
        if not self.hidden:
            if tag in {"p", "h1", "h2", "h3", "h4", "ul"}:
                self.parts.append("\n\n")
            if tag in {"h1", "h2", "h3", "h4"}:
                self.parts.append("### ")
            if tag == "li":
                self.parts.append("\n- ")
            if tag == "br":
                self.parts.append("\n\n")

    def handle_endtag(self, tag):
        if tag in {"style", "script", "head"}:
            self.hidden -= 1
        if not self.hidden and tag in {"p", "h1", "h2", "h3", "h4", "ul"}:
            self.parts.append("\n\n")

    def handle_data(self, data):
        if not self.hidden:
            self.parts.append(data)


def bundle(destination, root=None):
    root = root or Path(__file__).resolve().parent.parent
    destination.mkdir(parents=True, exist_ok=True)
    namespace = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
    sections = []
    included = set()
    # Packaging precedes feed publication. Include the app's own notes directly.
    with (root / "Resources/Info.plist").open("rb") as source:
        info = plistlib.load(source)
    current = (info["CFBundleShortVersionString"], info["CFBundleVersion"])
    notes = root / f"Documentation/ReleaseNotes-{current[0]}-build{current[1]}.md"
    if notes.exists():
        body = re.sub(r"(?m)^# .+\n?", "", notes.read_text(encoding="utf-8"))
        body = re.sub(r"(?m)^(?:Build|Release base|Release commit):[^\n]*\n?", "", body).strip()
        sections.append(f"# {current[0]} · Build {current[1]}\n\n{body}")
        included.add(current)
    for item in ET.parse(root / "appcast.xml").findall("./channel/item"):
        version = item.findtext("sparkle:shortVersionString", namespaces=namespace) or item.findtext("title", "")
        build = item.findtext("sparkle:version", namespaces=namespace) or ""
        if (version, build) in included:
            continue
        included.add((version, build))
        parser = NotesText()
        parser.feed(item.findtext("description", ""))
        # Keep paragraphs while dropping blank runs and obsolete release metadata.
        paragraphs = [p.strip() for p in "".join(parser.parts).split("\n\n") if p.strip()]
        paragraphs = [p for p in paragraphs if not p.startswith("Build:")]
        sections.append(f"# {version} · Build {build}\n\n" + "\n\n".join(paragraphs))
    (destination / "VersionHistory.md").write_text("\n\n".join(sections) + "\n", encoding="utf-8")
    shutil.copyfile(root / "Resources/About/Heritage.md", destination / "Heritage.md")
    shutil.copyfile(root / "Tools/Telemetry/contributors.md", destination / "Contributors.md")


if __name__ == "__main__":
    bundle(Path(sys.argv[1]))
