#!/usr/bin/env python3
"""Sign, inspect and archive the complete Ultimate Lemmix Mac Store application."""

import argparse
import base64
import datetime
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile

from mac_sources import SHARED_MODULES, describe

ROOT = Path(__file__).resolve().parents[2]
MODULES = ("NxlvKit", *SHARED_MODULES)
WIDGET = Path("Contents/PlugIns/DeskClockMacWidget.appex")


def run(*command):
    """Run a required packaging command and return its standard output."""
    return subprocess.check_output([str(value) for value in command])


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def validate_output(args):
    if args.adhoc and args.automatic_export:
        raise ValueError("Choose either ad-hoc signing or automatic Store export.")
    raw = args.build_dir.absolute()
    if any(path.is_symlink() for path in (raw, *raw.parents)):
        raise ValueError("The build directory must not contain symbolic links.")
    output = raw.resolve()
    if (output == ROOT or output in ROOT.parents or output == Path.home()
            or len(output.parts) < 4 or output.name.endswith(".app")):
        raise ValueError("Choose a dedicated generated build directory.")
    if ROOT in output.parents and ROOT / ".build" not in output.parents:
        raise ValueError("Use the checkout's .build folder or a separate external build directory.")
    if any("personal-preview" in part.lower() or "manual-review" in part.lower() for part in output.parts):
        raise ValueError("Do not use a personal preview directory for Store output.")
    if not args.architectures or len(set(args.architectures)) != len(args.architectures):
        raise ValueError("Choose each requested architecture exactly once.")
    if not args.adhoc and set(args.architectures) != {"arm64", "x86_64"}:
        raise ValueError("Store packages require arm64 and x86_64.")
    output.mkdir(parents=True, exist_ok=True)
    marker = output / "mac-store-output.json"
    expected = {"product": "ultimate-lemmix", "root": str(ROOT), "schemaVersion": 1}
    if marker.exists():
        if json.loads(marker.read_text()) != expected:
            raise ValueError("The build output belongs to another checkout or product.")
    elif any(output.iterdir()):
        raise ValueError("Choose an empty output directory for the first Store build.")
    else:
        save(marker, expected)
    args.build_dir = output
    args.app = output / "Ultimate Lemmix.app"


def permits(allowed, requested):
    if allowed == "*" and isinstance(requested, (str, list)):
        return True
    if isinstance(requested, list):
        return isinstance(allowed, list) and all(any(permits(item, value) for item in allowed) for value in requested)
    if isinstance(allowed, list):
        return any(permits(value, requested) for value in allowed)
    if isinstance(requested, str) and isinstance(allowed, str):
        return fnmatch.fnmatchcase(requested, allowed)
    return requested == allowed


def profile(path, identifier, base, development=False):
    """Require an unexpired Mac Store profile that permits every restricted entitlement."""
    document = plistlib.loads(run("security", "cms", "-D", "-i", path))
    if document.get("ExpirationDate", datetime.datetime.min) <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
        raise ValueError(f"The provisioning profile expired: {path}")
    if not development and (document.get("ProvisionedDevices") or document.get("ProvisionsAllDevices")):
        raise ValueError("Use a Mac App Store distribution profile without registered devices.")
    if not set(document.get("Platform", [])) & {"OSX", "macOS"}:
        raise ValueError("Use a macOS provisioning profile.")
    allowed = document["Entitlements"]
    team = document["TeamIdentifier"][0]
    prefix = document["ApplicationIdentifierPrefix"][0]
    application_identifier = prefix + "." + identifier
    key = "com.apple.application-identifier"
    if allowed.get(key) != application_identifier:
        raise ValueError(f"The profile must name the exact application identifier: {application_identifier}")
    if not development and (allowed.get("get-task-allow") or allowed.get("com.apple.security.get-task-allow")):
        raise ValueError("The distribution profile must disable debugging.")
    entitlements = dict(base, **{key: application_identifier, "com.apple.developer.team-identifier": team})
    if not development and entitlements.get("com.apple.developer.icloud-services"):
        entitlements["com.apple.developer.icloud-container-environment"] = "Production"
    for name, value in entitlements.items():
        # Sandbox permissions are local. App groups and service permissions need profile approval.
        restricted = name in (key, "com.apple.security.application-groups") or name.startswith("com.apple.developer.")
        if restricted and not permits(allowed.get(name), value):
            raise ValueError(f"The profile does not permit the required entitlement: {name}")
    return document, entitlements


