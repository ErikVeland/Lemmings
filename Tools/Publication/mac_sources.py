#!/usr/bin/env python3
"""Compile both Mac editions from one source contract and verified stage records."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
SHARED_MODULES = ("LemmingsMobileCore", "LemmingsGameArt", "LemmingsAudio",
                  "LemmingsAppCore", "LemmingsTVCore")


def digest(path):
    """Return a file content digest."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fingerprint(value):
    """Return a stable digest for structured build inputs."""
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def describe(root, edition):
    """Describe the common source paths without calling the compiler."""
    modules = {}
    for module in ("NxlvKit", *SHARED_MODULES, "LemmingsLocal"):
        modules[module] = [path.relative_to(root).as_posix()
                           for path in sorted((root / "Sources" / module).glob("**/*.swift"))]
        if not modules[module]:
            raise ValueError(f"No sources found for {module}. Restore the source directory before building.")
    sources = [{"path": path, "sha256": digest(root / path)}
               for path in sorted(path for paths in modules.values() for path in paths)]
    return {"edition": edition, "modules": modules, "sources": sources,
            "sourceFingerprint": fingerprint(sources)}


def verified_record(path, inputs):
    """Return a cached record only when its inputs and output hashes match."""
    try:
        record = json.loads(path.read_text())
        if record["inputs"] == inputs and record["outputs"] and all(
                Path(output).is_file() and digest(Path(output)) == expected
                for output, expected in record["outputs"].items()):
            return record
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return None


