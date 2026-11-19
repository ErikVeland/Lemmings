#!/usr/bin/env python3
"""Build separate products with shared game source and independent release metadata."""

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
    if manifest.get("schemaVersion") != 2 or "version" in manifest:
        raise ValueError("Use separate product manifests. A shared release version is not permitted.")
    manifest["editions"] = {
        edition: json.loads((root / path).read_text())
        for edition, path in manifest["editions"].items()
    }
    for edition in manifest["editions"].values():
        if not re.fullmatch(r"\d+(?:\.\d+){0,2}", edition.get("version", "")):
            raise ValueError("The product release version is invalid.")
        if not edition.get("releaseBranch", "").startswith("release/"):
            raise ValueError("Each product must have a release branch.")
        for profile in edition["platforms"].values():
            if not isinstance(profile["build"], int) or isinstance(profile["build"], bool) or profile["build"] < 1:
                raise ValueError("Publication build numbers must be positive integers.")
            parent_id = profile["bundleIdentifier"]
            for extension_id in profile.get("extensionBundleIdentifiers", {}).values():
                if not re.fullmatch(re.escape(parent_id) + r"\.[A-Za-z0-9-]+", extension_id):
                    raise ValueError(f"Extension {extension_id} must append one suffix to {parent_id}.")
    branches = [edition["releaseBranch"] for edition in manifest["editions"].values()]
    if len(branches) != len(set(branches)):
        raise ValueError("Products must use separate release branches.")
    return manifest


def profiles(manifest, platforms=None, selected_edition=None):
    """Select a product without changing the other product's release metadata."""
    for edition_id, edition in manifest["editions"].items():
        if selected_edition is not None and edition_id != selected_edition:
            continue
        for platform, profile in edition["platforms"].items():
            if platforms is None or platform in platforms:
                yield edition_id, platform, profile


def project_objects(path):
    """Use Apple's property-list reader for Xcode's project format."""
    data = subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(path)])
    return json.loads(data)["objects"]


