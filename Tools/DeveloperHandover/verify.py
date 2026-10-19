#!/usr/bin/env python3
"""Verify source tests in a separate snapshot without ignored assets or caches."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import uuid


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Tools/RepositoryMaintenance"))
from repository_policy import contains_symlink, exclusion_reason, repository_files


def git(root, *arguments):
    return subprocess.check_output(["git", *arguments], cwd=root)


def snapshot(root, destination):
    """Copy current Git-visible file bytes, never following symlinks."""
    entries, omitted = [], []
    for relative in repository_files(root):
        source = root / relative
        if exclusion_reason(relative):
            omitted.append(relative.as_posix())
            continue
        if contains_symlink(root, relative):
            raise ValueError(f"Review symlink before including it in a handover: {relative}")
        if not source.exists():
            continue  # A tracked deletion is part of the working-tree snapshot.
        if not source.is_file():
            raise ValueError(f"Expected a file, not a submodule or directory: {relative}")
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        content = target.read_bytes()
        entries.append({"path": relative.as_posix(), "bytes": len(content),
                        "sha256": hashlib.sha256(content).hexdigest()})
    return entries, omitted


def changed_inputs(root, entries):
    """Catch edits made while the sequential snapshot was being prepared."""
    changed = []
    for entry in entries:
        source = root / entry["path"]
        if (contains_symlink(root, Path(entry["path"])) or not source.is_file()
                or hashlib.sha256(source.read_bytes()).hexdigest() != entry["sha256"]):
            changed.append(entry["path"])
    current_paths = {path.as_posix() for path in repository_files(root)
                     if not exclusion_reason(path)}
    return sorted(set(changed) | (current_paths ^ {entry["path"] for entry in entries}))


def run_check(command, cwd, log_path, environment, timeout):
    started = datetime.now(timezone.utc)
    result = {"command": command, "log": log_path.name,
              "startedAt": started.isoformat()}
    with log_path.open("w") as log:
        try:
            process = subprocess.Popen(command, cwd=cwd, env=environment, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            process.wait(timeout=timeout)
            result.update(status="passed" if process.returncode == 0 else "failed",
                          exitCode=process.returncode)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            result.update(status="failed", reason=f"Timed out after {timeout} seconds")
        except OSError as error:
            result.update(status="failed", reason=str(error))
    result["seconds"] = round((datetime.now(timezone.utc) - started).total_seconds(), 2)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New directory for source, logs and report")
    parser.add_argument("--prepare-only", action="store_true", help="Copy inputs without running tests")
    parser.add_argument("--timeout", type=int, default=1800, help="Maximum seconds for the source test command")
    args = parser.parse_args()
    if args.timeout < 1:
        parser.error("--timeout must be positive")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output = (args.output or ROOT / ".build/developer-handover" / f"{stamp}-{uuid.uuid4().hex[:8]}").resolve()
    if output == ROOT or ROOT in output.parents and ".build" not in output.relative_to(ROOT).parts:
        parser.error("An in-repository output must be under .build")
    try:
        output.mkdir(parents=True, exist_ok=False)
    except OSError as error:
        parser.error(f"Cannot create a new output directory: {error}")
    source = output / "source"
    source.mkdir()
    report = {"schemaVersion": 1, "createdAt": datetime.now(timezone.utc).isoformat(),
              "status": "failed", "checks": [], "limits": [
                  "Working files are copied sequentially. Do not edit inputs during preparation.",
                  "This is a source-test check, not gameplay, release or rights clearance.",
                  "Ignored data and build caches are absent. System toolchains and SwiftPM dependency caches may be used."]}
    try:
        report["baseCommit"] = git(ROOT, "rev-parse", "HEAD").decode().strip()
        report["workingTreeStatus"] = git(ROOT, "status", "--porcelain=v1").decode()
        entries, omitted = snapshot(ROOT, source)
        manifest = json.dumps(entries, indent=2) + "\n"
        (output / "inputs.json").write_text(manifest)
        report.update(inputCount=len(entries), omitted=omitted,
                      inputManifestSHA256=hashlib.sha256(manifest.encode()).hexdigest())
        report["changedDuringPreparation"] = changed_inputs(ROOT, entries)
        if report["changedDuringPreparation"]:
            raise ValueError("Source changed during snapshot preparation. Stop edits and rerun.")
        environment = os.environ.copy()
        environment.update(LEMMINGS_TEST_AUDIO="muted", LEMMINGS_TEST_WINDOWS="offscreen")
        # Override inherited search paths that could resolve the original build.
        for key in ("SWIFTPM_CUSTOM_LIBS_DIR", "SWIFT_MODULECACHE_PATH", "CLANG_MODULE_CACHE_PATH",
                    "DYLD_LIBRARY_PATH", "DYLD_FRAMEWORK_PATH", "SDKROOT"):
            environment.pop(key, None)
        environment["CLANG_MODULE_CACHE_PATH"] = str(source / ".build/clang-module-cache")
        if args.prepare_only:
            report["status"] = "prepared"
        else:
            for name, command in (
                ("toolchain", ["swift", "--version"]),
                ("source-tests", ["zsh", "Scripts/run-source-tests.sh",
                                  "--cache-path", str(source / ".build/swiftpm-cache"),
                                  "--config-path", str(source / ".build/swiftpm-config"),
                                  "--security-path", str(source / ".build/swiftpm-security")]),
            ):
                print(f"Running {name}; log: {output / (name + '.log')}", flush=True)
                check = run_check(command, source, output / f"{name}.log", environment, args.timeout)
                report["checks"].append(check)
                if check["status"] != "passed":
                    break
            report["status"] = "passed" if all(c["status"] == "passed" for c in report["checks"]) else "failed"
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        report["error"] = str(error)
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"{report['status'].upper()}: {output / 'report.json'}")
    return 0 if report["status"] in {"passed", "prepared"} else 1


if __name__ == "__main__":
    sys.exit(main())
