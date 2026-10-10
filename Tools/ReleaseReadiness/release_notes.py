#!/usr/bin/env python3
"""Check a reviewed release-notes draft and stamp the frozen source commit."""

import argparse
from pathlib import Path
import re


def render_release_notes(draft: str, build: str, base: str, commit: str) -> str:
    """Return notes for one build and one frozen Git commit."""
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("The release commit must be a full Git SHA.")

    lines = draft.splitlines()
    build_line = f"Build: {build}"
    base_line = f"Release base: {base}"
    if lines.count(build_line) != 1:
        raise ValueError(f"The draft must identify build {build} exactly once.")
    if lines.count(base_line) != 1:
        raise ValueError(f"The draft must identify release base {base} exactly once.")
    if any(line.startswith("Release commit:") for line in lines):
        raise ValueError("The draft must not contain a release commit. The package adds it.")

    lines.insert(lines.index(build_line) + 1, f"Release commit: {commit}")
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--draft", type=Path, required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--base", required=True)
    parser.add_argument("--commit", required=True)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--check", action="store_true")
    action.add_argument("--output", type=Path)
    args = parser.parse_args()

    rendered = render_release_notes(
        args.draft.read_text(), args.build, args.base, args.commit
    )
    if args.output:
        args.output.write_text(rendered)
        print(f"Wrote release notes: {args.output}")
    else:
        print(f"PASS release notes draft for build {args.build}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        print(f"FAILED: {error}")
        raise SystemExit(1)