def metadata_errors(root, manifest, platforms=None, selected_edition=None):
    """Report stale versions or identities before a profile can build."""
    errors = []
    for edition, platform, profile in profiles(manifest, platforms, selected_edition):
        version = manifest["editions"][edition]["version"]
        expected = {"MARKETING_VERSION": version, "CURRENT_PROJECT_VERSION": str(profile["build"])}
        if platform == "macos":
            path = root / profile["infoPlist"]
            try:
                info = plistlib.loads(path.read_bytes())
                for key, value in [("CFBundleShortVersionString", version),
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
            for name, bundle_id in profile.get("extensionBundleIdentifiers", {}).items():
                extensions = [item for item in objects.values()
                              if item.get("isa") == "PBXNativeTarget" and item.get("name") == name]
                if len(extensions) != 1:
                    errors.append(f"{profile['project']}: extension target {name} is missing.")
                    continue
                for identifier in objects[extensions[0]["buildConfigurationList"]]["buildConfigurations"]:
                    if objects[identifier]["buildSettings"].get("PRODUCT_BUNDLE_IDENTIFIER") != bundle_id:
                        errors.append(f"{profile['project']}: extension {name} must use {bundle_id}.")
        except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
            errors.append(f"{edition}/{platform}: cannot read the project: {error}")
    return errors


def sync_metadata(root, manifest, platforms=None, selected_edition=None):
    """Materialise release scalars while preserving edition identities and project structure."""
    changed = []
    for edition, platform, profile in profiles(manifest, platforms, selected_edition):
        version = manifest["editions"][edition]["version"]
        if platform == "macos":
            path = root / profile["infoPlist"]
            info = plistlib.loads(path.read_bytes())
            if (info.get("CFBundleShortVersionString"), info.get("CFBundleVersion")) == (version, str(profile["build"])):
                continue
            info["CFBundleShortVersionString"] = version
            info["CFBundleVersion"] = str(profile["build"])
            path.write_bytes(plistlib.dumps(info, sort_keys=False))
        else:
            path = root / profile["project"] / "project.pbxproj"
            original = path.read_text()
            text = re.sub(r"(?m)^(\s*CURRENT_PROJECT_VERSION\s*=\s*)[^;]+;",
                          lambda match: match[1] + str(profile["build"]) + ";", original)
            text = re.sub(r"(?m)^(\s*MARKETING_VERSION\s*=\s*)[^;]+;",
                          lambda match: match[1] + version + ";", text)
            if text == original:
                continue
            path.write_text(text)
        changed.append(str(path.relative_to(root)))
    return changed


def guard_product_branch(root, manifest, edition_id, require_release=False, branch=None):
    """Reject the other product on a release branch before a build or upload."""
    required = manifest["editions"][edition_id]["releaseBranch"]
    marker = root / "Product.json"
    if marker.exists() and json.loads(marker.read_text()).get("product") != edition_id:
        raise ValueError(f"This checkout belongs to another product. Use the {edition_id} working folder.")
    if branch is None:
        current = subprocess.run(["git", "symbolic-ref", "--quiet", "--short", "HEAD"],
                                 cwd=root, capture_output=True, text=True)
        branch = current.stdout.strip() if current.returncode == 0 else ""
    owners = {edition["releaseBranch"]: key for key, edition in manifest["editions"].items()}
    if branch in owners and owners[branch] != edition_id:
        raise ValueError(f"{branch} belongs to {owners[branch]}. Use {required} for {edition_id}.")
    if require_release and branch != required:
        raise ValueError(f"Publish {edition_id} only from {required}.")


def publication_inputs(root, manifest, edition_id):
    """Track the selected product's metadata during compilation."""
    path = root / MANIFEST
    if not path.exists():
        return json.dumps(manifest["editions"][edition_id], sort_keys=True).encode()
    index = path.read_bytes()
    product = root / json.loads(index)["editions"][edition_id]
    return index + b"\n" + product.read_bytes()


def compare_shared_sources(root, other_ref):
    """Compare shared inputs across branches without changing either checkout."""
    paths = ["Package.swift", "Sources", "Apps/SharedAppleMobile",
             "Apps/DeskClockWidget", "Tools/Publication/mac_sources.py"]
    commits = [subprocess.check_output(
        ["git", "rev-parse", "--verify", "--end-of-options", ref + "^{commit}"],
        cwd=root, text=True).strip() for ref in ["HEAD", other_ref]]
    changed = subprocess.check_output(["git", "diff", "--name-only", *commits, "--", *paths],
                                      cwd=root, text=True)
    if changed:
        raise ValueError("Shared source differs between the product branches:\n" + changed.rstrip())
    return commits


def build_command(root, manifest, edition_id, platform, arguments):
    """Select packaging policy without selecting another gameplay implementation."""
    try:
        edition = manifest["editions"][edition_id]
        profile = edition["platforms"][platform]
    except KeyError as error:
        raise ValueError("Choose a configured edition and platform.") from error
    guard_product_branch(root, manifest, edition_id)
    version_arguments = {"MARKETING_VERSION": edition["version"], "CURRENT_PROJECT_VERSION": str(profile["build"])}
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
                raise ValueError(f"Set {key} in Resources/Publishing/{edition_id}.json before building.")
            continue
        retained.append(argument)
    environment = {
        "DEVELOPER_DIR": os.environ.get("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer"),
        "LEMMINGS_PUBLICATION_EDITION": edition_id,
        "LEMMINGS_PUBLICATION_VERSION": edition["version"],
        "LEMMINGS_PUBLICATION_BUILD": str(profile["build"]),
        "ULTIMATE_LEMMIX_STORE": "1" if edition["storeArtwork"] else "0",
    }
    if platform == "macos":
        return ["zsh", str(root / profile["buildScript"]), *retained], environment
    command = ["xcodebuild", "-project", str(root / profile["project"]), "-scheme", profile["scheme"]]
    if edition["storeArtwork"]:
        command += ["-xcconfig", str(root / "Apps/UltimateLemmixSupport/Store.xcconfig")]
        supplied = {argument.partition("=")[0] for argument in retained}
        if "ULTIMATE_LEMMIX_RESOURCES_DIR" not in supplied:
            command += ["ULTIMATE_LEMMIX_RESOURCES_DIR=" + str(root / ".build/publication-resources/ultimate-lemmix")]
        if "ULTIMATE_LEMMIX_RELEASE_CHECKS" not in supplied:
            command += ["ULTIMATE_LEMMIX_RELEASE_CHECKS=1"]
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
    configuration = publication_inputs(root, manifest, edition_id)
    completed = runner(command, cwd=root, env={**os.environ, **environment})
    after = source_snapshot(root)
    after_configuration = publication_inputs(root, manifest, edition_id)
    unchanged = before == after and configuration == after_configuration
    result = completed.returncode if unchanged else 1
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, capture_output=True, text=True)
    record = {
        "schemaVersion": 1, "edition": edition_id, "platform": platform,
        "version": manifest["editions"][edition_id]["version"], "build": manifest["editions"][edition_id]["platforms"][platform]["build"],
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


def check(root, manifest, metadata_only=False, selected_edition=None):
    """Reject publication drift before compiler or packaging side effects."""
    errors = metadata_errors(root, manifest, selected_edition=selected_edition)
    if not metadata_only:
        from check_sources import check_sources
        errors += check_sources(root, manifest)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print("Update the product manifest, then run Scripts/build-publication.sh --sync PRODUCT.", file=sys.stderr)
    return not errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    commands = parser.add_subparsers(dest="action", required=True)
    checker = commands.add_parser("check")
    checker.add_argument("--metadata-only", action="store_true")
    checker.add_argument("--edition")
    sync = commands.add_parser("sync")
    sync.add_argument("edition")
    guard = commands.add_parser("guard")
    guard.add_argument("edition")
    guard.add_argument("--release", action="store_true")
    compare = commands.add_parser("compare")
    compare.add_argument("other_ref")
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
        if arguments.action == "guard":
            guard_product_branch(root, manifest, arguments.edition, arguments.release)
            return 0
        if arguments.action == "compare":
            commits = compare_shared_sources(root, arguments.other_ref)
            print("PASS matching shared source: " + " / ".join(commits))
            return 0
        if arguments.action == "sync":
            guard_product_branch(root, manifest, arguments.edition)
            for path in sync_metadata(root, manifest, selected_edition=arguments.edition):
                print("Updated " + path)
            return 0 if check(root, manifest, metadata_only=True, selected_edition=arguments.edition) else 1
        if arguments.action == "check":
            if arguments.edition and arguments.edition not in manifest["editions"]:
                raise ValueError("Choose a configured product.")
            if not check(root, manifest, arguments.metadata_only, arguments.edition):
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
            value = edition["version"] if arguments.field == "version" else edition["name"] if arguments.field == "name" else profile[arguments.field]
            print(value)
            return 0
        command, environment = build_command(root, manifest, arguments.edition, arguments.platform, arguments.arguments)
        if arguments.action == "plan":
            print(json.dumps({"edition": arguments.edition, "platform": arguments.platform,
                              "command": command, "environment": environment}, indent=2))
            return 0
        if not check(root, manifest, selected_edition=arguments.edition):
            return 1
        subprocess.run([sys.executable, str(root / "Tools/ReleaseReadiness/version_history.py"),
                        "--edition", arguments.edition], check=True)
        return run_build(root, manifest, arguments.edition, arguments.platform, arguments.arguments)
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
