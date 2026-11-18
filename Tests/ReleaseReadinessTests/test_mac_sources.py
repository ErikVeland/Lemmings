"""Check shared Mac compiler inputs without compiling game code."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "Tools/Publication/mac_sources.py"
MODULES = ("NxlvKit", "LemmingsAppCore", "LemmingsAudio", "LemmingsMobileCore",
           "LemmingsTVCore", "LemmingsGameArt", "LemmingsLocal")


class MacSourcesTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        (self.root / "Scripts").mkdir()
        shutil.copy(ROOT / "Scripts/build-shared-modules.sh", self.root / "Scripts")
        for module in MODULES:
            directory = self.root / "Sources" / module
            directory.mkdir(parents=True)
            (directory / "Initial.swift").write_text("// fixture\n")
        self.sdk = self.root / "SDK"
        self.sdk.mkdir()
        (self.sdk / "SDKSettings.json").write_text('{"Version":"1"}')
        self.compiler = self.root / "swiftc"
        self.compiler.write_text("""#!/usr/bin/env python3
import json, pathlib, sys
if '--version' in sys.argv:
    print('fixture Swift 6')
    raise SystemExit
arguments = sys.argv[1:]
for flag in ('-o', '-emit-module-path'):
    if flag in arguments:
        path = pathlib.Path(arguments[arguments.index(flag) + 1])
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(arguments))
""")
        self.compiler.chmod(0o755)

    def invoke(self, edition="ultimate-lemmix", *arguments):
        return subprocess.run(
            [sys.executable, str(HELPER), "--root", str(self.root), "--edition", edition,
             "--build-dir", str(self.root / edition), "--target", "arm64-apple-macosx12.3",
             "--sdk", str(self.sdk), "--compiler", str(self.compiler), *arguments],
            capture_output=True, text=True, env=dict(os.environ), check=False)

    def build(self, edition="ultimate-lemmix", *arguments):
        result = self.invoke(edition, *arguments)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return self.root / edition / "arm64"

    def test_both_editions_compile_new_sources_from_the_same_contract(self):
        for module in MODULES:
            (self.root / "Sources" / module / "FutureSource.swift").write_text("// new\n")
        manifests = []
        for edition, executable in (("ultimate-lemmings", "LemmingsLocal"),
                                    ("ultimate-lemmix", "UltimateLemmix")):
            result = self.invoke(edition, "--describe")
            self.assertEqual(result.returncode, 0, result.stderr)
            manifests.append(json.loads(result.stdout))
            directory = self.build(edition, "--sparkle-framework", str(self.root / "Sparkle"))
            for module in MODULES:
                output = directory / (executable if module == "LemmingsLocal" else f"lib{module}.dylib")
                self.assertIn(str(self.root / "Sources" / module / "FutureSource.swift"),
                              json.loads(output.read_text()))
        self.assertEqual(manifests[0]["sources"], manifests[1]["sources"])
        self.assertEqual(len(manifests[0]["sources"]), 14)

    def test_cache_reuses_only_verified_artifacts(self):
        directory = self.build()
        output = directory / "libLemmingsGameArt.dylib"
        before = output.stat().st_mtime_ns
        self.build()
        self.assertEqual(before, output.stat().st_mtime_ns)
        output.write_text("unverified replacement")
        self.build()
        self.assertNotEqual(output.read_text(), "unverified replacement")

    def test_both_editions_compile_nested_sources_in_every_module(self):
        for module in MODULES:
            nested = self.root / "Sources" / module / "Feature"
            nested.mkdir()
            (nested / "FutureSource.swift").write_text("// nested feature\n")
        for edition, executable in (("ultimate-lemmings", "LemmingsLocal"),
                                    ("ultimate-lemmix", "UltimateLemmix")):
            result = self.invoke(edition, "--describe")
            self.assertEqual(result.returncode, 0, result.stderr)
            paths = {row["path"] for row in json.loads(result.stdout)["sources"]}
            directory = self.build(edition, "--sparkle-framework", str(self.root / "Sparkle"))
            for module in MODULES:
                relative = f"Sources/{module}/Feature/FutureSource.swift"
                self.assertIn(relative, paths)
                output = directory / (executable if module == "LemmingsLocal" else f"lib{module}.dylib")
                self.assertIn(str(self.root / relative), json.loads(output.read_text()))

    def test_legacy_wrapper_selects_xcode_and_preserves_explicit_toolchains(self):
        shutil.copy(ROOT / "Scripts/build-local-app.sh", self.root / "Scripts")
        tools = self.root / "Tools/Publication"
        tools.mkdir(parents=True)
        (tools / "publication.py").write_text(
            "import json, os\n"
            "print(json.dumps({'developer': os.environ.get('DEVELOPER_DIR'), 'path': os.environ['PATH']}))\n"
            "raise SystemExit(73)\n")
        for override in (None, str(self.root / "CustomXcode/Contents/Developer")):
            with self.subTest(override=override):
                environment = dict(os.environ)
                environment["PATH"] = str(Path(sys.executable).parent) + ":" + environment["PATH"]
                environment.pop("DEVELOPER_DIR", None)
                if override:
                    environment["DEVELOPER_DIR"] = override
                result = subprocess.run(["zsh", str(self.root / "Scripts/build-local-app.sh")],
                                        capture_output=True, text=True, env=environment, check=False)
                self.assertEqual(result.returncode, 73, result.stdout + result.stderr)
                selected = json.loads(result.stdout)
                developer = override or "/Applications/Xcode.app/Contents/Developer"
                self.assertEqual(selected["developer"], developer)
                self.assertEqual(selected["path"].split(":")[0],
                                 developer + "/Toolchains/XcodeDefault.xctoolchain/usr/bin")

    def test_compiler_symlink_preserves_swiftc_driver_mode(self):
        frontend = self.compiler.with_name("swift-frontend")
        self.compiler.rename(frontend)
        frontend.write_text(frontend.read_text().replace(
            "import json, pathlib, sys", "import json, pathlib, sys\n"
            "if pathlib.Path(sys.argv[0]).name != 'swiftc':\n"
            "    raise SystemExit('wrong Swift driver mode')"))
        self.compiler.symlink_to(frontend.name)
        self.build()

    def test_new_shared_source_invalidates_shared_and_frontend(self):
        directory = self.build()
        before = (directory / "UltimateLemmix").stat().st_mtime_ns
        (self.root / "Sources/LemmingsAppCore/FutureSource.swift").write_text("// new\n")
        self.build()
        self.assertIn("FutureSource.swift", (directory / "libLemmingsAppCore.dylib").read_text())
        self.assertNotEqual(before, (directory / "UltimateLemmix").stat().st_mtime_ns)

    def test_inputs_invalidate_cached_compilation(self):
        for change in ("flags", "compiler", "sdk", "target"):
            with self.subTest(change=change):
                directory = self.build()
                before = (directory / "libNxlvKit.dylib").stat().st_mtime_ns
                arguments = []
                if change == "flags":
                    arguments = ["--optimization=-Onone"]
                elif change == "compiler":
                    self.compiler.write_text(self.compiler.read_text() + "\n# changed compiler\n")
                elif change == "sdk":
                    (self.sdk / "SDKSettings.json").write_text('{"Version":"2"}')
                else:
                    arguments = ["--target", "arm64-apple-macosx13.0"]
                self.build("ultimate-lemmix", *arguments)
                self.assertNotEqual(before, (directory / "libNxlvKit.dylib").stat().st_mtime_ns)

    def test_finish_rejects_stale_shared_sources_without_compiling(self):
        directory = self.build()
        output = directory / "UltimateLemmix"
        before = output.stat().st_mtime_ns
        (self.root / "Sources/LemmingsGameArt/Initial.swift").write_text("// changed\n")
        result = self.invoke("ultimate-lemmix", "--mode", "finish", "--reuse-core")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("shared", result.stderr)
        self.assertEqual(before, output.stat().st_mtime_ns)

    def test_reuse_core_rejects_missing_or_changed_core_record(self):
        self.build()
        (self.root / "Sources/NxlvKit/Initial.swift").write_text("// changed\n")
        result = self.invoke("ultimate-lemmix", "--reuse-core")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("core", result.stderr)

    def test_frontend_only_rejects_unverified_shared_markers(self):
        self.build("ultimate-lemmix", "--mode", "core-only")
        (self.root / "ultimate-lemmix/game-art-abi-ready").touch()
        result = self.invoke("ultimate-lemmix", "--mode", "frontend-only", "--reuse-core")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("shared", result.stderr)


if __name__ == "__main__":
    unittest.main()
