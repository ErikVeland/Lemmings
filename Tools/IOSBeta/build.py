#!/usr/bin/env python3
"""Build and inspect an iOS beta archive. Never upload, install or launch it."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import zipfile

from content import digest, stage, verify

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "Apps/UltimateLemmingsIOS/UltimateLemmingsIOS.xcodeproj"


def run(arguments, log=None, env=None):
    print("Running:", arguments[0], flush=True)
    result = subprocess.run(arguments, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT if log else None)
    if result.returncode:
        raise RuntimeError(f"{arguments[0]} failed ({result.returncode}). See the candidate logs.")


def source_manifest():
    files = [ROOT / "Package.swift", ROOT / "Package.resolved", ROOT / "Scripts/run-swift-tests.sh"]
    for relative in ("Sources/NxlvKit", "Sources/LemmingsGameArt", "Sources/LemmingsMobileCore", "Sources/LemmingsMobileUI", "Tools/IOSBeta", "Tools/IOSMenuAudit"):
        files += [p for p in (ROOT / relative).rglob("*") if p.suffix in (".swift", ".py")]
    files += [p for p in (ROOT / "Apps/UltimateLemmingsIOS").rglob("*")
              if p.is_file() and p.suffix in (".swift", ".plist", ".xcprivacy", ".pbxproj", ".xcscheme", ".png", ".json", ".resolved")
              and "xcuserdata" not in p.parts]
    result = {str(p.relative_to(ROOT)): digest(p) for p in sorted(set(files))}
    artwork = Path(os.environ.get("IOS_MAC_ARTWORK_DIR", ROOT / ".build/mac-artwork/export/lemmings"))
    manifest = artwork / "manifest.json"
    if manifest.is_file():
        from artwork import BANKS
        document = json.loads(manifest.read_text())
        selected = {key for key, name in document.get("names", {}).items() if name in BANKS}
        inputs = {manifest}
        for key, frames in document["banks"].items():
            if key in selected:
                for frame in frames:
                    if frame:
                        name = frame["file"]
                        if "/" in name or ".." in name:
                            raise ValueError("Unsafe artwork frame path.")
                        inputs.add(artwork / name)
        result.update({"MacArtworkInput/" + p.name: digest(p) for p in sorted(inputs)})
    return result


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def uuids(path):
    output = subprocess.check_output(["xcrun", "dwarfdump", "--uuid", str(path)], text=True)
    return sorted(re.findall(r"UUID: ([0-9A-F-]+) \(([^)]+)\)", output))


def validate_export(package, output, archive_record, device_id, export_method):
    destination = output / "Install"
    with zipfile.ZipFile(package) as bundle:
        for member in bundle.infolist():
            path = Path(member.filename)
            if path.is_absolute() or ".." in path.parts or (member.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError("The IPA contains an unsafe file path.")
        bundle.extractall(destination)
        for member in bundle.infolist():
            permissions = (member.external_attr >> 16) & 0o777
            if permissions:
                (destination / member.filename).chmod(permissions)
    apps = list((destination / "Payload").glob("*.app"))
    if len(apps) != 1:
        raise ValueError("The IPA does not contain exactly one app.")
    app = apps[0]
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if (info["CFBundleIdentifier"], info["CFBundleVersion"], info["UIDeviceFamily"]) != (archive_record["bundleID"], str(archive_record["build"]), [1, 2]):
        raise ValueError("The exported app metadata differs from the archive.")
    run(["codesign", "--verify", "--deep", "--strict", str(app)])
    if uuids(app / info["CFBundleExecutable"]) != archive_record["symbolUUIDs"]:
        raise ValueError("The exported executable no longer matches its crash symbols.")
    verify(app / "BetaGameData")
    if digest(app / "BetaGameData/manifest.json") != archive_record["contentManifestSHA256"]:
        raise ValueError("The exported game content differs from the archive.")
    profile = plistlib.loads(subprocess.check_output([
        "openssl", "smime", "-verify", "-noverify", "-inform", "DER", "-in", str(app / "embedded.mobileprovision")
    ], stderr=subprocess.DEVNULL))
    included = device_id in profile.get("ProvisionedDevices", []) if device_id else None
    if device_id and export_method != "app-store-connect" and not included:
        raise ValueError("The exported signing profile does not include the requested device.")
    if profile["ExpirationDate"].replace(tzinfo=timezone.utc) <= datetime.now(timezone.utc):
        raise ValueError("The exported signing profile has expired.")
    return {"installApp": str(app), "minimumOS": info["MinimumOSVersion"],
            "exportExecutableSHA256": digest(app / info["CFBundleExecutable"]),
            "requestedDeviceIncluded": included,
            "profileExpiresUTC": profile["ExpirationDate"].isoformat() + "Z",
            "exportSignatureVerified": True}


def validate_archive(archive, build, bundle_id, signed):
    app = archive / "Products/Applications/UltimateLemmingsIOS.app"
    info = plistlib.loads((app / "Info.plist").read_bytes())
    for key, expected in {
        "CFBundleIdentifier": bundle_id, "CFBundleShortVersionString": "2.0",
        "CFBundleVersion": str(build), "CFBundleSupportedPlatforms": ["iPhoneOS"],
        "UIDeviceFamily": [1, 2], "ITSAppUsesNonExemptEncryption": False,
    }.items():
        if info.get(key) != expected:
            raise ValueError(f"Unexpected archived {key}: {info.get(key)!r}")
    if not info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon"):
        raise ValueError("The archive has no compiled app icon.")
    if not (app / "Assets.car").is_file():
        raise ValueError("The archive has no asset catalogue.")
    privacy = plistlib.loads((app / "PrivacyInfo.xcprivacy").read_bytes())
    reasons = {p["NSPrivacyAccessedAPIType"]: set(p["NSPrivacyAccessedAPITypeReasons"])
               for p in privacy["NSPrivacyAccessedAPITypes"]}
    if reasons.get("NSPrivacyAccessedAPICategorySystemBootTime") != {"35F9.1"}:
        raise ValueError("The in-app timer privacy reason is missing.")
    if reasons.get("NSPrivacyAccessedAPICategoryFileTimestamp") != {"C617.1", "3B52.1"}:
        raise ValueError("The local and imported file privacy reasons are missing.")
    if reasons.get("NSPrivacyAccessedAPICategoryUserDefaults") != {"CA92.1"}:
        raise ValueError("The local settings and progress privacy reason is missing.")
    if privacy["NSPrivacyTracking"] or privacy["NSPrivacyCollectedDataTypes"]:
        raise ValueError("Beta privacy declarations changed. Audit them before distribution.")
    content = verify(app / "BetaGameData")
    binary = app / info["CFBundleExecutable"]
    symbols = archive / "dSYMs/UltimateLemmingsIOS.app.dSYM"
    binary_uuids = uuids(binary)
    if not binary_uuids or binary_uuids != uuids(symbols) or {a for _, a in binary_uuids} != {"arm64"}:
        raise ValueError("Device executable and crash symbols do not match.")
    if signed:
        run(["codesign", "--verify", "--deep", "--strict", str(app)])
        if not (app / "embedded.mobileprovision").is_file():
            raise ValueError("The signed device archive has no provisioning profile.")
    return {
        "app": str(app), "bundleID": bundle_id, "version": "2.0", "build": build,
        "executableSHA256": digest(binary), "symbolUUIDs": binary_uuids,
        "contentManifestSHA256": digest(app / "BetaGameData/manifest.json"),
        "contentFiles": len(content["files"]), "archiveSigned": signed,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=int, required=True, help="A new App Store Connect build number")
    parser.add_argument("--team", default="54WU29TRTY")
    parser.add_argument("--bundle-id", default="academy.glasscode.lemmings.ios")
    parser.add_argument("--content", type=Path, default=ROOT / "Sources/Ports/lemmings_dos_1991-07-30")
    parser.add_argument("--output", type=Path, help="New candidate directory. Must not already exist.")
    parser.add_argument("--unsigned", action="store_true", help="Inspect a device archive without signing or exporting")
    parser.add_argument("--export", choices=["debugging", "release-testing", "app-store-connect"], default="debugging")
    parser.add_argument("--allow-provisioning-updates", action="store_true", help="Let Xcode use its signed-in account to create/download signing assets")
    device = parser.add_mutually_exclusive_group()
    device.add_argument("--device-id", help="Connected device UDID to register and include in the development profile")
    device.add_argument("--registered-device-id", help="Already registered device UDID to verify after a generic device archive")
    args = parser.parse_args()
    requested_device = args.device_id or args.registered_device_id
    if args.build < 1 or not re.fullmatch(r"[A-Z0-9]{10}", args.team):
        parser.error("Use a positive build number and a ten-character team ID.")
    if requested_device and (not re.fullmatch(r"[A-Fa-f0-9-]{20,40}", requested_device)
                           or args.unsigned or not args.allow_provisioning_updates):
        parser.error("Device signing requires a valid UDID, signing and --allow-provisioning-updates.")
    if requested_device and args.export == "app-store-connect":
        parser.error("Device profile checks require a development or ad hoc export.")
    output = (args.output or ROOT / f".build/ios-beta/2.0-{args.build}").resolve()
    output.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, LEMMINGS_TEST_AUDIO="muted")
    # Apple's rsync must also resolve itself for Xcode's symbol-copy subprocess.
    env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:" + env.get("PATH", "")
    stable_xcode = Path("/Applications/Xcode.app/Contents/Developer")
    if "DEVELOPER_DIR" not in env and stable_xcode.is_dir():
        env["DEVELOPER_DIR"] = str(stable_xcode)
    env["CLANG_MODULE_CACHE_PATH"] = str(output / "module-cache")
    env["SWIFTPM_MODULECACHE_OVERRIDE"] = str(output / "module-cache")
    record = {
        "startedUTC": datetime.now(timezone.utc).isoformat(), "scope": "Classic first device beta",
        "launchScope": ["Classic", "Lemmings 2", "Lemmings 3"],
        "status": "preparing", "signed": False, "exported": False, "uploaded": False,
        "physicalDeviceAcceptance": "pending", "team": args.team, "build": args.build,
        "xcode": subprocess.check_output(["xcodebuild", "-version"], env=env, text=True).strip(),
        "gitCommit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
    }
    try:
        before = source_manifest()
        write_json(output / "source-manifest.json", before)
        stage(args.content, output / "BetaGameData")
        with (output / "content-validation.log").open("w") as log:
            run(["swift", "run", "--disable-sandbox", "LemmingsMobileBetaTool",
                 str(output / "BetaGameData"), str(output / "content-validation.json")], log, env)
        archive = output / "UltimateLemmingsIOS.xcarchive"
        command = ["xcodebuild", "-quiet", "-project", str(PROJECT), "-scheme", "UltimateLemmingsIOS",
                   "-configuration", "Release", "-destination", f"id={args.device_id}" if args.device_id else "generic/platform=iOS",
                   "-archivePath", str(archive), "-derivedDataPath", str(output / "DerivedData"),
                   "-clonedSourcePackagesDirPath", str(ROOT / ".build/ios-packages"),
                   f"CURRENT_PROJECT_VERSION={args.build}", "MARKETING_VERSION=2.0",
                   f"PRODUCT_BUNDLE_IDENTIFIER={args.bundle_id}", f"DEVELOPMENT_TEAM={args.team}",
                   f"IOS_BETA_CONTENT_DIR={output / 'BetaGameData'}", "COMPILER_INDEX_STORE_ENABLE=NO"]
        if args.unsigned:
            command.append("CODE_SIGNING_ALLOWED=NO")
        if args.allow_provisioning_updates and not args.unsigned:
            command.append("-allowProvisioningUpdates")
            if args.device_id:
                command.append("-allowProvisioningDeviceRegistration")
        command.append("archive")
        with (output / "archive.log").open("w") as log:
            run(command, log, env)
        record.update(validate_archive(archive, args.build, args.bundle_id, not args.unsigned))
        record["signed"] = not args.unsigned
        # Publishing always needs an explicit separate action.
        if not args.unsigned:
            options = {
                "method": args.export, "destination": "export", "teamID": args.team,
                "signingStyle": "automatic", "manageAppVersionAndBuildNumber": False,
                "uploadSymbols": True,
            }
            if args.export == "app-store-connect":
                options["testFlightInternalTestingOnly"] = False
            with (output / "ExportOptions.plist").open("wb") as stream:
                plistlib.dump(options, stream)
            command = ["xcodebuild", "-exportArchive", "-archivePath", str(archive),
                       "-exportPath", str(output / "Export"), "-exportOptionsPlist", str(output / "ExportOptions.plist")]
            if args.allow_provisioning_updates:
                command.append("-allowProvisioningUpdates")
            with (output / "export.log").open("w") as log:
                run(command, log, env)
            packages = list((output / "Export").glob("*.ipa"))
            if len(packages) != 1:
                raise ValueError("The export did not produce exactly one installable IPA.")
            record.update(exported=True, exportMethod=args.export, ipa=str(packages[0]), ipaSHA256=digest(packages[0]))
            record.update(validate_export(packages[0], output, record, requested_device, args.export))
        after = source_manifest()
        if after != before:
            write_json(output / "source-manifest-after.json", after)
            raise ValueError("Mobile source changed during the build. Create a new candidate.")
        record["status"] = "unsigned archive verified" if args.unsigned else "signed archive and IPA exported"
        print(record["status"], output, flush=True)
    except Exception as error:
        record.update(status="blocked", error=str(error))
        print(str(error), file=sys.stderr)
        raise
    finally:
        record["finishedUTC"] = datetime.now(timezone.utc).isoformat()
        write_json(output / "evidence.json", record)


if __name__ == "__main__":
    main()
