#!/usr/bin/env python3
"""Build either publication profile from the same game source and release metadata."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path("Resources/Publishing/editions.json")


def load_manifest(root):
    """Read the canonical publication metadata without changing historical outputs."""
    manifest = json.loads((root / MANIFEST).read_text())
    if manifest.get("schemaVersion") != 1 or not re.fullmatch(r"\d+(?:\.\d+){0,2}", manifest.get("version", "")):
        raise ValueError("The publication manifest has an invalid schema or version.")
    for edition in manifest["editions"].values():
        for profile in edition["platforms"].values():
            if not isinstance(profile["build"], int) or isinstance(profile["build"], bool) or profile["build"] < 1:
                raise ValueError("Publication build numbers must be positive integers.")
    return manifest


def profiles(manifest, platforms=None):
    """Yield the destination-specific counters under one marketing version."""
    for edition_id, edition in manifest["editions"].items():
        for platform, profile in edition["platforms"].items():
            if platforms is None or platform in platforms:
                yield edition_id, platform, profile


def project_objects(path):
    """Use Apple's property-list reader for Xcode's project format."""
    data = subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(path)])
    return json.loads(data)["objects"]


def metadata_errors(root, manifest, platforms=None):
    """Report stale versions or identities before a profile can build."""
    errors = []
    for edition, platform, profile in profiles(manifest, platforms):
        expected = {"MARKETING_VERSION": manifest["version"], "CURRENT_PROJECT_VERSION": str(profile["build"])}
        if platform == "macos":
            path = root / profile["infoPlist"]
            try:
                info = plistlib.loads(path.read_bytes())
                for key, value in [("CFBundleShortVersionString", manifest["version"]),
                                   ("CFBundleVersion", str(profile["build"])),
                                   ("CFBundleIdentifier", profile["bundleIdentifier"])]:
                    if info.get(key) != value:
                        errors.append(f"{profile['infoPlist']}: {key} must be {value}.")
            except (OSError, ValueError) as error:
                errors.append(f"{profile['infoPlist']}: cannot read metadata: {error}")
            continue
        path = root / profile["project"] / "project.pbxproj"
        try:
            objects = project_objects(path)
            for configuration in objects.values():
                if configuration.get("isa") != "XCBuildConfiguration":
                    continue
                settings = configuration.get("buildSettings", {})
                for key, value in expected.items():
                    if key in settings and str(settings[key]) != value:
                        errors.append(f"{profile['project']}: {configuration['name']} {key} must be {value}.")
            targets = [item for item in objects.values()
                       if item.get("isa") == "PBXNativeTarget" and item.get("name") == profile["appTarget"]]
            if len(targets) != 1:
                errors.append(f"{profile['project']}: the configured app target is missing.")
                continue
            configurations = objects[targets[0]["buildConfigurationList"]]["buildConfigurations"]
            for identifier in configurations:
                settings = objects[identifier]["buildSettings"]
                for key, value in {**expected, "PRODUCT_BUNDLE_IDENTIFIER": profile["bundleIdentifier"]}.items():
                    if str(settings.get(key)) != value:
                        errors.append(f"{profile['project']}: app {key} must be {value}.")
        except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
            errors.append(f"{edition}/{platform}: cannot read the project: {error}")
    return errors


def sync_metadata(root, manifest, platforms=None):
    """Materialise release scalars while preserving edition identities and project structure."""
    changed = []
    for _, platform, profile in profiles(manifest, platforms):
        if platform == "macos":
            path = root / profile["infoPlist"]
            info = plistlib.loads(path.read_bytes())
            if (info.get("CFBundleShortVersionString"), info.get("CFBundleVersion")) == (manifest["version"], str(profile["build"])):
                continue
            info["CFBundleShortVersionString"] = manifest["version"]
            info["CFBundleVersion"] = str(profile["build"])
            path.write_bytes(plistlib.dumps(info, sort_keys=False))
        else:
            path = root / profile["project"] / "project.pbxproj"
            original = path.read_text()
            text = re.sub(r"(?m)^(\s*CURRENT_PROJECT_VERSION\s*=\s*)[^;]+;",
                          lambda match: match[1] + str(profile["build"]) + ";", original)
            text = re.sub(r"(?m)^(\s*MARKETING_VERSION\s*=\s*)[^;]+;",
                          lambda match: match[1] + manifest["version"] + ";", text)
            if text == original:
                continue
            path.write_text(text)
        changed.append(str(path.relative_to(root)))
    return changed


def build_command(root, manifest, edition_id, platform, arguments):
    """Select packaging policy without selecting another gameplay implementation."""
    try:
        edition = manifest["editions"][edition_id]
        profile = edition["platforms"][platform]
    except KeyError as error:
        raise ValueError("Choose a configured edition and platform.") from error
    version_arguments = {"MARKETING_VERSION": manifest["version"], "CURRENT_PROJECT_VERSION": str(profile["build"])}
    profile_settings = {"PRODUCT_BUNDLE_IDENTIFIER", "PRODUCT_NAME", "PRODUCT_MODULE_NAME",
                        "INFOPLIST_FILE", "GENERATE_INFOPLIST_FILE", "CODE_SIGN_ENTITLEMENTS",
                        "OTHER_SWIFT_FLAGS", "SWIFT_ACTIVE_COMPILATION_CONDITIONS", "ULTIMATE_LEMMIX_STORE"}
    retained = []
    for argument in arguments:
        if argument.split("=", 1)[0] in ["-project", "-workspace", "-scheme", "-xcconfig"]:
            raise ValueError("Project, scheme and shared configuration come from the publication profile.")
        key, separator, value = argument.partition("=")
        if separator and (key in profile_settings or key.startswith("INFOPLIST_KEY_")):
            raise ValueError(f"{key} comes from the publication profile.")
        if separator and key in version_arguments:
            if value != version_arguments[key]:
                raise ValueError(f"Set {key} in {MANIFEST} before building.")
            continue
        retained.append(argument)
    environment = {
        "DEVELOPER_DIR": os.environ.get("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer"),
        "LEMMINGS_PUBLICATION_EDITION": edition_id,
        "LEMMINGS_PUBLICATION_VERSION": manifest["version"],
        "LEMMINGS_PUBLICATION_BUILD": str(profile["build"]),
        "ULTIMATE_LEMMIX_STORE": "1" if edition["storeArtwork"] else "0",
    }
    if platform == "macos":
        return ["zsh", str(root / profile["buildScript"]), *retained], environment
    command = ["xcodebuild", "-project", str(root / profile["project"]), "-scheme", profile["scheme"]]
    if edition["storeArtwork"]:
        command += ["-xcconfig", str(root / "Apps/UltimateLemmixSupport/Store.xcconfig")]
    command += retained + [key + "=" + value for key, value in version_arguments.items()]
    return command, environment


def source_snapshot(root):
    """Identify shared game and launcher code independently of publication identity."""
    files = []
    for directory in [root / "Sources", root / "Apps/SharedAppleMobile"]:
        if not directory.exists():
            continue
        for path in directory.rglob("*"):
            relative = path.relative_to(root)
            if path.is_file() and path.suffix in [".swift", ".metal", ".strings", ".stringsdict"] and not {"Tests", "UITests"}.intersection(relative.parts):
                files.append({"path": relative.as_posix(), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    files.sort(key=lambda item: item["path"])
    encoded = json.dumps(files, sort_keys=True, separators=(",", ":")).encode()
    return {"sourceFingerprint": hashlib.sha256(encoded).hexdigest(), "sources": files}


def run_build(root, manifest, edition_id, platform, arguments, runner=subprocess.run):
    """Retain a source receipt and reject a build made while shared inputs changed."""
    command, environment = build_command(root, manifest, edition_id, platform, arguments)
    before = source_snapshot(root)
    configuration = json.dumps(manifest, sort_keys=True).encode()
    manifest_path = root / MANIFEST
    configuration = manifest_path.read_bytes() if manifest_path.exists() else configuration
    completed = runner(command, cwd=root, env={**os.environ, **environment})
    after = source_snapshot(root)
    after_configuration = manifest_path.read_bytes() if manifest_path.exists() else configuration
    unchanged = before == after and configuration == after_configuration
    result = completed.returncode if unchanged else 1
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, capture_output=True, text=True)
    record = {
        "schemaVersion": 1, "edition": edition_id, "platform": platform,
        "version": manifest["version"], "build": manifest["editions"][edition_id]["platforms"][platform]["build"],
        "command": command, "environment": environment,
        "sourceCommit": commit.stdout.strip() if commit.returncode == 0 else None,
        "sourceBefore": before, "sourceAfterFingerprint": after["sourceFingerprint"],
        "sharedSourcesUnchanged": before == after,
        "publicationMetadataUnchanged": configuration == after_configuration,
        "publicationManifestSHA256": hashlib.sha256(configuration).hexdigest(),
        "compilerExitCode": completed.returncode, "exitCode": result,
    }
    destination = root / ".build/publications" / edition_id / platform / "last-build.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(record, indent=2) + "\n")
    if not unchanged:
        print("Shared inputs changed during the build. Rebuild before publishing.", file=sys.stderr)
    return result


def check(root, manifest, metadata_only=False):
    """Reject publication drift before compiler or packaging side effects."""
    errors = metadata_errors(root, manifest)
    if not metadata_only:
        from check_sources import check_sources
        errors += check_sources(root, manifest)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print("Run Scripts/build-publication.sh --sync after updating the publication manifest.", file=sys.stderr)
    return not errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    commands = parser.add_subparsers(dest="action", required=True)
    checker = commands.add_parser("check")
    checker.add_argument("--metadata-only", action="store_true")
    commands.add_parser("sync")
    commands.add_parser("list")
    field = commands.add_parser("field")
    field.add_argument("edition")
    field.add_argument("platform", choices=["macos", "ios", "tvos"])
    field.add_argument("field", choices=["version", "build", "name", "bundleIdentifier"])
    for action in ["plan", "build"]:
        command = commands.add_parser(action)
        command.add_argument("edition")
        command.add_argument("platform", choices=["macos", "ios", "tvos"])
        command.add_argument("arguments", nargs=argparse.REMAINDER)
    arguments = parser.parse_args()
    root = arguments.root.resolve()
    try:
        manifest = load_manifest(root)
        if arguments.action == "sync":
            for path in sync_metadata(root, manifest):
                print("Updated " + path)
            return 0 if check(root, manifest, metadata_only=True) else 1
        if arguments.action == "check":
            if not check(root, manifest, arguments.metadata_only):
                return 1
            print("PASS publication identities and release metadata" if arguments.metadata_only
                  else "PASS shared publication sources, identities and release metadata")
            return 0
        if arguments.action == "list":
            print(json.dumps(manifest, indent=2))
            return 0
        if arguments.action == "field":
            edition = manifest["editions"][arguments.edition]
            profile = edition["platforms"][arguments.platform]
            value = manifest["version"] if arguments.field == "version" else edition["name"] if arguments.field == "name" else profile[arguments.field]
            print(value)
            return 0
        command, environment = build_command(root, manifest, arguments.edition, arguments.platform, arguments.arguments)
        if arguments.action == "plan":
            print(json.dumps({"edition": arguments.edition, "platform": arguments.platform,
                              "command": command, "environment": environment}, indent=2))
            return 0
        if not check(root, manifest):
            return 1
        return run_build(root, manifest, arguments.edition, arguments.platform, arguments.arguments)
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