def prepare_signing(args):
    app_info = plistlib.loads((ROOT / "Resources/UltimateLemmix/Info.plist").read_bytes())
    identity = os.environ.get("ULTIMATE_LEMMIX_SIGNING_IDENTITY", "")
    installer = os.environ.get("ULTIMATE_LEMMIX_INSTALLER_IDENTITY", "")
    if args.adhoc:
        if identity not in ("", "-"):
            raise ValueError("Do not combine --adhoc with an Apple signing identity.")
        identity = "-"
    elif args.automatic_export:
        if not identity.startswith("Apple Development:") or not os.environ.get("ULTIMATE_LEMMIX_TEAM_ID"):
            raise ValueError("Set an Apple Development identity and ULTIMATE_LEMMIX_TEAM_ID for automatic export.")
    else:
        if not identity or identity == "-" or not installer:
            raise ValueError("Set both the Mac Store application and installer signing identities, or use --adhoc.")
        if not any(label in identity for label in ("Apple Distribution:", "3rd Party Mac Developer Application:", "Mac App Distribution:")):
            raise ValueError("Select an Apple Distribution or Mac App Distribution application identity by name.")
        if not any(label in installer for label in ("3rd Party Mac Developer Installer:", "Mac Installer Distribution:")):
            raise ValueError("Select a Mac Installer Distribution signing identity by name.")
    state = {"adhoc": args.adhoc, "automaticExport": args.automatic_export, "identity": identity, "installerIdentity": installer, "bundles": {}}
    for name, filename, identifier, variable in (
            ("app", "AppStore.entitlements", app_info["CFBundleIdentifier"], "ULTIMATE_LEMMIX_APP_PROFILE"),
            ("widget", "DeskClockMacWidget.entitlements", app_info["CFBundleIdentifier"] + ".DeskClockWidget", "ULTIMATE_LEMMIX_WIDGET_PROFILE")):
        base = plistlib.loads((ROOT / "Resources/UltimateLemmix" / filename).read_bytes())
        row = {"identifier": identifier, "entitlements": base}
        if args.automatic_export:
            team = os.environ["ULTIMATE_LEMMIX_TEAM_ID"]
            row.update(team=team, entitlements=dict(base, **{
                "com.apple.application-identifier": team + "." + identifier,
                "com.apple.developer.team-identifier": team}))
            if os.environ.get(variable):
                source = Path(os.environ[variable])
                document, entitlements = profile(source, identifier, base, development=True)
                if document["TeamIdentifier"][0] != team:
                    raise ValueError("The development profile uses a different signing team.")
                target = args.build_dir / f"{name}.provisionprofile"
                shutil.copyfile(source, target)
                row.update(profile=str(target), profileSHA256=digest(target), profileUUID=document["UUID"],
                           entitlements=entitlements,
                           certificates=[hashlib.sha256(data).hexdigest() for data in document["DeveloperCertificates"]])
        elif not args.adhoc:
            source = Path(os.environ.get(variable, ""))
            if not source.is_file():
                raise ValueError(f"Set {variable} to the matching Mac Store provisioning profile.")
            document, entitlements = profile(source, identifier, base)
            target = args.build_dir / f"{name}.provisionprofile"
            shutil.copyfile(source, target)
            row.update(profile=str(target), profileSHA256=digest(target), profileUUID=document["UUID"],
                       team=document["TeamIdentifier"][0], entitlements=entitlements,
                       certificates=[hashlib.sha256(data).hexdigest() for data in document["DeveloperCertificates"]])
        (args.build_dir / f"{name}.entitlements").write_bytes(plistlib.dumps(row["entitlements"]))
        state["bundles"][name] = row
    if not args.adhoc and state["bundles"]["app"]["team"] != state["bundles"]["widget"]["team"]:
        raise ValueError("The app and widget profiles must use the same signing team.")
    save(args.build_dir / "mac-store-signing.json", state)


