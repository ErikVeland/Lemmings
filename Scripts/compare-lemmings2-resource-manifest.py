#!/usr/bin/env python3
"""Compare a Lemmings 2 resource tree with a release input manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
from pathlib import Path
from typing import Any


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("resource_root", type=Path)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()

    resource_root = args.resource_root.resolve(strict=True)
    manifest_path = args.manifest.resolve(strict=True)
    manifest_bytes = manifest_path.read_bytes()
    manifest: dict[str, Any] = json.loads(manifest_bytes)
    prefix = "Ports/Lemm2/"
    expected = {
        path[len(prefix) :]: record
        for path, record in manifest["files"].items()
        if path.startswith(prefix)
    }
    if not expected:
        raise SystemExit(f"No {prefix} entries found in {manifest_path}")

    actual = {
        path.relative_to(resource_root).as_posix(): {
            "sha256": sha256(path),
            "bytes": path.stat().st_size,
        }
        for path in resource_root.rglob("*")
        if path.is_file()
    }
    expected_paths, actual_paths = set(expected), set(actual)
    missing = sorted(expected_paths - actual_paths)
    unexpected = sorted(actual_paths - expected_paths)
    changed = [
        path
        for path in sorted(expected_paths & actual_paths)
        if expected[path]["sha256"] != actual[path]["sha256"]
        or expected[path]["bytes"] != actual[path]["bytes"]
    ]
    tree_rows = [
        [path, actual[path]["sha256"], actual[path]["bytes"]]
        for path in sorted(actual)
    ]
    tree_digest = hashlib.sha256(
        json.dumps(tree_rows, separators=(",", ":"), ensure_ascii=False).encode()
    ).hexdigest()
    bundle_info_path = resource_root.parents[2] / "Info.plist"
    bundle_info = (
        plistlib.loads(bundle_info_path.read_bytes())
        if bundle_info_path.is_file()
        else {}
    )
    result = {
        "schemaVersion": 1,
        "baselineVersion": manifest.get("baselineVersion"),
        "baselineBuild": manifest.get("baselineBuild"),
        "baselinePurpose": manifest.get("purpose"),
        "resourceBundleVersion": bundle_info.get("CFBundleShortVersionString"),
        "resourceBundleBuild": bundle_info.get("CFBundleVersion"),
        "resourceRoot": str(resource_root),
        "manifest": str(manifest_path),
        "manifestSHA256": hashlib.sha256(manifest_bytes).hexdigest(),
        "resourcePrefix": prefix,
        "expectedFiles": len(expected),
        "actualFiles": len(actual),
        "matchedFiles": len(expected_paths & actual_paths) - len(changed),
        "missingFiles": missing,
        "unexpectedFiles": unexpected,
        "changedFiles": [
            {
                "path": path,
                "expectedSHA256": expected[path]["sha256"],
                "actualSHA256": actual[path]["sha256"],
                "expectedBytes": expected[path]["bytes"],
                "actualBytes": actual[path]["bytes"],
            }
            for path in changed
        ],
        "resourceTreeSHA256": tree_digest,
        "matches": not missing and not unexpected and not changed,
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))
    if not result["matches"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
