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


def input_paths(app=None):
    # Include evidence and actual asset inputs, including the installed test bundle.
    folders = ["Sources", "Tests", "Scripts", "Tools", "Resources", "Content",
               "Documentation/CampaignCompletion", "Documentation/ClassicCompletion", "Documentation/Lemmings2Completion",
               "Documentation/TrolleyVerification", "Documentation/ReleaseReadiness"]
    paths = [ROOT / "Package.swift", ROOT / "Documentation/ReleaseScope.md",
             ROOT / "Documentation/FanLevelPruning.json"]
    folders.append((app or ROOT / ".build/local/Ultimate Lemmings.app") / "Contents/Resources")
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


def scoped_gates(gates, scope):
    # Untagged gates remain mandatory. Missing metadata must not hide a blocker.
    if scope == "all":
        return gates
    return [gate for gate in gates if scope in gate.get("scopes", [scope])]


def campaign_command(scope):
    command = ["zsh", "Scripts/verify-campaign-completion.sh", "--classic-only"]
    if scope == "classic-1.0":
        command.append("--require-all")
    return command


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / ".build/release-audit" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
    parser.add_argument("--app", action="store_true", help="Also run the complete macOS app and sequel view checks")
    parser.add_argument("--app-bundle", type=Path, default=ROOT / ".build/local/Ultimate Lemmings.app",
                        help="Resource bundle for fresh tests. Use a candidate inside this checkout.")
    parser.add_argument("--scope", choices=["all", "classic-1.0"], default="all",
                        help="Classic 1.0 requires official and conversion wins, fan load/start checks, and sequel regressions.")
    parser.add_argument("--require-closure", action="store_true", help="Fail while any tracked release gate is still open")
    args = parser.parse_args()
    app = args.app_bundle.resolve()
    if not app.is_relative_to(ROOT) or not (app / "Contents/Resources").is_dir():
        parser.error("--app-bundle must contain Resources and be inside this checkout")
    os.chdir(ROOT)
    base = args.out.resolve()
    base.mkdir(parents=True, exist_ok=False)
    logs, library, frozen = base / "logs", base / "library", base / "source"
    for path in [logs, library / "modules", frozen]:
        path.mkdir(parents=True, exist_ok=True)
    before = manifest(input_paths(app))
    (base / "inputs.json").write_text(json.dumps(before, indent=2) + "\n")
    for source in ROOT.glob("Sources/NxlvKit/*.swift"):
        shutil.copy2(source, frozen / source.name)
    checks = []
    compiler_target = f"{platform.machine()}-apple-macos12.3"

    def run(name, commands, env=None):
        env = dict(env or os.environ, LEMMINGS_TEST_APP=str(app),
                   CAMPAIGN_TEST_RESOURCES=str(app / "Contents/Resources"))
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
        return ["swiftc", "-O", "-swift-version", "6", "-target", compiler_target, *extra, "-I", library / "modules", "-L", library,
                "-lNxlvKit", "-Xlinker", "-rpath", "-Xlinker", library, "-o", output, source]

    checks.append(run("shared-library", [["swiftc", "-O", "-swift-version", "6", "-target", compiler_target, "-parse-as-library",
        "-emit-module", "-emit-library", "-module-name", "NxlvKit", "-emit-module-path",
        library / "modules/NxlvKit.swiftmodule", "-Xlinker", "-install_name", "-Xlinker",
        "@rpath/libNxlvKit.dylib", "-o", library / "libNxlvKit.dylib", *sorted(frozen.glob("*.swift"))]]))
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
        checks.append(run("cross-build-recovery", [["zsh", "Scripts/run-cross-build-recovery-tests.sh"]],
                          dict(os.environ, SAVE_TEST_LIBRARY_DIR=str(library), CROSS_BUILD_PORTS=str(ports))))
        checks.append(run("fan-library", [["zsh", "Scripts/run-fan-library-tests.sh"]],
                          dict(os.environ, FAN_TEST_LIBRARY_DIR=str(library))))
        verifier = library / "ClassicCompletion"
        data = ports / "lemmings_dos_1991-07-30"
        checks.append(run("original-120-solutions", [compile_command(ROOT / "Tools/ClassicCompletion/main.swift", verifier),
            [verifier, "verify", data], [sys.executable, "Tools/ClassicCompletion/report.py", "--check"],
            [sys.executable, "Tests/ClassicDOSCompletionTests/test_gate.py", verifier, data]]))
        environment = dict(os.environ, CAMPAIGN_TEST_LIBRARY_DIR=str(library),
                           CAMPAIGN_TEST_RESOURCES=str(app / "Contents/Resources"))
        checks.append(run("additional-campaign-solutions", [campaign_command(args.scope)], environment))
        if args.scope == "classic-1.0":
            quest_verifier = library / "OfficialClassicQuest"
            checks.append(run("official-classic-quest", [
                compile_command(ROOT / "Tools/OfficialClassicQuest/main.swift", quest_verifier,
                                [ROOT / "Sources/LemmingsLocal/GameSession.swift",
                                 ROOT / "Sources/LemmingsLocal/RunRecovery.swift"]),
                [quest_verifier, ports, base / "official-classic-quest.json"],
                [quest_verifier, ports, base / "classic-conversion-quest.json", "--include-conversions"],
                [sys.executable, "Tests/ClassicFamilyCompletionTests/test_official_quest.py", quest_verifier, ports, "--include-conversions"]]))
            corpus = base / "classic-corpus"
            corpus.mkdir()
            corpus_verifier = library / "ClassicCorpus"
            checks.append(run("classic-fan-conversion-completion", [
                compile_command(ROOT / "Tools/ClassicValidation/main.swift", corpus_verifier,
                                [ROOT / "Sources/LemmingsLocal/FanLevelLibrary.swift"]),
                [sys.executable, "Tools/ClassicValidation/parallel.py", corpus_verifier,
                 app / "Contents/Resources", corpus, ROOT, "4"]]))
        checks.append(run("l3-solutions", [["zsh", "Scripts/verify-l3-completion.sh"]],
                          dict(os.environ, L3_TEST_LIBRARY_DIR=str(library))))
        l2_verifier, l2_negative = library / "L2Completion", library / "L2CompletionNegative"
        l2_data = ROOT / "Sources/Ports/Lemm2"
        checks.append(run("l2-solutions", [
            [sys.executable, "Tests/Lemmings2CompletionTests/test_chains.py"],
            [sys.executable, "Tools/Lemmings2Completion/report.py", "--check"],
            compile_command(ROOT / "Tools/Lemmings2Completion/main.swift", l2_verifier),
            [l2_verifier, l2_data],
            [sys.executable, "Tests/Lemmings2CompletionTests/test_chain_gate.py", l2_verifier, l2_data],
            compile_command(ROOT / "Tests/Lemmings2CompletionTests/negative.swift", l2_negative),
            [l2_negative, l2_data]]))
    for name, command in [
        ("audit-integrity", [sys.executable, "Tests/ReleaseReadinessTests/test_audit.py"]),
        ("package-closure", [sys.executable, "Tests/ReleaseReadinessTests/test_package_scope.py"]),
        ("automatic-updates", [sys.executable, "Tests/ReleaseReadinessTests/test_automatic_updates.py"]),
        ("classic-panel-art", [sys.executable, "Tools/ClassicPanelArt/check.py"]),
        ("fan-pruning", [sys.executable, "Tools/FanLevelCatalog/test_prune.py"]),
        ("retained-rescue-targets", [sys.executable, "Tools/TrolleyVerification/test_retained_targets.py"]),
        ("hint-catalogue", ["zsh", "Scripts/test-level-hint-catalogue.sh"]),
        ("controller", ["zsh", "Scripts/run-controller-qol-tests.sh"]),
        ("variable-speed", ["zsh", "Scripts/run-gameplay-speed-tests.sh"]),
        ("pointer-capture", ["zsh", "Scripts/run-pointer-capture-tests.sh"]),
        ("hdr-gpu", ["zsh", "Scripts/run-explosion-hdr-tests.sh"]),
        ("rescue-certificates", [sys.executable, "Tools/TrolleyVerification/catalogue.py", "check"]),
    ]:
        checks.append(run(name, [command]))
    if args.app:
        checks.append(run("replay-movies", [["zsh", "Scripts/run-replay-movie-tests.sh"]],
                          dict(os.environ, REPLAY_TEST_LIBRARY_DIR=str(library))))
        checks.append(run("mac-app-integration", [["zsh", "Scripts/run-app-integration-tests.sh"]]))
        checks.append(run("local-performance-measurement", [["zsh", "Scripts/run-app-integration-tests.sh"]],
                          dict(os.environ, TEST_SCOPE="performance", TEST_OPTIMIZE="1",
                               LEMMINGS_PERFORMANCE_OUTPUT=str(base / "performance.json"))))
        checks.append(run("sequel-views", [["zsh", "Scripts/run-sequel-mac-artwork-tests.sh"]]))
        checks.append(run("arcade-records", [["zsh", "Scripts/run-arcade-records-tests.sh"]]))
    else:
        checks.append(dict(name="replay-movies", status="not-run", reason="Use --app."))
        checks.append(dict(name="mac-app-integration", status="not-run", reason="Use --app. Separate app evidence must match the final source."))
        checks.append(dict(name="local-performance-measurement", status="not-run", reason="Use --app. Short local measurements do not certify sustained throughput or hardware."))
        checks.append(dict(name="sequel-views", status="not-run", reason="Use --app."))
        checks.append(dict(name="arcade-records", status="not-run", reason="Use --app."))
    after = manifest(input_paths(app))
    drift = sorted(key for key in set(before) | set(after) if before.get(key) != after.get(key))
    all_gates = json.loads((ROOT / "Documentation/ReleaseReadiness/gates.json").read_text())
    gates = scoped_gates(all_gates, args.scope)
    sdk = subprocess.run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], capture_output=True, text=True)
    report = dict(schemaVersion=1, generatedAt=datetime.now(timezone.utc).isoformat(),
                  host=platform.platform(), compilerTarget=compiler_target, inputManifest="inputs.json", sourceDrift=drift,
                  checks=checks, gates=gates, releaseScope=args.scope,
                  deferredGates=[gate for gate in all_gates if gate not in gates],
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