def build(args):
    """Build core, shared libraries and the frontend with separate cache records."""
    root = args.root.resolve()
    contract = describe(root, args.edition)
    if args.describe:
        print(json.dumps(contract, indent=2))
        return
    if args.build_dir is None or args.target is None:
        raise ValueError("Set --build-dir and --target before compiling.")
    compiler = shutil.which(args.compiler)
    if compiler is None:
        raise ValueError("The Swift compiler is missing. Select an installed Swift toolchain.")
    # Swift selects its driver mode from argv[0]. Keep the swiftc symlink name.
    compiler = os.path.abspath(compiler)
    version = subprocess.check_output([compiler, "--version"], text=True).strip()
    sdk = args.sdk or (Path(os.environ["SDKROOT"]) if os.environ.get("SDKROOT") else None)
    if sdk is None:
        sdk = Path(subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip())
    sdk = sdk.resolve()
    if not sdk.is_dir():
        raise ValueError("The selected SDK directory is missing. Select an installed macOS SDK.")
    sdk_identity = {"path": str(sdk), "modified": sdk.stat().st_mtime_ns,
                    "settings": {name: digest(sdk / name) for name in ("SDKSettings.json", "SDKSettings.plist")
                                 if (sdk / name).is_file()}}
    build_dir = args.build_dir.resolve()
    architecture = args.target.split("-", 1)[0]
    library_dir = build_dir / architecture
    module_dir = library_dir / "modules"
    records = library_dir / "source-records"
    for directory in (module_dir, records, build_dir / "ModuleCache"):
        directory.mkdir(parents=True, exist_ok=True)
    compatibility = ["-runtime-compatibility-version", "none"] if architecture == "x86_64" else []
    flags = [args.optimization, "-sdk", str(sdk), "-module-cache-path", str(build_dir / "ModuleCache")]
    edition_flags = ["-DULTIMATE_LEMMIX_STORE"] if args.edition == "ultimate-lemmix" else []
    environment = dict(os.environ, SWIFTC=compiler)
    for key in ("LEMMINGS_GAME_ART_ONLY", "LEMMINGS_APP_CORE_ONLY", "LEMMINGS_SKIP_GAME_ART_BUILD"):
        environment.pop(key, None)
    common = {"compiler": {"path": compiler, "sha256": digest(Path(compiler)), "version": version},
              "sdk": sdk_identity, "target": args.target, "flags": flags,
              "helper": digest(Path(__file__))}

    def stage(name, modules, outputs, command, dependencies=None, extra=None, require=False):
        """Compile a stage or require an existing record with matching inputs."""
        paths = {path for module in modules for path in contract["modules"][module]}
        inputs = {**common, "sources": [row for row in contract["sources"] if row["path"] in paths],
                  "dependencies": dependencies, "extra": extra}
        record_path = records / f"{name}.json"
        record = verified_record(record_path, inputs)
        if record is not None:
            print(f"Verified cached Mac stage: {name}")
            return record
        if require:
            raise ValueError(f"The {name} compilation is missing or stale. Run a full source build before reusing it.")
        record_path.unlink(missing_ok=True)
        subprocess.run(command, cwd=root, env=environment, check=True)
        missing = [str(path) for path in outputs if not path.is_file()]
        if missing:
            raise ValueError(f"The {name} compiler did not produce its required outputs: {', '.join(missing)}")
        record = {"inputs": inputs, "outputs": {str(path): digest(path) for path in outputs}}
        pending = record_path.with_suffix(".tmp")
        pending.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
        pending.replace(record_path)
        return record

    def module_outputs(modules):
        """List the shared library and module required for each compilation."""
        return [path for module in modules for path in
                (library_dir / f"lib{module}.dylib", module_dir / f"{module}.swiftmodule")]

    core = stage("core", ("NxlvKit",), module_outputs(("NxlvKit",)),
                 [compiler, "-swift-version", "6", *compatibility, *flags, "-target", args.target,
                  "-parse-as-library", "-emit-module", "-emit-library", "-module-name", "NxlvKit",
                  "-emit-module-path", str(module_dir / "NxlvKit.swiftmodule"),
                  "-Xlinker", "-install_name", "-Xlinker", "@rpath/libNxlvKit.dylib", "-Xlinker", "-w",
                  "-o", str(library_dir / "libNxlvKit.dylib"),
                  *[str(root / path) for path in contract["modules"]["NxlvKit"]]],
                 require=args.reuse_core or args.mode in ("finish", "frontend-only"))
    if args.mode == "core-only":
        return
    shared_script = root / "Scripts/build-shared-modules.sh"
    shared = stage("shared", SHARED_MODULES, module_outputs(SHARED_MODULES),
                   ["zsh", str(shared_script), str(module_dir), str(library_dir), args.target,
                    *flags, *edition_flags], dependencies=core,
                   extra={"flags": edition_flags, "script": digest(shared_script)},
                   require=args.mode in ("finish", "frontend-only"))
    executable = "UltimateLemmix" if args.edition == "ultimate-lemmix" else "LemmingsLocal"
    link_flags = []
    sparkle = None
    if args.edition == "ultimate-lemmings":
        if args.sparkle_framework is None:
            raise ValueError("Set --sparkle-framework for the Ultimate Lemmings frontend.")
        framework = args.sparkle_framework.resolve()
        link_flags = ["-F", str(framework.parent), "-framework", "Sparkle"]
        sparkle = {"path": str(framework), "files": {str(path.relative_to(framework)): digest(path)
                   for path in sorted(framework.rglob("*")) if path.is_file()}}
    stage("frontend", ("LemmingsLocal",), [library_dir / executable],
          [compiler, "-swift-version", "6", *compatibility, *flags, *edition_flags,
           "-target", args.target, "-I", str(module_dir), "-L", str(library_dir), "-lNxlvKit",
           *[f"-l{module}" for module in SHARED_MODULES], *link_flags,
           "-framework", "AppKit", "-framework", "AVFoundation", "-framework", "Metal",
           "-framework", "QuartzCore", "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
           "-Xlinker", "-w", "-o", str(library_dir / executable),
           *[str(root / path) for path in contract["modules"]["LemmingsLocal"]]],
          dependencies=shared, extra={"flags": edition_flags, "sparkle": sparkle, "output": executable},
          require=args.mode == "finish")


def main():
    """Read the shared compiler options and report actionable failures."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--edition", choices=("ultimate-lemmings", "ultimate-lemmix"), required=True)
    parser.add_argument("--describe", action="store_true")
    parser.add_argument("--build-dir", type=Path)
    parser.add_argument("--target")
    parser.add_argument("--sdk", type=Path)
    parser.add_argument("--compiler", default="swiftc")
    parser.add_argument("--optimization", default="-O")
    parser.add_argument("--sparkle-framework", type=Path)
    parser.add_argument("--mode", choices=("build", "core-only", "frontend-only", "finish"), default="build")
    parser.add_argument("--reuse-core", action="store_true")
    try:
        build(parser.parse_args())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Mac source build failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
