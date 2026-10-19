#!/usr/bin/env python3
"""Check repository hygiene, source syntax, structured files and local Markdown links."""

import argparse
import ast
from collections import Counter
import json
from pathlib import Path
import plistlib
import re
import subprocess
from urllib.parse import unquote, urlsplit

from repository_policy import contains_symlink, exclusion_reason, repository_files


ROOT = Path(__file__).resolve().parents[2]


def check_files(root, paths):
    errors, counts = [], Counter()
    for relative in paths:
        path = root / relative
        if reason := exclusion_reason(relative):
            errors.append(f"{relative}: {reason}")
            continue
        if contains_symlink(root, relative):
            errors.append(f"{relative}: review symlinks before adding them to repository source")
            continue
        if not path.is_file():
            continue
        counts["files"] += 1
        try:
            if path.suffix == ".py":
                ast.parse(path.read_text(), filename=str(relative))
                counts["python"] += 1
            elif path.suffix == ".json":
                json.loads(path.read_text())
                counts["json"] += 1
            elif path.suffix in {".plist", ".entitlements", ".xcprivacy", ".stringsdict"}:
                plistlib.loads(path.read_bytes())
                counts["plist"] += 1
            elif path.suffix == ".sh":
                lines = path.read_text().splitlines()
                interpreter = "zsh" if lines and "zsh" in lines[0] else "bash"
                result = subprocess.run([interpreter, "-n", str(path)], capture_output=True, text=True)
                if result.returncode:
                    errors.append(f"{relative}: {result.stderr.strip()}")
                counts["shell"] += 1
            elif path.suffix == ".md":
                text = re.sub(r"```.*?```|~~~.*?~~~", "", path.read_text(), flags=re.S)
                for match in re.finditer(r"!?\[[^\]]*\]\((<[^>]+>|[^)\s]+)(?:\s+\"[^\"]*\")?\)", text):
                    target = match[1].strip("<>")
                    url = urlsplit(target)
                    if url.scheme or not url.path or target.startswith("/"):
                        continue
                    counts["local_links"] += 1
                    if not (path.parent / unquote(url.path)).exists():
                        errors.append(f"{relative}: missing link target {target}")
                counts["markdown"] += 1
        except (ValueError, OSError, SyntaxError, UnicodeError, plistlib.InvalidFileException) as error:
            errors.append(f"{relative}: {error}")
    return dict(counts), errors


def check_release(root):
    info = plistlib.loads((root / "Resources/Info.plist").read_bytes())
    version, build = info["CFBundleShortVersionString"], info["CFBundleVersion"]
    welcome = (root / "Sources/LemmingsLocal/ReleaseWelcome.swift").read_text()
    errors = []
    if f'static let notesVersion = "{version}"' not in welcome:
        errors.append("ReleaseWelcome.swift: version differs from Resources/Info.plist")
    notes = root / f"Documentation/ReleaseNotes-{version}-build{build}.md"
    if not notes.is_file() or notes.read_text().splitlines().count(f"Build: {build}") != 1:
        errors.append(f"{notes.relative_to(root)}: matching release notes are required")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    counts, errors = check_files(ROOT, repository_files(ROOT))
    errors.extend(check_release(ROOT))
    report = {"status": "failed" if errors else "passed", "checks": counts, "errors": errors}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
