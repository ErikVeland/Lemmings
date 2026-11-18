#!/usr/bin/env python3
"""Check that publication variants compile the same maintained source files."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
ORIGINAL_ASSET_TOOLS = (
    "Tools/IOSBeta/content.py", "Tools/IOSBeta/artwork.py", "Tools/IOSBeta/packs.py",
    "Tools/IOSBeta/music.py", "Tools/TVAssets/sounds.py", "Scripts/bundle-game-data.sh",
    "Scripts/prepare-mac-artwork.sh",
)
ENGINE_EDITION_TOKENS = re.compile(
    r"\bULTIMATE_LEMMIX_STORE\b|\bAppDistribution\b|\bMobileResourceAccess\s*\.\s*isStore\b"
)


class ProjectSources:
    """Resolve project source references through their physical group directories."""

    def __init__(self, project):
        result = subprocess.run(["plutil", "-convert", "json", "-o", "-",
                                 str(project / "project.pbxproj")],
                                capture_output=True, text=True, check=False)
        if result.returncode:
            raise ValueError(f"Cannot read the project: {result.stderr.strip() or result.stdout.strip()}")
        data = json.loads(result.stdout)
        self.objects = data["objects"]
        configuration = self.objects[data["rootObject"]]
        self.source_root = (project.parent / configuration.get("projectDirPath", "")).resolve()
        self.main_group = configuration["mainGroup"]
        self.parents = {}
        for identifier, item in self.objects.items():
            for child in item.get("children", []):
                self.parents.setdefault(child, []).append(identifier)

    def path(self, identifier, visited=frozenset()):
        """Resolve source-root, group-relative and absolute references without guessing."""
        if identifier in visited:
            raise ValueError("A source group contains a cycle.")
        item = self.objects[identifier]
        value = item.get("path", "")
        tree = item.get("sourceTree", "<group>")
        if tree in ("SOURCE_ROOT", "PROJECT_DIR"):
            base = self.source_root
        elif tree == "<absolute>":
            if not Path(value).is_absolute():
                raise ValueError("An absolute source reference has a relative path.")
            base = Path("/")
        elif tree == "<group>":
            parents = self.parents.get(identifier, [])
            if identifier == self.main_group:
                base = self.source_root
            elif len(parents) == 1:
                base = self.path(parents[0], visited | {identifier})
            else:
                raise ValueError("A source reference has no unique parent group.")
        else:
            raise ValueError(f"Cannot resolve a source reference with sourceTree {tree}.")
        if "$(" in value or "${" in value:
            raise ValueError("A source reference contains an unresolved build setting.")
        return (base / value).resolve()

    def source_files(self, target):
        """Return every Swift compilation input and reject missing or repeated files."""
        paths = []
        for identifier in target.get("buildPhases", []):
            phase = self.objects[identifier]
            if phase["isa"] != "PBXSourcesBuildPhase":
                continue
            for source in phase.get("files", []):
                reference = self.objects[source]["fileRef"]
                path = self.path(reference)
                if path.suffix != ".swift":
                    continue
                if not path.is_file():
                    raise ValueError(f"A Swift source file is missing: {path}.")
                paths.append(path)
        if len(paths) != len(set(paths)):
            raise ValueError("A target compiles the same Swift source file more than once.")
        return set(paths)


def source_difference(root, actual, expected):
    """Describe the missing and extra source files with useful relative paths."""
    def label(path):
        try:
            return path.relative_to(root).as_posix()
        except ValueError:
            return str(path)
    missing = sorted(label(path) for path in expected - actual)
    extra = sorted(label(path) for path in actual - expected)
    return f"missing {missing}, extra {extra}"


def check_mac_sources(root, manifest):
    """Compare read-only source descriptions from the common Mac build helper."""
    editions = [edition for edition, details in manifest["editions"].items()
                if "macos" in details["platforms"]]
    if not editions:
        return []
    helper = root / manifest["shared"].get("macSourceHelper", "Tools/Publication/mac_sources.py")
    descriptions = []
    errors = []
    for edition in editions:
        result = subprocess.run([sys.executable, "-B", str(helper), "--root", str(root),
                                 "--edition", edition, "--describe"],
                                capture_output=True, text=True, check=False)
        if result.returncode:
            errors.append(f"{edition}/macos: Cannot describe the shared Mac sources: {result.stderr.strip()}.")
            continue
        try:
            description = json.loads(result.stdout)
            if not description["sources"] or not description["sourceFingerprint"]:
                raise ValueError("The Mac source description is empty.")
            descriptions.append((edition, description))
        except (ValueError, KeyError, TypeError) as error:
            errors.append(f"{edition}/macos: Cannot read the Mac source description: {error}.")
    if descriptions:
        first, baseline = descriptions[0]
        for edition, description in descriptions[1:]:
            if any(description[key] != baseline[key] for key in ("sources", "sourceFingerprint")):
                errors.append(f"{edition}/macos: The source files or source fingerprint differ from {first}.")
    return errors


def check_sources(root: Path, manifest: dict) -> list[str]:
    """Return publication source drift without compiling or opening an application."""
    root = root.resolve()
    shared = manifest["shared"]
    expected_package = (root / shared["package"]).resolve()
    errors = []
    for source in sorted((root / "Sources/NxlvKit").rglob("*.swift")):
        try:
            if ENGINE_EDITION_TOKENS.search(source.read_text()):
                errors.append(f"The shared engine contains an edition condition: {source.relative_to(root)}.")
        except OSError as error:
            errors.append(f"Cannot read the shared engine source {source.relative_to(root)}: {error}.")
    for edition, details in manifest["editions"].items():
        for platform, settings in details["platforms"].items():
            if platform not in ("ios", "tvos"):
                continue
            label = f"{edition}/{platform}"
            try:
                project = ProjectSources(root / settings["project"])
                local_packages = {identifier: (project.source_root / item["relativePath"]).resolve()
                                  for identifier, item in project.objects.items()
                                  if item.get("isa") == "XCLocalSwiftPackageReference"}
                if (set(local_packages.values()) != {expected_package.parent}
                        or not expected_package.is_file()):
                    errors.append(f"{label}: The local package root must contain {shared['package']}.")
                for item in project.objects.values():
                    if (item.get("isa") == "XCSwiftPackageProductDependency"
                            and item.get("package") not in local_packages):
                        errors.append(f"{label}: A product dependency does not use the shared local package.")
                guard = {shared["storeBuildGuard"]} if details["storeArtwork"] else set()
                expected = {settings["appTarget"]: set(shared["mobileAppSources"]) | guard}
                if platform == "ios":
                    expected[settings.get("widgetTarget", "DeskClockWidget")] = {shared["widgetSource"]} | guard
                    expected[settings.get("uiTestTarget", settings["appTarget"] + "UITests")] = set(shared["iosTestSources"])
                else:
                    expected[settings.get("topShelfTarget", "TopShelf")] = {shared["topShelfSource"]}
                found = set()
                for target in project.objects.values():
                    if target.get("isa") != "PBXNativeTarget":
                        continue
                    name = target["name"]
                    found.add(name)
                    if name not in expected:
                        errors.append(f"{label}: The target {name} has no shared source contract.")
                        continue
                    actual = project.source_files(target)
                    wanted = {(root / path).resolve() for path in expected[name]}
                    if actual != wanted:
                        errors.append(f"{label}/{name}: The source files differ: {source_difference(root, actual, wanted)}.")
                    if details["storeArtwork"]:
                        for phase_id in target.get("buildPhases", []):
                            phase = project.objects[phase_id]
                            if phase["isa"] == "PBXShellScriptBuildPhase" and any(
                                    tool in phase.get("shellScript", "") for tool in ORIGINAL_ASSET_TOOLS):
                                errors.append(f"{label}/{name}: A build phase prepares original assets in the Store edition.")
                for name in expected.keys() - found:
                    errors.append(f"{label}: The shared source target {name} is missing.")
            except (OSError, ValueError, KeyError, TypeError) as error:
                errors.append(f"{label}: Cannot check the project sources: {error}.")
    errors.extend(check_mac_sources(root, manifest))
    return errors


def main():
    """Read the publication manifest and report source drift."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    source_fingerprint = None
    try:
        manifest = json.loads((args.root / "Resources/Publishing/editions.json").read_text())
        errors = check_sources(args.root, manifest)
        mac_edition = next((edition for edition, details in manifest["editions"].items()
                            if "macos" in details["platforms"]), None)
        if not errors and mac_edition:
            helper = args.root / manifest["shared"].get("macSourceHelper", "Tools/Publication/mac_sources.py")
            description = json.loads(subprocess.check_output(
                [sys.executable, "-B", str(helper), "--root", str(args.root.resolve()),
                 "--edition", mac_edition, "--describe"], text=True))
            source_fingerprint = description["sourceFingerprint"]
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        errors = [f"Cannot check publication sources: {error}."]
    for error in errors:
        print(error, file=sys.stderr)
    if not errors:
        print("PASS shared publication source files and Mac source fingerprints")
        if source_fingerprint:
            print(f"sourceFingerprint: {source_fingerprint}")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
