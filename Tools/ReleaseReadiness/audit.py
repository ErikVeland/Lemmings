#!/usr/bin/env python3
"""Run fresh engine, input and campaign checks. A green run is not platform certification."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
SUITES = """ClassicGameFlowTests ClassicSettingsTests ClassicSoundCueTests AudioMatrixTests
NeoLemmixSimulationTests NxlvRendererTests NxlvStyleResolverTests ClassicDOSSimulationRegressions
ClassicDOSRewindTests ClassicDOSReplayTests ProTrackerTests PercussionTests AdaptiveDJDirectorTests
FLICTests Lemmings2RuntimeTests Lemmings2IntroTests Lemmings3RuntimeTests Lemmings3SoundTests
UnifiedGameTests ClassicSagaTests PlatformProfileTests AmigaSoundTests AmigaVersusTests BundledGameResourcesTests
PlatformExclusiveTests NeoLemmixEndToEnd PortableTests ModernEngineTests SequelDataTests""".split()


def manifest(paths):
    result = {}
    for path in sorted(set(paths)):
        if not path.is_file():
            continue
        digest = hashlib.sha256()
        with path.open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(chunk)
        result[str(path.relative_to(ROOT))] = digest.hexdigest()
    return result


def input_paths():
    # Include evidence and actual asset inputs, including the installed test bundle.
    folders = ["Sources", "Tests", "Scripts", "Tools", "Resources", "Content",
               "Documentation/CampaignCompletion", "Documentation/ClassicCompletion", "Documentation/Lemmings2Completion",
               "Documentation/TrolleyVerification", "Documentation/ReleaseReadiness",
               ".build/local/Ultimate Lemmings.app/Contents/Resources"]
    paths = [ROOT / "Package.swift"]
    for folder in folders:
        paths.extend(path for path in (ROOT / folder).rglob("*")
                     if "__pycache__" not in path.parts and path.suffix != ".pyc"
                     and path.name != ".DS_Store")
    return paths


def exit_status(checks, drift, gates, require_closure):
    if drift or any(item["status"] == "failed" for item in checks):
        return 1
    if require_closure and (any(item["status"] != "passed" for item in checks)
                            or any(gate["status"] != "closed" for gate in gates)):
        return 2
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / ".build/release-audit" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
    parser.add_argument("--app", action="store_true", help="Also run the complete macOS app and sequel view checks")
    parser.add_argument("--require-closure", action="store_true", help="Fail while any tracked release gate is still open")
    args = parser.parse_args()
    os.chdir(ROOT)
    base = args.out.resolve()
    base.mkdir(parents=True, exist_ok=False)
    logs, library, frozen = base / "logs", base / "library", base / "source"
    for path in [logs, library / "modules", frozen]:
        path.mkdir(parents=True, exist_ok=True)
    before = manifest(input_paths())
    (base / "inputs.json").write_text(json.dumps(before, indent=2) + "\n")
    for source in ROOT.glob("Sources/NxlvKit/*.swift"):
        shutil.copy2(source, frozen / source.name)
    checks = []

    def run(name, commands, env=None):
        started = time.monotonic()
        code = 0
        with (logs / (name + ".log")).open("w") as output:
            try:
                for command in commands:
                    code = subprocess.run([str(x) for x in command], cwd=ROOT,
                                          stdout=output, stderr=subprocess.STDOUT, env=env,
                                          timeout=1800).returncode
                    if code:
                        break
            except (OSError, subprocess.TimeoutExpired) as error:
                output.write(str(error) + "\n")
                code = 1
        result = dict(name=name, status="passed" if code == 0 else "failed",
                      seconds=round(time.monotonic() - started, 1), log="logs/" + name + ".log")
        print(result["status"].upper(), name, flush=True)
        return result

    def compile_command(source, output, extra=()):
        return ["swiftc", "-O", "-swift-version", "6", *extra, "-I", library / "modules", "-L", library,
                "-lNxlvKit", "-Xlinker", "-rpath", "-Xlinker", library, "-o", output, source]

    checks.append(run("shared-library", [["swiftc", "-O", "-swift-version", "6", "-parse-as-library",
        "-emit-module", "-emit-library", "-module-name", "NxlvKit", "-emit-module-path",
        library / "modules/NxlvKit.swiftmodule", "-Xlinker", "-install_name", "-Xlinker",
        "@rpath/libNxlvKit.dylib", "-o", library / "libNxlvKit.dylib", *sorted(frozen.glob("*.swift"))]]))
    app = ROOT / ".build/local/Ultimate Lemmings.app"
    ports = app / "Contents/Resources/Ports"
    if checks[-1]["status"] == "passed":
        def suite(name):
            flags = ["-parse-as-library"] if name in ["NxlvRendererTests", "NxlvStyleResolverTests"] else []
            arguments = []
            if name in ["ClassicGameFlowTests", "ClassicDOSSimulationRegressions", "ClassicDOSRewindTests", "ClassicDOSReplayTests"]:
                arguments = [ROOT / "Content/lemming1.pc"]
            if name in ["Lemmings2RuntimeTests", "Lemmings2IntroTests"]:
                arguments = [ROOT / "Sources/Ports/Lemm2"]
            if name == "Lemmings3RuntimeTests":
                arguments = [ROOT / "Sources/Ports/LEM3CD"]
            if name == "UnifiedGameTests":
                arguments = [app / "Contents/Resources"]
            if name == "BundledGameResourcesTests":
                arguments = [app]
            if name == "PortableTests":
                arguments = [ROOT]
            binary = library / name
            return run(name, [compile_command(ROOT / "Tests" / name / "main.swift", binary, flags), [binary, *arguments]])
        with ThreadPoolExecutor(max_workers=4) as pool:
            checks.extend(pool.map(suite, SUITES))
        checks.append(run("save-recovery", [["zsh", "Scripts/run-save-recovery-tests.sh"]],
                          dict(os.environ, SAVE_TEST_LIBRARY_DIR=str(library))))
        checks.append(run("run-recovery-files", [["zsh", "Scripts/run-run-recovery-file-tests.sh"]],
                          dict(os.environ, SAVE_TEST_LIBRARY_DIR=str(library))))
        checks.append(run("fan-library", [["zsh", "Scripts/run-fan-library-tests.sh"]],
                          dict(os.environ, FAN_TEST_LIBRARY_DIR=str(library))))
        verifier = library / "ClassicCompletion"
        data = ports / "lemmings_dos_1991-07-30"
        checks.append(run("original-120-solutions", [compile_command(ROOT / "Tools/ClassicCompletion/main.swift", verifier),
            [verifier, "verify", data], [sys.executable, "Tests/ClassicDOSCompletionTests/test_gate.py", verifier, data]]))
        environment = dict(os.environ, CAMPAIGN_TEST_LIBRARY_DIR=str(library))
        checks.append(run("additional-campaign-solutions", [["zsh", "Scripts/verify-campaign-completion.sh"]], environment))
        checks.append(run("l3-solutions", [["zsh", "Scripts/verify-l3-completion.sh"]],
                          dict(os.environ, L3_TEST_LIBRARY_DIR=str(library))))
        l2_verifier, l2_negative = library / "L2Completion", library / "L2CompletionNegative"
        l2_data = ROOT / "Sources/Ports/Lemm2"
        checks.append(run("l2-solutions", [
            [sys.executable, "Tools/Lemmings2Completion/report.py", "--check"],
            compile_command(ROOT / "Tools/Lemmings2Completion/main.swift", l2_verifier),
            [l2_verifier, l2_data],
            compile_command(ROOT / "Tests/Lemmings2CompletionTests/negative.swift", l2_negative),
            [l2_negative, l2_data]]))
    for name, command in [
        ("audit-integrity", [sys.executable, "Tests/ReleaseReadinessTests/test_audit.py"]),
        ("hint-catalogue", ["zsh", "Scripts/test-level-hint-catalogue.sh"]),
        ("controller", ["zsh", "Scripts/run-controller-qol-tests.sh"]),
        ("variable-speed", ["zsh", "Scripts/run-gameplay-speed-tests.sh"]),
        ("pointer-capture", ["zsh", "Scripts/run-pointer-capture-tests.sh"]),
        ("hdr-gpu", ["zsh", "Scripts/run-explosion-hdr-tests.sh"]),
        ("rescue-certificates", [sys.executable, "Tools/TrolleyVerification/catalogue.py", "check"]),
    ]:
        checks.append(run(name, [command]))
    if args.app:
        checks.append(run("mac-app-integration", [["zsh", "Scripts/run-app-integration-tests.sh"]]))
        checks.append(run("sequel-views", [["zsh", "Scripts/run-sequel-mac-artwork-tests.sh"]]))
        checks.append(run("arcade-records", [["zsh", "Scripts/run-arcade-records-tests.sh"]]))
    else:
        checks.append(dict(name="mac-app-integration", status="not-run", reason="Use --app. Separate app evidence must match the final source."))
        checks.append(dict(name="sequel-views", status="not-run", reason="Use --app."))
        checks.append(dict(name="arcade-records", status="not-run", reason="Use --app."))
    after = manifest(input_paths())
    drift = sorted(key for key in set(before) | set(after) if before.get(key) != after.get(key))
    gates = json.loads((ROOT / "Documentation/ReleaseReadiness/gates.json").read_text())
    sdk = subprocess.run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], capture_output=True, text=True)
    report = dict(schemaVersion=1, generatedAt=datetime.now(timezone.utc).isoformat(),
                  host=platform.platform(), inputManifest="inputs.json", sourceDrift=drift,
                  checks=checks, gates=gates,
                  iosSimulatorSDK=sdk.stdout.strip() if sdk.returncode == 0 else "unavailable",
                  releaseReady=False,
                  scope="Fresh local regression evidence. Does not certify hardware, stores, complete campaigns or other platforms.")
    (base / "results.json").write_text(json.dumps(report, indent=2) + "\n")
    lines = ["# Release audit", "", report["scope"], "", "**Release closure: open.**", "",
             "| Check | Result | Evidence |", "| --- | --- | --- |"]
    for item in checks:
        evidence = f"[Log]({item['log']})" if "log" in item else item["reason"]
        lines.append(f"| {item['name']} | {item['status']} | {evidence} |")
    lines += ["", f"Source drift: {len(drift)} files.", "", "## Open gates", ""]
    lines += [f"- **{gate['area']}** ({gate['priority']}): {gate['exitCriteria']}" for gate in gates if gate["status"] != "closed"]
    (base / "report.md").write_text("\n".join(lines) + "\n")
    print(base / "report.md")
    return exit_status(checks, drift, gates, args.require_closure)


if __name__ == "__main__":
    raise SystemExit(main())