def inputs():
    contract = describe(ROOT, "ultimate-lemmix")
    paths = set(row["path"] for row in contract["sources"])
    paths.update(("Scripts/build-mac-sources.sh", "Scripts/build-shared-modules.sh",
                  "Scripts/build-desk-clock-mac-widget.sh", "Scripts/build-ultimate-lemmix-app-store.sh",
                  "Tools/Publication/mac_sources.py", "Tools/Publication/mac_store.py",
                  "Tools/Publication/publication.py", "Scripts/check-release-history.sh",
                  "Tools/ReleaseReadiness/version_history.py", "Tools/AlternativeAssets/prepare_lemmix_base.py",
                  "Tools/AlternativeAssets/prepare_project_pixel.py", "Tools/AlternativeAssets/prepare_original_font.py",
                  "Tools/AlternativeAssets/store_resources.py", "Tools/AlternativeAssets/feature_resources.py",
                  "Tools/AlternativeAssets/prepare_music.py", "Resources/AlternativeAssets/music-sources.json",
                  "Resources/UltimateLemmix/alternative-resource-source.json",
                  "Resources/UltimateLemmix/AppIcon/UltimateLemmix.png", "Resources/UltimateLemmix/AppIcon/README.md",
                  "Tools/TrolleyVerification/catalogue.py", "Tools/TrolleyVerification/presentation-files.json",
                  "Tools/TrolleyVerification/legacy-presentation-hashes.json",
                  "Apps/DeskClockWidget/DeskClockWidget.swift", "Apps/DeskClockWidget/Mac/Info.plist",
                  "Resources/UltimateLemmix/Info.plist", "Resources/UltimateLemmix/AppStore.entitlements",
                  "Resources/UltimateLemmix/DeskClockMacWidget.entitlements", "Resources/Publishing/ultimate-lemmix.json"))
    return {name: digest(ROOT / name) for name in sorted(paths)}


def signing_state(args):
    state = getattr(args, "signing_override", None) or json.loads((args.build_dir / "mac-store-signing.json").read_text())
    if state["adhoc"] != args.adhoc:
        raise ValueError("The signing record does not match the requested signing mode.")
    for name, row in state["bundles"].items():
        if not getattr(args, "signing_override", None) and plistlib.loads((args.build_dir / f"{name}.entitlements").read_bytes()) != row["entitlements"]:
            raise ValueError("The prepared signing entitlements changed.")
        if "profile" in row and digest(Path(row["profile"])) != row["profileSHA256"]:
            raise ValueError("The prepared provisioning profile changed.")
    return state


def binaries(app):
    return [app / "Contents/MacOS/UltimateLemmix",
            *[app / f"Contents/Frameworks/lib{module}.dylib" for module in MODULES],
            app / WIDGET / "Contents/MacOS/DeskClockMacWidget"]


def sign(args):
    state = signing_state(args)
    flags = ["--force", "--sign", state["identity"], "--options", "0x0"]
    if not args.adhoc:
        flags.append("--timestamp")
    if (args.app / "Contents/Resources/Localization.bundle").exists():
        raise ValueError("Place Mac Store localisation in the main app's resources before signing.")
    for path in binaries(args.app)[1:-1]:
        run("codesign", *flags, path)
    for name, bundle in (("widget", args.app / WIDGET), ("app", args.app)):
        row = state["bundles"][name]
        if "profile" in row:
            shutil.copyfile(row["profile"], bundle / "Contents/embedded.provisionprofile")
        run("codesign", *flags, "--entitlements", args.build_dir / f"{name}.entitlements", bundle)


