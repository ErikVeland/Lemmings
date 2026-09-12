#!/usr/bin/env python3
"""Record and compare every source, fixture and packaged input used by the audit."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

project, resources, fixtures, output = map(Path, sys.argv[1:5])
roots = [project / "Sources/NxlvKit", project / "Tools/ClassicValidation",
         project / "Sources/LemmingsLocal/FanLevelLibrary.swift",
         project / "Scripts/run-classic-validation.sh", resources / "Ports",
         resources / "LevelPacks", fixtures / "Tests/ClassicDOSCompletionTests/Fixtures",
         fixtures / "Tests/ClassicFamilyCompletionTests/Fixtures"]
paths = set()
for root in roots:
    if not root.exists():
        sys.exit("Missing input: " + str(root))
    paths.update([root] if root.is_file() else (p for p in root.rglob("*") if p.is_file() and "__pycache__" not in p.parts))
hashes = {}
for path in sorted(paths):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    hashes[str(path)] = digest.hexdigest()
manifest = {"source": subprocess.check_output(["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip(),
            "files": hashes}
output.mkdir(parents=True, exist_ok=True)
if len(sys.argv) > 5 and sys.argv[5] == "--check":
    original = json.loads((output / "inputs.json").read_text())
    changed = sorted(key for key in set(original["files"]) | set(hashes) if original["files"].get(key) != hashes.get(key))
    (output / "input-drift.json").write_text(json.dumps({"changed": changed}, indent=2) + "\n")
    sys.exit(1 if changed else 0)
(output / "inputs.json").write_text(json.dumps(manifest, indent=2) + "\n")
