#!/usr/bin/env python3
"""Build and run a fixed-input, arm64/x86_64 host performance baseline."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import subprocess
import time
from classic_corpus import generate as generate_classic


TOOLS = Path(__file__).resolve().parent


def invoke(command, log, cwd=None, environment=None):
    with log.open("w") as stream:
        stream.write(json.dumps([str(value) for value in command]) + "\n")
        stream.flush()
        subprocess.run([str(value) for value in command], cwd=cwd, env=environment,
                       stdout=stream, stderr=subprocess.STDOUT, check=True)


def prepare_native_runner(source, log):
    # The shared runner can compile universal glue. This baseline needs only
    # its host slice, built from the same frozen placement and mute sources.
    folder = source / ".build/ui-test-runner"
    folder.mkdir(parents=True, exist_ok=True)
    invoke(["xcrun", "clang", "-dynamiclib", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
            "-Wno-unused-parameter", "-arch", platform.machine(), "-mmacosx-version-min=12.3",
            "-framework", "AppKit", "-framework", "AVFoundation",
            source / "Tools/UITestRunner/WindowPlacement.m", source / "Tools/UITestRunner/AudioSilence.m",
            "-o", folder / "WindowPlacement.dylib"], log)


def verify(manifest, root):
    document = json.loads(manifest.read_text())
    expected = hashlib.sha256(json.dumps(document["files"], sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    if expected != document["treeSHA256"]:
        raise ValueError("Manifest aggregate hash differs")
    for record in document["files"]:
        path = root / record["path"]
        data = os.readlink(path).encode() if record.get("kind") == "symlink" else path.read_bytes()
        if hashlib.sha256(data).hexdigest() != record["sha256"]:
            raise ValueError(f"Snapshot changed: {path}")
    return document["treeSHA256"]


def build(source, destination):
    destination.mkdir(parents=True, exist_ok=True)
    modules = destination / "modules"
    modules.mkdir(exist_ok=True)
    developer = Path(subprocess.check_output(["xcode-select", "-p"], text=True).strip())
    frameworks = developer / "Platforms/MacOSX.platform/Developer/Library/Frameworks"
    flags = ["-O", "-swift-version", "6", "-target", f"{platform.machine()}-apple-macos12.3",
             "-module-cache-path", str(destination / "ModuleCache")]
    command = ["xcrun", "swiftc", *flags, "-parse-as-library", "-emit-module", "-emit-library",
               "-module-name", "NxlvKit", "-emit-module-path", modules / "NxlvKit.swiftmodule",
               "-Xlinker", "-install_name", "-Xlinker", "@rpath/libNxlvKit.dylib",
               "-o", destination / "libNxlvKit.dylib",
               *sorted((source / "Sources/NxlvKit").glob("*.swift"))]
    invoke(command, destination / "build-nxlvkit.log")
    invoke(["xcrun", "clang", "-O2", "-arch", platform.machine(), "-mmacosx-version-min=12.3", "-c", TOOLS / "Allocations.c",
            "-o", destination / "Allocations.o"], destination / "build-counter.log")
    shared = [TOOLS / "Scenarios.swift", source / "Tools/Lemmings3Completion/Replay.swift",
              source / "Sources/LemmingsLocal/GameAssetCache.swift",
              source / "Sources/LemmingsAppCore/Collections/ClassicSourceRevision.swift",
              source / "Sources/LemmingsLocal/FanLevelLibrary.swift", destination / "Allocations.o"]
    link = ["-I", str(modules), "-L", str(destination), "-lNxlvKit",
            "-Xlinker", "-rpath", "-Xlinker", str(destination), "-parse-as-library"]
    invoke(["xcrun", "swiftc", *flags, *link, *shared, TOOLS / "Main.swift",
            "-o", destination / "baseline"], destination / "build-baseline.log")
    invoke(["xcrun", "swiftc", *flags, *link, *shared, TOOLS / "CorpusMain.swift",
            "-o", destination / "corpus"], destination / "build-corpus.log")
    bundle = destination / "PerformanceTests.xctest/Contents"
    (bundle / "MacOS").mkdir(parents=True, exist_ok=True)
    with (bundle / "Info.plist").open("wb") as stream:
        plistlib.dump({"CFBundleExecutable": "PerformanceTests", "CFBundleIdentifier": "local.lemmings.performance",
                      "CFBundlePackageType": "BNDL", "CFBundleVersion": "1"}, stream)
    testing_libs = developer / "Platforms/MacOSX.platform/Developer/usr/lib"
    invoke(["xcrun", "swiftc", *flags, *link, "-F", frameworks, "-I", testing_libs,
            "-L", testing_libs, "-lXCTestSwiftSupport", "-framework", "XCTest",
            "-framework", "Metal", "-Xlinker", "-rpath", "-Xlinker", frameworks,
            "-Xlinker", "-rpath", "-Xlinker", testing_libs,
            "-emit-library", "-module-name", "PerformanceTests", *shared, TOOLS / "PerformanceTests.swift",
            "-o", bundle / "MacOS/PerformanceTests"], destination / "build-xctest.log")


def compare(before, after):
    def signatures(path):
        result = {}
        for row in json.loads(path.read_text()):
            name = row["scenario"]["id"]
            if name in result:
                raise ValueError(f"Duplicate case: {name}")
            values = {(sample["stateHash"], sample["ticks"], sample["saved"], sample["width"],
                       sample["height"], sample["population"], sample.get("recordedOutcomeMatches", True))
                      for sample in row["samples"] + [row["allocationSample"]]}
            if len(values) != 1:
                raise ValueError(f"Within-run divergence: {name}")
            identity = tuple(row["scenario"].get(key) for key in ["engine", "level", "replay", "initialHash", "purpose"])
            result[name] = (identity, values.pop())
        if not result:
            raise ValueError("Empty result set")
        return result
    left, right = signatures(before), signatures(after)
    if left != right:
        changed = sorted(key for key in left.keys() | right.keys() if left.get(key) != right.get(key))
        raise ValueError("Outcomes differ: " + ", ".join(changed))
    print(f"IDENTICAL: {len(left)} case hashes, ticks, results and dimensions")


def build_extras(source, destination):
    target = f"{platform.machine()}-apple-macos12.3"
    invoke(["zsh", source / "Scripts/build-shared-modules.sh", destination / "modules", destination,
            target, "-O", "-module-cache-path", destination / "ModuleCache"], destination / "build-shared.log")
    generated = destination / "generated"
    (generated / "audio").mkdir(parents=True, exist_ok=True)
    names = ["MusicRewindBuffer.swift", "MusicFileDeck.swift", "ModuleMusicPlayer.swift", "VinylRamp.swift", "SoundEffectPlayer.swift"]
    audio = generated / "audio/main.swift"
    audio.write_text("\n".join((source / "Sources/LemmingsAudio" / name).read_text() for name in names)
                     + "\n" + (TOOLS / "AudioBench.swift").read_text())
    flags = ["-O", "-swift-version", "6", "-target", target, "-module-cache-path", destination / "ModuleCache",
             "-I", destination / "modules", "-L", destination, "-lNxlvKit", "-Xlinker", "-rpath", "-Xlinker", destination]
    invoke(["xcrun", "swiftc", *flags, audio, "-o", destination / "audio-baseline"], destination / "build-audio.log")
    names = ["GameCursor.swift", "ExplosionHDR.swift", "MacFXPerformance.swift", "LemmingSelectionHDR.swift", "CRTView.swift"]
    crt = generated / "crt.swift"
    crt.write_text("\n".join((source / "Sources/LemmingsLocal" / name).read_text() for name in names)
                   + "\n" + (TOOLS / "CRTBench.swift").read_text())
    invoke(["xcrun", "swiftc", *flags, "-D", "PERFORMANCE_TESTS", "-parse-as-library",
            "-lLemmingsGameArt", "-lLemmingsAppCore", "-lLemmingsMobileCore", "-lLemmingsTVCore",
            crt, "-o", destination / "crt-baseline"], destination / "build-crt.log")
    classic = generated / "classic/main.swift"
    classic.parent.mkdir(exist_ok=True)
    generate_classic(source, classic)
    invoke(["xcrun", "swiftc", *flags, classic, source / "Sources/LemmingsLocal/GameAssetCache.swift",
            source / "Sources/LemmingsAppCore/Collections/ClassicSourceRevision.swift",
            source / "Sources/LemmingsLocal/FanLevelLibrary.swift", "-o", destination / "classic-corpus"],
           destination / "build-classic-corpus.log")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    builder = sub.add_parser("build")
    builder.add_argument("source", type=Path)
    builder.add_argument("build", type=Path)
    extras = sub.add_parser("build-extras")
    extras.add_argument("source", type=Path)
    extras.add_argument("build", type=Path)
    extra_run = sub.add_parser("measure-extras")
    for name in ["source", "assets", "build", "output"]:
        extra_run.add_argument(name, type=Path)
    run = sub.add_parser("measure")
    for name in ["source", "assets", "cases", "build", "output"]:
        run.add_argument(name, type=Path)
    run.add_argument("--repeats", type=int, default=7)
    comparison = sub.add_parser("compare")
    comparison.add_argument("before", type=Path)
    comparison.add_argument("after", type=Path)
    check = sub.add_parser("verify")
    check.add_argument("manifest", type=Path)
    check.add_argument("root", type=Path)
    args = parser.parse_args()
    if args.action == "build":
        build(args.source.resolve(), args.build.resolve())
    elif args.action == "build-extras":
        build_extras(args.source.resolve(), args.build.resolve())
    elif args.action == "measure-extras":
        args.output.mkdir(parents=True, exist_ok=True)
        prepare_native_runner(args.source.resolve(), args.output / "runner-build.log")
        environment = dict(os.environ, LEMMINGS_TEST_AUDIO="muted", LEMMINGS_TEST_WINDOWS="offscreen")
        runner = args.source.resolve() / "Tools/UITestRunner/run.py"
        invoke(["python3", runner, args.build.resolve() / "audio-baseline", args.output.resolve() / "audio.json"],
               args.output / "audio.log", environment=environment)
        invoke(["python3", runner, args.build.resolve() / "crt-baseline", args.output.resolve() / "crt.json", args.assets.resolve()],
               args.output / "crt.log", environment=environment)
    elif args.action == "compare":
        compare(args.before, args.after)
    elif args.action == "verify":
        print(verify(args.manifest, args.root))
    else:
        args.output.mkdir(parents=True, exist_ok=True)
        prepare_native_runner(args.source.resolve(), args.output / "runner-build.log")
        environment = dict(os.environ, LEMMINGS_TEST_AUDIO="muted", LEMMINGS_TEST_WINDOWS="offscreen",
                           BASELINE_SOURCE=str(args.source.resolve()), BASELINE_ASSETS=str(args.assets.resolve()),
                           BASELINE_CASES=str(args.cases.resolve()))
        metadata = {"startedUnix": time.time(), "architecture": platform.machine(),
                    "os": platform.platform(), "loadAverage": os.getloadavg(),
                    "swift": subprocess.check_output(["xcrun", "swiftc", "--version"], text=True),
                    "tools": {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                              for path in TOOLS.iterdir() if path.is_file()}}
        for label, path in [("source", args.source.parent / "source-manifest.json"),
                            ("assets", args.assets.parent / "assets-manifest.json")]:
            if not path.exists():
                raise ValueError(f"Missing fixed-input manifest: {path}")
            metadata[label + "TreeSHA256"] = verify(path, args.source if label == "source" else args.assets)
        metadata["casesSHA256"] = hashlib.sha256(args.cases.read_bytes()).hexdigest()
        metadata["binaries"] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                                for path in [args.build / "baseline", args.build / "libNxlvKit.dylib"]}
        (args.output / "environment.json").write_text(json.dumps(metadata, indent=2) + "\n")
        invoke([args.build.resolve() / "baseline", args.source.resolve(), args.assets.resolve(),
                args.cases.resolve(), args.output.resolve() / "simulation.json", str(args.repeats)],
               args.output / "simulation.log", environment=environment)
        invoke(["python3", args.source.resolve() / "Tools/UITestRunner/run.py", "xcrun", "xctest",
                args.build.resolve() / "PerformanceTests.xctest"], args.output / "xctest.log", environment=environment)


if __name__ == "__main__":
    main()
