#!/usr/bin/env python3
"""Reject notarization archives whose app or nested Mach-O code lacks the expected Developer ID signature."""

import os
from pathlib import Path
import re
import subprocess
import sys


def run(*args):
    return subprocess.run(args, capture_output=True, text=True)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("Usage: verify-developer-id-signature.py APP EXPECTED_IDENTITY")
    app = Path(sys.argv[1]).resolve()
    expected_identity = sys.argv[2]
    match = re.search(r"\(([^()]+)\)$", expected_identity)
    if not app.is_dir() or not match:
        raise SystemExit("FAILED: app path or Developer ID identity is invalid.")
    expected_team = match.group(1)

    code = {app}
    for root, _, names in os.walk(app / "Contents", followlinks=False):
        for name in names:
            path = Path(root, name)
            if path.is_symlink() or not os.access(path, os.X_OK):
                continue
            kind = run("/usr/bin/file", "-b", str(path))
            if kind.returncode == 0 and "Mach-O" in kind.stdout:
                code.add(path)

    checked = 0
    for path in sorted(code, key=str):
        result = run("/usr/bin/codesign", "-dv", "--verbose=4", str(path))
        details = result.stderr + result.stdout
        if result.returncode:
            raise SystemExit(f"FAILED: cannot read code signature for {path}: {details.strip()}")
        authorities = [line.removeprefix("Authority=") for line in details.splitlines()
                       if line.startswith("Authority=")]
        team = next((line.removeprefix("TeamIdentifier=") for line in details.splitlines()
                     if line.startswith("TeamIdentifier=")), "")
        if not authorities or authorities[0] != expected_identity:
            actual = authorities[0] if authorities else "unsigned"
            raise SystemExit(f"FAILED: {path} is signed by {actual}; expected {expected_identity}.")
        if team != expected_team:
            raise SystemExit(f"FAILED: {path} has Team ID {team or 'missing'}; expected {expected_team}.")
        checked += 1

    result = run("/usr/bin/codesign", "--verify", "--deep", "--strict", str(app))
    if result.returncode:
        raise SystemExit("FAILED: strict app signature verification failed: " +
                         (result.stderr or result.stdout).strip())
    print(f"PASS Developer ID signature: {checked} Mach-O code objects use {expected_identity}")


if __name__ == "__main__":
    main()
