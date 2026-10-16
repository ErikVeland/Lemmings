#!/usr/bin/env python3
"""Capture repository inputs without changing Git or following source symlinks."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import shutil
from datetime import datetime, timezone


def capture(repository, destination):
    destination.mkdir(parents=True, exist_ok=False)
    source = destination / "source"
    source.mkdir()
    names = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=repository).decode().split("\0")
    records = []
    for name in sorted(set(filter(None, names))):
        original = repository / name
        if not original.is_file() and not original.is_symlink():
            continue
        target = source / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if original.is_symlink():
            data = os.readlink(original).encode()
            target.symlink_to(os.readlink(original))
            kind = "symlink"
        else:
            data = original.read_bytes()
            target.write_bytes(data)
            target.chmod(0o555 if os.access(original, os.X_OK) else 0o444)
            kind = "file"
        records.append(dict(path=name, kind=kind, bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
    manifest = dict(capturedAtUTC=datetime.now(timezone.utc).isoformat(),
                    head=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repository, text=True).strip(),
                    branch=subprocess.check_output(["git", "branch", "--show-current"], cwd=repository, text=True).strip(),
                    files=records,
                    treeSHA256=hashlib.sha256(json.dumps(records, sort_keys=True, separators=(",", ":")).encode()).hexdigest())
    (destination / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (destination / "working-tree.patch").write_bytes(subprocess.check_output(["git", "diff", "--binary", "HEAD"], cwd=repository))
    (destination / "working-tree-status.txt").write_bytes(subprocess.check_output(["git", "status", "--short"], cwd=repository))
    print(manifest["treeSHA256"])


def seal_assets(root, manifest, origins):
    records = []
    for path in sorted(root.rglob("*")):
        if path.is_file():
            data = path.read_bytes()
            records.append(dict(path=str(path.relative_to(root)), bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
            path.chmod(0o444)
    document = dict(origins=origins, files=records,
                    treeSHA256=hashlib.sha256(json.dumps(records, sort_keys=True, separators=(",", ":")).encode()).hexdigest())
    manifest.write_text(json.dumps(document, indent=2) + "\n")
    return document


def capture_assets(destination, resources, neo, candidates=None):
    root = destination / "assets"
    root.mkdir(exist_ok=False)
    for name in ["Ports", "LevelPacks", "Localization.bundle", "Hints", "Progression"]:
        shutil.copytree(resources / name, root / "resources" / name, symlinks=False)
    for name in ["levels", "styles"]:
        shutil.copytree(neo / name, root / "neo" / name, symlinks=False)
    origins = dict(resources=str(resources.resolve()), neo=str(neo.resolve()))
    if candidates:
        shutil.copyfile(candidates, root / "candidate-solutions.json")
        origins["classicCandidates"] = str(candidates.resolve())
    return seal_assets(root, destination / "assets-manifest.json", origins)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repository", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--resources", type=Path)
    parser.add_argument("--neo", type=Path)
    parser.add_argument("--classic-candidates", type=Path)
    args = parser.parse_args()
    if bool(args.resources) != bool(args.neo):
        parser.error("--resources and --neo must be supplied together")
    capture(args.repository.resolve(), args.destination.resolve())
    if args.resources:
        print(capture_assets(args.destination.resolve(), args.resources, args.neo, args.classic_candidates)["treeSHA256"])
