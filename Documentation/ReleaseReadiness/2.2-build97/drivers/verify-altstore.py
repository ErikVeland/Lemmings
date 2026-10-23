#!/usr/bin/env python3
"""Check the 2.2 AltStore source against its unchanged, signed release IPA."""

import argparse
import hashlib
import json
import plistlib
import struct
import subprocess
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path


def check(condition, message):
    if not condition:
        raise ValueError(message)


def run(*args, data=None):
    return subprocess.run(args, input=data, capture_output=True, check=True).stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--source", type=Path, default=Path("altstore.json"))
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = json.loads(args.source.read_text())
    app = source["apps"][0]
    version = app["versions"][0]
    receipt = {
        "sourceCommit": "a9c154af8380a9371d73e66bbd6830ddfc5f6081",
        "channel": "AltStore Classic",
        "sourceURL": "https://raw.githubusercontent.com/ErikVeland/Lemmings/main/altstore.json",
        "sourceSHA256": hashlib.sha256(args.source.read_bytes()).hexdigest(),
        "ipaURL": version["downloadURL"],
        "ipaBytes": args.ipa.stat().st_size,
        "ipaSHA256": hashlib.file_digest(args.ipa.open("rb"), "sha256").hexdigest(),
        "bundles": [],
    }
    check(receipt["ipaSHA256"] == "516ecbf97362a2ac5e282ae08646bfca3b29591589b383caa622f006385c9cf9",
          "IPA differs from the validated frozen 2.2 export")
    check(receipt["ipaBytes"] == version["size"], "IPA size differs from source")
    check(source["featuredApps"] == [app["bundleIdentifier"]], "Featured app mismatch")
    check(len(source["apps"]) == 1, "Unexpected app count")
    with zipfile.ZipFile(args.ipa) as archive:
        check(archive.testzip() is None, "IPA CRC failure")
    receipt["zipCRC"] = "passed"

    permissions = set()
    privacy = {}
    with tempfile.TemporaryDirectory(prefix="lemmings-altstore-") as temporary:
        run("ditto", "-x", "-k", str(args.ipa.resolve()), temporary)
        applications = list((Path(temporary) / "Payload").glob("*.app"))
        check(len(applications) == 1, "Expected one main app")
        main_app = applications[0]
        bundles = [main_app, *sorted(main_app.glob("PlugIns/*.appex"))]
        check(len(bundles) == 2, "Expected the app and Desk Clock widget")
        for bundle in bundles:
            info = plistlib.loads((bundle / "Info.plist").read_bytes())
            run("codesign", "--verify", "--deep", "--strict", str(bundle))
            entitlements = plistlib.loads(run(
                "derq", "query", "-x", data=run(
                    "codesign", "-d", "--entitlements", "-", "--der", str(bundle))))
            permissions.update(entitlements)
            for key, value in info.items():
                if key.endswith("UsageDescription"):
                    check(key not in privacy or privacy[key] == value,
                          f"Conflicting privacy description: {key}")
                    privacy[key] = value
            check(info["CFBundleShortVersionString"] == version["version"] == "2.2",
                  "Version mismatch")
            check(info["CFBundleVersion"] == version["buildVersion"] == "20",
                  "Build mismatch")
            check(info["MinimumOSVersion"] == version["minOSVersion"] == "16.0",
                  "Minimum OS mismatch")
            check(info["UIDeviceFamily"] == [1, 2], "Device family mismatch")
            identifier = info["CFBundleIdentifier"]
            expected = app["bundleIdentifier"]
            if bundle != main_app:
                expected += ".DeskClockWidget"
            check(identifier == expected, "Bundle identifier mismatch")
            executable = (bundle / info["CFBundleExecutable"]).read_bytes()
            magic, cpu, _, _, commands, command_bytes, _, _ = struct.unpack_from("<8I", executable)
            check(magic == 0xFEEDFACF and cpu == 0x100000C, "Expected arm64 Mach-O")
            offset = 32
            encryption = []
            for _ in range(commands):
                command, size = struct.unpack_from("<2I", executable, offset)
                check(size >= 8 and offset + size <= 32 + command_bytes,
                      "Invalid Mach-O command")
                if command in (0x21, 0x2C):
                    cryptid = struct.unpack_from("<I", executable, offset + 16)[0]
                    check(cryptid == 0, "Encrypted executable cannot be sideloaded")
                    encryption.append(cryptid)
                offset += size
            check(encryption == [0], "Expected one unencrypted encryption record")
            receipt["bundles"].append({
                "bundleIdentifier": identifier,
                "version": info["CFBundleShortVersionString"],
                "build": info["CFBundleVersion"],
                "minimumOS": info["MinimumOSVersion"],
                "deviceFamily": info["UIDeviceFamily"],
                "cryptids": encryption,
                "signature": "verified",
                "entitlements": entitlements,
            })
    check(set(app["appPermissions"]["entitlements"]) == permissions,
          "Source entitlements differ from the app/extension union")
    check(app["appPermissions"]["privacy"] == privacy,
          "Source privacy descriptions differ from the app/extension union")
    receipt["permissionsMatchIPA"] = True
    receipt["privacy"] = privacy
    receipt["deviceInstallation"] = "not run"
    receipt["iCloudAndGameCenterAfterResigning"] = "not verified"
    receipt["verifiedUTC"] = datetime.now(timezone.utc).isoformat()
    args.output.write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"Verified 2.2 (20): {receipt['ipaBytes']} bytes, both signatures, permissions and cryptid=0")


if __name__ == "__main__":
    main()
