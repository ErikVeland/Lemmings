#!/usr/bin/env python3
"""Verify a retained development candidate, install it, and confirm its build. Never launch or upload it."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import zipfile

from build import digest, uuids
from content import verify

ROOT = Path(__file__).resolve().parents[2]
IMAZING = Path("/Applications/iMazing.app/Contents/MacOS/iMazing")


def inspect_candidate(candidate, device_id, env):
    record = json.loads((candidate / "evidence.json").read_text())
    if not record.get("exported") or record.get("exportMethod") not in ("debugging", "release-testing"):
        raise ValueError("Choose a verified development or ad hoc candidate.")
    if record.get("status") != "signed archive and IPA exported" or not all(
        record.get(key) for key in ("signed", "archiveSigned", "exportSignatureVerified")
    ):
        raise ValueError("The candidate did not finish verification. Create a new candidate.")
    app = Path(record["installApp"]).resolve()
    ipa = Path(record["ipa"]).resolve()
    if not app.is_relative_to(candidate.resolve()) or not ipa.is_relative_to(candidate.resolve()):
        raise ValueError("Candidate paths must remain inside the retained candidate directory.")
    if digest(ipa) != record["ipaSHA256"]:
        raise ValueError("The IPA has changed since export.")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if (info["CFBundleIdentifier"], info["CFBundleShortVersionString"], info["CFBundleVersion"]) != (
        record["bundleID"], record["version"], str(record["build"])
    ):
        raise ValueError("The install app differs from the candidate metadata.")
    executable = info["CFBundleExecutable"]
    if not executable or Path(executable).name != executable:
        raise ValueError("The install app has an invalid executable path.")
    binary = app / executable
    with zipfile.ZipFile(ipa) as package:
        exported = package.read(f"Payload/{app.name}/{executable}")
    if digest(binary) != hashlib.sha256(exported).hexdigest():
        raise ValueError("The install executable has changed since export.")
    if uuids(binary) != [tuple(item) for item in record["symbolUUIDs"]]:
        raise ValueError("The install executable does not match the retained crash symbols.")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], env=env, check=True)
    profile = plistlib.loads(subprocess.check_output([
        "openssl", "smime", "-verify", "-noverify", "-inform", "DER", "-in", str(app / "embedded.mobileprovision")
    ], env=env, stderr=subprocess.DEVNULL))
    if device_id not in profile.get("ProvisionedDevices", []):
        raise ValueError("The signing profile does not include this device. Register it and export again.")
    if profile["ExpirationDate"].replace(tzinfo=timezone.utc) <= datetime.now(timezone.utc):
        raise ValueError("The signing profile has expired.")
    entitlements = profile["Entitlements"]
    if profile.get("TeamIdentifier") != [record["team"]] or entitlements.get("com.apple.developer.team-identifier") != record["team"]:
        raise ValueError("The signing profile belongs to a different developer team.")
    application_id = entitlements.get("application-identifier", "")
    prefix = record["team"] + "."
    if not application_id.startswith(prefix) or not (
        application_id[len(prefix):] == record["bundleID"] or application_id == prefix + "*"
    ):
        raise ValueError("The signing profile does not cover this bundle ID.")
    verify(app / "BetaGameData")
    if digest(app / "BetaGameData/manifest.json") != record["contentManifestSHA256"]:
        raise ValueError("The installed game content differs from the candidate.")
    return record, app, ipa


def verify_installed_apps(document, bundle_id, version, build):
    apps = document.get("result", {}).get("apps", [])
    matches = [app for app in apps if app.get("bundleIdentifier") == bundle_id]
    if len(matches) != 1:
        raise ValueError("The requested app was not found in the device's installed apps.")
    installed = matches[0]
    if str(installed.get("version")) != version or str(installed.get("bundleVersion")) != str(build):
        raise ValueError("The device reports a different installed version or build.")
    return {"bundleID": bundle_id, "version": version, "build": str(build)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--device-id", required=True, help="The physical device UDID. Device names are ambiguous.")
    parser.add_argument("--backend", choices=["devicectl", "imazing"], default="devicectl")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Fa-f0-9-]{20,40}", args.device_id):
        parser.error("Use a physical device UDID.")
    candidate = args.candidate.resolve()
    env = dict(os.environ, LEMMINGS_TEST_AUDIO="muted")
    env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:" + env.get("PATH", "")
    env.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    delivery = candidate / ("Delivery-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    delivery.mkdir(exist_ok=False)
    result = {"startedUTC": datetime.now(timezone.utc).isoformat(), "backend": args.backend,
              "installed": False, "installationAttempted": False, "appLaunched": False, "uploaded": False}
    try:
        record, app, ipa = inspect_candidate(candidate, args.device_id, env)
        result.update(bundleID=record["bundleID"], version=record["version"], build=record["build"],
                      ipaSHA256=record["ipaSHA256"], contentManifestSHA256=record["contentManifestSHA256"],
                      requestedDeviceIncluded=True, preflightVerified=True)
        if args.backend == "devicectl":
            install = ["xcrun", "devicectl", "device", "install", "app", "--device", args.device_id,
                       "--timeout", "60", "--json-output", str(delivery / "install.json"), str(app)]
            check = ["xcrun", "devicectl", "device", "info", "apps", "--device", args.device_id,
                     "--bundle-id", record["bundleID"], "--timeout", "30", "--json-output", str(delivery / "apps.json")]
        else:
            if not IMAZING.is_file():
                raise ValueError("The requested iMazing installer is not installed.")
            install = [str(IMAZING), "--device-install-custom-package", "--udid", args.device_id,
                       "--item-path", str(ipa), "--package-type", "Developer", "--timeout", "30", "--usb"]
            check = [str(IMAZING), "--device-app-info", "--udid", args.device_id,
                     "--bundle-id", record["bundleID"], "--timeout", "30", "--usb"]
        result["installationAttempted"] = True
        with (delivery / "install.log").open("w") as log:
            subprocess.run(install, env=env, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
        with (delivery / "apps.log").open("w") as log:
            subprocess.run(check, env=env, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=60)
        if args.backend == "devicectl":
            result["installedApp"] = verify_installed_apps(json.loads((delivery / "apps.json").read_text()),
                                                           record["bundleID"], record["version"], record["build"])
            result["installed"] = True
            result["status"] = "installed build verified"
        else:
            # Preserve the vendor's response for review. Do not infer a build from exit status alone.
            result["status"] = "installation command succeeded; review apps.log to verify the installed build"
        print(result["status"], delivery, flush=True)
    except Exception as error:
        result.update(status="blocked", error=str(error))
        raise
    finally:
        result["finishedUTC"] = datetime.now(timezone.utc).isoformat()
        (delivery / "evidence.json").write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
