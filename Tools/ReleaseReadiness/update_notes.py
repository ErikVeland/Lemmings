#!/usr/bin/env python3
"""Render stamped release notes as HTML for the Sparkle update alert."""

import argparse
from html import escape
from pathlib import Path
import re

METADATA = ("Build:", "Release commit:", "Release base:")


def _inline(text: str) -> str:
    text = escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"`(.+?)`", r"<code>\1</code>", text)
    return re.sub(r"\[(.+?)\]\((https://[^)\s]+)\)", r'<a href="\2">\1</a>', text)


def render_update_notes(markdown: str) -> str:
    """Return player-facing HTML. Build metadata moves to a small footer."""
    blocks, metadata, paragraph, items = [], [], [], []

    def flush():
        if paragraph:
            blocks.append(f"<p>{_inline(' '.join(paragraph))}</p>")
            paragraph.clear()
        if items:
            blocks.append("<ul>" + "".join(f"<li>{_inline(i)}</li>" for i in items) + "</ul>")
            items.clear()

    for line in markdown.splitlines():
        stripped = line.strip()
        if stripped.startswith(METADATA):
            flush()
            metadata.append(stripped)
        elif not stripped:
            flush()
        elif heading := re.match(r"(#{1,4})\s+(.*)", stripped):
            flush()
            # The alert already names the app, so the title heading is dropped.
            if len(heading[1]) > 1:
                level = min(len(heading[1]) + 1, 4)
                blocks.append(f"<h{level}>{_inline(heading[2])}</h{level}>")
        elif stripped.startswith("- "):
            if paragraph:
                flush()
            items.append(stripped[2:])
        elif items and line.startswith("  "):
            items[-1] += " " + stripped
        elif stripped.startswith("[Download"):
            # Players who see the alert already have the app.
            continue
        else:
            paragraph.append(stripped)
    flush()
    if metadata:
        blocks.append(f'<p class="meta">{"<br>".join(escape(m) for m in metadata)}</p>')
    style = ("<style>:root{color-scheme:light dark}body{font:13px -apple-system,sans-serif}h3{font-size:14px;margin:14px 0 4px}"
             "h4{font-size:13px;margin:10px 0 2px}ul{padding-left:18px;margin:4px 0}"
             ".meta{color:#888;font-size:11px}</style>")
    return f"<html><head><meta charset=\"utf-8\">{style}</head><body>" + "\n".join(blocks) + "</body></html>\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("notes", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.write_text(render_update_notes(args.notes.read_text()))


if __name__ == "__main__":
    main()