def audit(args):
    """Check exact files, architectures, signatures, entitlements and frozen sources."""
    state = signing_state(args)
    if json.loads((args.build_dir / "source-inputs.json").read_text()) != inputs():
        raise ValueError("Build sources changed during compilation. Rebuild before archiving.")
    app = args.app
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if info != plistlib.loads((ROOT / "Resources/UltimateLemmix/Info.plist").read_bytes()):
        raise ValueError("The application metadata differs from the selected product identity.")
    widget_info = plistlib.loads((ROOT / "Apps/DeskClockWidget/Mac/Info.plist").read_bytes())
    widget_info.update(CFBundleIdentifier=info["CFBundleIdentifier"] + ".DeskClockWidget",
                       CFBundleExecutable="DeskClockMacWidget", CFBundleName="DeskClockMacWidget",
                       CFBundleShortVersionString=info["CFBundleShortVersionString"], CFBundleVersion=info["CFBundleVersion"],
                       LSMinimumSystemVersion="12.3", DeskClockURLScheme="ultimatelemmix", UltimateLemmixStore=True)
    if plistlib.loads((app / WIDGET / "Contents/Info.plist").read_bytes()) != widget_info:
        raise ValueError("The widget metadata differs from the selected product identity.")
    resource_root = app / "Contents/Resources"
    manifest = json.loads((resource_root / "store-resources-manifest.json").read_text())
    expected_resources = {row["path"]: row["sha256"] for row in manifest["files"]}
    actual_resources = {path.relative_to(resource_root).as_posix(): digest(path)
                        for path in resource_root.rglob("*") if path.is_file() and path.name != "store-resources-manifest.json"}
    if actual_resources != expected_resources:
        raise ValueError("The resource files differ from the verified clean inventory.")
    widget_resources = {name: value for name, value in expected_resources.items()
                        if name.startswith(("Fonts/Lix/", "Fonts/LixInterface/", "AlternativeAssets/Lix/"))
                        or name in ("Licences/Lix-font-LICENSE.txt", "PrivacyInfo.xcprivacy")}
    expected = {"Contents/Info.plist", "Contents/_CodeSignature/CodeResources",
                str(WIDGET / "Contents/Info.plist"), str(WIDGET / "Contents/_CodeSignature/CodeResources"),
                "Contents/Resources/store-resources-manifest.json"}
    expected.update(str(path.relative_to(app)) for path in binaries(app))
    expected.update("Contents/Resources/" + name for name in expected_resources)
    expected.update(str(WIDGET / "Contents/Resources" / name) for name in widget_resources)
    for name, bundle in (("app", Path(".")), ("widget", WIDGET)):
        if "profile" in state["bundles"][name]:
            expected.add(str(bundle / "Contents/embedded.provisionprofile"))
    actual = set()
    for path in app.rglob("*"):
        if path.is_symlink():
            raise ValueError("The Store application contains a symbolic link.")
        if path.is_file():
            actual.add(path.relative_to(app).as_posix())
    if actual != expected:
        raise ValueError(f"The Store bundle inventory differs. Extra: {sorted(actual - expected)}. Missing: {sorted(expected - actual)}")
    for name, value in widget_resources.items():
        if digest(app / WIDGET / "Contents/Resources" / name) != value:
            raise ValueError(f"The widget resource differs from the clean app resource: {name}")
    if (resource_root / "Localization.bundle").exists():
        raise ValueError("The Mac Store app contains a separately packaged localisation bundle.")
    localisation = {"Fonts/TamilPixelFont.json"}
    localisation.update(f"{language}.lproj/{table}" for language in info["CFBundleLocalizations"]
                        for table in ("Interface.strings", "Interface.stringsdict"))
    sealed = plistlib.loads((app / "Contents/_CodeSignature/CodeResources").read_bytes())["files2"]
    for name in sorted(localisation):
        entry = sealed.get(f"Resources/{name}", {})
        if name not in expected_resources or entry.get("hash2", b"").hex() != expected_resources[name]:
            raise ValueError(f"The app signature does not seal the approved localisation resource: {name}")
    cursor = (ROOT / "Sources/LemmingsLocal/GameCursor.swift").read_text()
    payloads = re.findall(r'originalPointerImage\("""(.*?)"""', cursor, re.S)
    if len(payloads) != 2:
        raise ValueError("Review the original cursor audit after its source changed.")
    for binary in binaries(app):
        if set(run("lipo", "-archs", binary).decode().split()) != set(args.architectures):
            raise ValueError(f"The binary has missing or unexpected architectures: {binary.name}")
        data = binary.read_bytes()
        for payload in payloads:
            compact = re.sub(r"\s+", "", payload)
            if compact[:80].encode() in data or base64.b64decode(compact) in data:
                raise ValueError("The Store executable contains original cursor artwork.")
        dependencies = run("otool", "-L", binary).decode()
        if "Sparkle" in dependencies:
            raise ValueError("The Store application must not link Sparkle.")
        for line in dependencies.splitlines():
            if "(compatibility version" not in line:
                continue
            dependency = line.strip().split(" (", 1)[0]
            if not dependency.startswith(("/System/Library/", "/usr/lib/", "@rpath/lib")):
                raise ValueError(f"The binary links an external dependency: {dependency}")
            if dependency.startswith("@rpath/") and dependency.split("/")[-1] not in {f"lib{module}.dylib" for module in MODULES}:
                raise ValueError(f"The binary links an unbundled library: {dependency}")
        run("codesign", "--verify", "--strict", "--all-architectures", binary)
        for architecture in args.architectures:
            result = subprocess.run(["codesign", "-d", "--verbose=4", "--arch", architecture, str(binary)], capture_output=True, text=True, check=True)
            flags = int(re.search(r"flags=0x([0-9a-fA-F]+)", result.stderr).group(1), 16)
            if bool(flags & 2) != args.adhoc:
                raise ValueError("A binary signature does not match the requested signing mode.")
            if not args.adhoc:
                team = re.search(r"^TeamIdentifier=(.*)$", result.stderr, re.M).group(1)
                if team != state["bundles"]["app"]["team"]:
                    raise ValueError("Every binary must use the app's signing team.")
                if state.get("automaticExport"):
                    continue
                if not any(label in result.stderr for label in ("Authority=Apple Distribution:", "Authority=3rd Party Mac Developer Application:", "Authority=Mac App Distribution:")):
                    raise ValueError("The exported app needs a Store distribution signing certificate.")
                with tempfile.TemporaryDirectory(dir=args.build_dir) as temporary:
                    prefix = Path(temporary) / "certificate"
                    run("codesign", "-d", "--arch", architecture, f"--extract-certificates={prefix}", binary)
                    certificate = digest(Path(str(prefix) + "0"))
                    name = "widget" if binary == binaries(app)[-1] else "app"
                    if certificate not in state["bundles"][name]["certificates"]:
                        raise ValueError("A signing certificate is absent from the provisioning profile.")
    for name, bundle in (("app", app), ("widget", app / WIDGET)):
        row = state["bundles"][name]
        for architecture in args.architectures:
            entitlements = plistlib.loads(run("codesign", "-d", "--arch", architecture, "--entitlements", ":-", bundle))
            if entitlements != row["entitlements"]:
                raise ValueError("Signed entitlements differ from the prepared product entitlements.")
        if "profile" in row:
            if digest(bundle / "Contents/embedded.provisionprofile") != row["profileSHA256"]:
                raise ValueError("An embedded provisioning profile changed.")
            profile(bundle / "Contents/embedded.provisionprofile", row["identifier"], row["entitlements"],
                    development=state.get("automaticExport", False))
    run("codesign", "--verify", "--deep", "--strict", "--all-architectures", app)
    blockers = []
    if state.get("automaticExport"):
        blockers.append("The development-signed archive requires successful Mac App Store export.")
    if args.adhoc:
        blockers.append("Ad-hoc signatures cannot be submitted to the Mac App Store.")
    if set(args.architectures) != {"arm64", "x86_64"}:
        blockers.append("Both Mac architectures are required for the release package.")
    if any(row.get("redistributionCleared") is False for row in manifest.get("mediaLicences", [])):
        blockers.append("The resource manifest records unresolved artwork redistribution rights.")
    result = {"schemaVersion": 1, "product": "ultimate-lemmix", "version": info["CFBundleShortVersionString"],
              "build": info["CFBundleVersion"], "architectures": args.architectures, "adHoc": args.adhoc,
              "packageReadyForSubmission": False, "blockers": blockers, "sourceSnapshotVerified": True,
              "resourceManifestSHA256": digest(resource_root / "store-resources-manifest.json"),
              "binaries": {str(path.relative_to(app)): digest(path) for path in binaries(app)},
              "compilerStageRecords": {
                  str(path.relative_to(args.build_dir)): digest(path)
                  for architecture in args.architectures
                  for path in sorted((args.build_dir / architecture / "source-records").glob("*.json"))},
              "sourceFiles": inputs(), "gitHead": run("git", "-C", ROOT, "rev-parse", "HEAD").decode().strip(),
              "gitDirty": bool(run("git", "-C", ROOT, "status", "--porcelain")),
              "skippedChecks": ["Automated test suites and test-running release audits, under the release schedule."],
              "acceptanceLimits": ["No App Store upload, processing or review is established by this package audit."]}
    save(args.build_dir / "build-evidence.json", result)
    print(f"Verified complete {'ad-hoc' if args.adhoc else 'Store-signed'} Mac candidate: {app}")
    return result


def archive(args):
    result = audit(args)
    archive_path = args.build_dir / "Ultimate Lemmix.xcarchive"
    if archive_path.exists():
        raise ValueError("The archive already exists. Preserve it and choose a new output directory.")
    app_info = plistlib.loads((args.app / "Contents/Info.plist").read_bytes())
    applications = archive_path / "Products/Applications"
    applications.mkdir(parents=True)
    run("ditto", args.app, applications / args.app.name)
    info = {"ArchiveVersion": 2, "CreationDate": datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None),
            "Name": "Ultimate Lemmix", "SchemeName": "UltimateLemmix",
            "ApplicationProperties": {"ApplicationPath": "Applications/Ultimate Lemmix.app",
                "CFBundleIdentifier": app_info["CFBundleIdentifier"],
                "CFBundleShortVersionString": app_info["CFBundleShortVersionString"],
                "CFBundleVersion": app_info["CFBundleVersion"], "SigningIdentity": signing_state(args)["identity"]}}
    if not args.adhoc:
        info["ApplicationProperties"]["Team"] = signing_state(args)["bundles"]["app"]["team"]
    (archive_path / "Info.plist").write_bytes(plistlib.dumps(info))
    run("codesign", "--verify", "--deep", "--strict", "--all-architectures", applications / args.app.name)
    result["archive"] = str(archive_path)
    if args.automatic_export:
        save(args.build_dir / "build-evidence.json", result)
        automatic_export(args, archive_path, result)
        return
    if not args.adhoc:
        package = args.build_dir / f"Ultimate-Lemmix-{result['version']}-build{result['build']}-Mac-App-Store.pkg"
        if package.exists():
            raise ValueError("The installer already exists. Preserve it and choose a new output directory.")
        run("productbuild", "--component", applications / args.app.name, "/Applications", "--sign",
            signing_state(args)["installerIdentity"], "--timestamp", package)
        signature = run("pkgutil", "--check-signature", package).decode()
        if signing_state(args)["installerIdentity"] not in signature:
            raise ValueError("The package signature differs from the selected installer identity.")
        expanded = args.build_dir / "PackageInspection"
        run("pkgutil", "--expand-full", package, expanded)
        payloads = list(expanded.rglob("Ultimate Lemmix.app"))
        if len(payloads) != 1:
            raise ValueError("The installer must contain exactly one Ultimate Lemmix application.")
        def inventory(directory):
            return {path.relative_to(directory).as_posix(): digest(path)
                    for path in directory.rglob("*") if path.is_file()}
        if inventory(payloads[0]) != inventory(applications / args.app.name):
            raise ValueError("The installer payload differs from the verified archive.")
        run("codesign", "--verify", "--deep", "--strict", "--all-architectures", payloads[0])
        result.update(package=str(package), packageSHA256=digest(package), packageSignature=signature,
                      packageReadyForSubmission=not result["blockers"])
    save(args.build_dir / "build-evidence.json", result)
    print(f"Archive: {archive_path}")
    if result["blockers"]:
        print("Submission blocked: " + " ".join(result["blockers"]))


def automatic_export(args, archive_path, result):
    """Ask authenticated Xcode to export locally, then inspect the exported package."""
    team = signing_state(args)["bundles"]["app"]["team"]
    options = {"method": "app-store-connect", "destination": "export", "teamID": team,
               "signingStyle": "automatic", "manageAppVersionAndBuildNumber": False,
               "iCloudContainerEnvironment": "Production", "stripSwiftSymbols": False,
               "generateAppStoreInformation": True}
    options_path = args.build_dir / "ExportOptions.plist"
    options_path.write_bytes(plistlib.dumps(options))
    export_path = args.build_dir / "Export"
    log_path = args.build_dir / "export.log"
    command = ["xcodebuild", "-exportArchive", "-archivePath", str(archive_path),
               "-exportOptionsPlist", str(options_path), "-exportPath", str(export_path),
               "-allowProvisioningUpdates"]
    key_path, key_id, issuer_id = (os.environ.get(name) for name in ("ASC_KEY_PATH", "ASC_KEY_ID", "ASC_ISSUER_ID"))
    if any((key_path, key_id, issuer_id)):
        if not all((key_path, key_id, issuer_id)):
            raise ValueError("Set ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID together.")
        command.extend(["-authenticationKeyPath", key_path, "-authenticationKeyID", key_id,
                        "-authenticationKeyIssuerID", issuer_id])
    environment = dict(os.environ, PATH="/usr/bin:/bin:/usr/sbin:/sbin",
                       TMPDIR=str(args.build_dir / "Temporary") + "/")
    (args.build_dir / "Temporary").mkdir(exist_ok=True)
    with log_path.open("w") as log:
        completed = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, env=environment, umask=0o022)
    result.update(exportCommand=command, exportExitCode=completed.returncode, exportLog=str(log_path))
    if completed.returncode:
        result["blockers"].append("Authenticated Xcode export failed. See export.log for the provisioning response.")
        save(args.build_dir / "build-evidence.json", result)
        raise ValueError(f"Automatic Store export failed. Read {log_path}.")
    save(args.build_dir / "build-evidence.json", result)
    store_info_path = export_path / "AppStoreInfo.plist"
    if not store_info_path.is_file():
        raise ValueError("Xcode export did not produce the requested App Store analysis report.")
    store_info = plistlib.loads(store_info_path.read_bytes())
    result.update(appStoreAnalysis=str(store_info_path), appStoreAnalysisErrors=store_info.get("product-errors", []))
    save(args.build_dir / "build-evidence.json", result)
    if store_info.get("product-errors"):
        raise ValueError("The exported package has App Store analysis errors. Read AppStoreInfo.plist.")
    packages = list(export_path.glob("*.pkg"))
    if len(packages) != 1:
        raise ValueError("Xcode export did not produce exactly one Mac Store installer package.")
    package = packages[0]
    signature = run("pkgutil", "--check-signature", package).decode()
    if not any(label in signature for label in ("3rd Party Mac Developer Installer:", "Mac Installer Distribution:")) or f"({team})" not in signature:
        raise ValueError("The exported installer must use the selected team's Mac Store distribution certificate.")
    expanded = args.build_dir / "ExportInspection"
    run("pkgutil", "--expand-full", package, expanded)
    apps = list(expanded.rglob("Ultimate Lemmix.app"))
    if len(apps) != 1:
        raise ValueError("The exported installer does not contain exactly one Ultimate Lemmix application.")
    exported_state = {"adhoc": False, "automaticExport": False, "bundles": {}}
    for name, bundle, filename in (("app", apps[0], "AppStore.entitlements"),
                                   ("widget", apps[0] / WIDGET, "DeskClockMacWidget.entitlements")):
        identifier = plistlib.loads((bundle / "Contents/Info.plist").read_bytes())["CFBundleIdentifier"]
        path = bundle / "Contents/embedded.provisionprofile"
        base = plistlib.loads((ROOT / "Resources/UltimateLemmix" / filename).read_bytes())
        document, expected = profile(path, identifier, base)
        actual = plistlib.loads(run("codesign", "-d", "--entitlements", ":-", bundle))
        if not all(actual.get(key) == value for key, value in expected.items()):
            raise ValueError("Automatic export removed or changed a required product entitlement.")
        for key, value in actual.items():
            if key not in expected and not permits(document["Entitlements"].get(key), value):
                raise ValueError(f"Automatic export added an entitlement absent from its profile: {key}")
        if actual.get("get-task-allow") or actual.get("com.apple.security.get-task-allow"):
            raise ValueError("The exported application must disable debugging.")
        exported_state["bundles"][name] = {"identifier": identifier, "profile": str(path),
            "profileSHA256": digest(path), "profileUUID": document["UUID"], "team": team,
            "entitlements": actual, "certificates": [hashlib.sha256(data).hexdigest() for data in document["DeveloperCertificates"]]}
        if document["TeamIdentifier"][0] != team:
            raise ValueError("The exported profile uses a different signing team.")
    args.app = apps[0]
    args.signing_override = exported_state
    verified = audit(args)
    verified.update(archive=str(archive_path), package=str(package), packageSHA256=digest(package),
                    packageSignature=signature, exportCommand=command, exportExitCode=0, exportLog=str(log_path),
                    packageReadyForSubmission=not verified["blockers"],
                    appStoreAnalysis=str(store_info_path), appStoreAnalysisErrors=[])
    save(args.build_dir / "exported-signing.json", exported_state)
    save(args.build_dir / "build-evidence.json", verified)
    print(f"Verified Mac Store export: {package}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("validate-output", "prepare-signing", "snapshot", "sign", "audit", "archive", "export"))
    parser.add_argument("--build-dir", type=Path, required=True)
    parser.add_argument("--architectures", nargs="+", choices=("arm64", "x86_64"), required=True)
    parser.add_argument("--adhoc", action="store_true")
    parser.add_argument("--automatic-export", action="store_true")
    args = parser.parse_args()
    try:
        validate_output(args)
        if args.action == "snapshot":
            save(args.build_dir / "source-inputs.json", inputs())
        elif args.action == "export":
            if not args.automatic_export:
                raise ValueError("Use --automatic-export to retry authenticated Store export.")
            automatic_export(args, args.build_dir / "Ultimate Lemmix.xcarchive",
                             json.loads((args.build_dir / "build-evidence.json").read_text()))
        elif args.action != "validate-output":
            {"prepare-signing": prepare_signing, "sign": sign, "audit": audit, "archive": archive}[args.action](args)
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        if args.build_dir.is_dir() and (args.build_dir / "mac-store-output.json").exists():
            save(args.build_dir / "mac-store-failure.json", {"action": args.action, "error": str(error)})
        print(f"Mac Store packaging failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
