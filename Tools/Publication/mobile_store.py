#!/usr/bin/env python3
"""Prepare and verify local Ultimate Lemmix mobile Store exports."""
import argparse
import datetime
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import shutil
import zipfile

from publication import load_manifest

ROOT = Path(__file__).resolve().parents[2]
TEAM = "54WU29TRTY"
GROUP = "group.academy.glasscode.lemmings"
CONTAINER = "iCloud.academy.glasscode.lemmings"
SIGNATURE_FILES = {"CodeResources", "CodeDirectory", "CodeSignature", "CodeRequirements"}
WIDGET_FOLDERS = {"AlternativeAssets", "Fonts", "Licences", "Provenance"}
FORBIDDEN = {"MacArtwork", "AmigaArtwork", "NeoLemmix", "LevelPacks", "BetaGameData"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def run(*args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, capture_output=True, **kwargs)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_plist(path):
    return plistlib.loads(path.read_bytes())


def entitlements(bundle):
    return plistlib.loads(run("/usr/bin/codesign", "-d", "--entitlements", ":-", bundle).stdout)


def signature(bundle):
    run("/usr/bin/codesign", "--verify", "--strict", bundle)
    description = run("/usr/bin/codesign", "-dvv", bundle).stderr.decode()
    return [line.split("=", 1)[1] for line in description.splitlines() if line.startswith("Authority=")]


def resource_signatures(app, required=False):
    generated = set()
    records = []
    for bundle in sorted(app.rglob("*.bundle")):
        info = read_plist(bundle / "Info.plist")
        require(not info.get("CFBundleExecutable"), f"Unexpected executable resource bundle: {bundle}")
        directory = bundle / "_CodeSignature"
        if not directory.exists() and not required:
            continue
        authorities = signature(bundle)
        description = run("/usr/bin/codesign", "-dvv", bundle).stderr.decode()
        require(f"TeamIdentifier={TEAM}" in description, f"Wrong resource signing team: {bundle}")
        for resource in bundle.rglob("*"):
            require(not resource.is_symlink(), f"Resource symlink: {resource}")
            if resource.is_file():
                with resource.open("rb") as stream:
                    magic = stream.read(4)
                require(magic not in {bytes.fromhex(value) for value in ["feedface", "cefaedfe", "feedfacf", "cffaedfe", "cafebabe", "bebafeca", "cafebabf", "bfbafeca"]},
                        f"Executable content in resource bundle: {resource}")
        require(directory.is_dir() and not directory.is_symlink(), f"Invalid signature directory: {directory}")
        files = list(directory.iterdir())
        require(files and {p.name for p in files} == SIGNATURE_FILES,
                f"Unexpected codeless signature files: {directory}")
        require(all(p.is_file() and not p.is_symlink() for p in files), f"Invalid signature file: {directory}")
        generated.update(p.relative_to(app).as_posix() for p in files)
        records.append({"path": bundle.relative_to(app).as_posix(), "authorities": authorities})
    return generated, records


def verify_resources(app, resources, platform, signatures_required=False):
    manifest = json.loads((resources / "ultimate-lemmix-mobile-resources.json").read_text())
    require(manifest["kind"] == "ultimate-lemmix-full-game-mobile-resources", "Wrong resource manifest kind.")
    rows = manifest["files"]
    for row in rows:
        relative = Path(row["path"])
        require(not relative.is_absolute() and ".." not in relative.parts, "Unsafe resource path.")
        source = resources / relative
        require(source.is_file() and not source.is_symlink(), f"Missing source resource: {relative}")
        require(source.stat().st_size == row["bytes"] and digest(source) == row["sha256"],
                f"Source resource changed: {relative}")
    sys.path.insert(0, str(ROOT / "Tools/AlternativeAssets"))
    from prepare_project_pixel import FONT_PREFIX, verify_packaged_font
    verify_packaged_font({row["path"]: (resources / row["path"]).read_bytes()
                          for row in rows if row["path"].startswith(FONT_PREFIX)})
    generated, signatures = resource_signatures(app, signatures_required)
    result = []
    for bundle in [app, *app.glob("PlugIns/*.appex")]:
        selected = rows if bundle == app else [r for r in rows if Path(r["path"]).parts[0] in WIDGET_FOLDERS] if platform == "ios" else []
        for name in FORBIDDEN:
            require(not (bundle / name).exists(), f"Excluded resource folder: {name}")
        if selected:
            receipt = json.loads((bundle / "ultimate-lemmix-resource-receipt.json").read_text())
            require(receipt["files"] == selected, f"Resource receipt differs: {bundle.name}")
            tracked = {row["path"] for row in selected}
            for row in selected:
                target = bundle / row["path"]
                require(target.is_file() and not target.is_symlink(), f"Missing packaged resource: {target}")
                require(target.stat().st_size == row["bytes"] and digest(target) == row["sha256"],
                        f"Packaged resource changed: {row['path']}")
            managed = {Path(path).parts[0] for path in tracked if "/" in path}
            actual = {p.relative_to(bundle).as_posix() for name in managed for p in (bundle / name).rglob("*") if p.is_file()}
            prefix = "" if bundle == app else bundle.relative_to(app).as_posix() + "/"
            allowed = {path[len(prefix):] for path in generated if path.startswith(prefix)}
            require(actual - allowed == {p for p in tracked if "/" in p},
                    f"Untracked resource files: {sorted(actual - allowed - tracked)}")
        result.append({"bundle": bundle.relative_to(app).as_posix(), "resourceCount": len(selected)})
    return result, signatures


def prepare_archive(args):
    require(not args.output.exists(), "The prepared archive destination must not exist.")
    source_app = next((args.archive / "Products/Applications").glob("*.app"))
    verify_resources(source_app, args.resources, args.platform)
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", source_app)
    before = {bundle.relative_to(source_app).as_posix(): entitlements(bundle)
              for bundle in [*source_app.glob("PlugIns/*.appex"), source_app]}
    require(all(e.get("com.apple.developer.team-identifier") == TEAM for e in before.values()), "Wrong archive team.")
    source_profiles = {p.relative_to(source_app).as_posix(): digest(p)
                       for p in source_app.rglob("embedded.mobileprovision")}
    run("/usr/bin/ditto", args.archive, args.output)
    app = next((args.output / "Products/Applications").glob("*.app"))
    for bundle in sorted(app.rglob("*.bundle"), key=lambda p: len(p.parts), reverse=True):
        run("/usr/bin/codesign", "--force", "--sign", args.identity, "--timestamp=none", bundle)
    for bundle in [*app.glob("PlugIns/*.appex"), app]:
        run("/usr/bin/codesign", "--force", "--sign", args.identity,
            "--preserve-metadata=entitlements,requirements,flags", "--timestamp=none", bundle)
        require(entitlements(bundle) == before[bundle.relative_to(app).as_posix()], "Archive entitlements changed.")
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", app)
    require(all(digest(app / path) == value for path, value in source_profiles.items()), "Archive profile changed.")
    resources, signatures = verify_resources(app, args.resources, args.platform, True)
    record = {"sourceArchive": str(args.archive), "preparedArchive": str(args.output),
              "platform": args.platform, "entitlementsPreserved": True, "originalProfileHashes": source_profiles, "resources": resources,
              "resourceSignatures": signatures, "helperSHA256": digest(Path(__file__))}
    args.output.with_suffix(".preparation.json").write_text(json.dumps(record, indent=2) + "\n")
    print(f"Prepared {args.output}")


def validate_export(args):
    metadata = read_plist(args.output / "AppStoreInfo.plist")
    require(not metadata.get("product-errors"), f"App Store package analysis failed: {metadata.get('product-errors')}")
    ipas = list(args.output.glob("*.ipa"))
    require(len(ipas) == 1, "The export must contain one IPA.")
    ipa = ipas[0]
    inspection = Path(tempfile.mkdtemp(prefix=".inspection-", dir=args.output))
    with zipfile.ZipFile(ipa) as archive:
        require(all(not Path(p).is_absolute() and ".." not in Path(p).parts for p in archive.namelist()), "Unsafe IPA path.")
    run("/usr/bin/ditto", "-x", "-k", ipa, inspection)
    app = next((inspection / "Payload").glob("*.app"))
    product = load_manifest(ROOT)["editions"]["ultimate-lemmix"]
    config = product["platforms"][args.platform]
    expected_ids = {config["bundleIdentifier"], *config["extensionBundleIdentifiers"].values()}
    records = []
    for bundle in [app, *app.glob("PlugIns/*.appex")]:
        info = read_plist(bundle / "Info.plist")
        bid = info["CFBundleIdentifier"]
        require(bid in expected_ids, f"Unexpected bundle ID: {bid}")
        require(info["CFBundleShortVersionString"] == product["version"] and info["CFBundleVersion"] == str(config["build"]), "Wrong bundle version.")
        authorities = signature(bundle)
        require(authorities and authorities[0].startswith("Apple Distribution:") and authorities[0].endswith(f"({TEAM})"), "Wrong distribution signer.")
        ent = entitlements(bundle)
        profile = plistlib.loads(run("/usr/bin/security", "cms", "-D", "-i", bundle / "embedded.mobileprovision").stdout)
        require(ent["application-identifier"] == TEAM + "." + bid, "Wrong application identifier.")
        require(ent["com.apple.developer.team-identifier"] == TEAM, "Wrong signing team.")
        require(not ent.get("get-task-allow") and not profile.get("ProvisionedDevices") and not profile.get("ProvisionsAllDevices"), "Not a Store distribution signature.")
        require(profile["ExpirationDate"] > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None), "Expired profile.")
        require(GROUP in ent["com.apple.security.application-groups"], "Missing shared app group.")
        for key, value in ent.items():
            allowed = profile["Entitlements"].get(key)
            if isinstance(value, list) and isinstance(allowed, list):
                require(all(any(fnmatch.fnmatchcase(v, pattern) for pattern in allowed) for v in value), f"Profile denies {key}.")
            elif key in {"application-identifier", "com.apple.developer.team-identifier", "get-task-allow", "aps-environment", "com.apple.developer.icloud-container-environment"}:
                require(value in allowed if isinstance(allowed, list) else value == allowed, f"Profile denies {key}.")
        require(run("/usr/bin/lipo", "-archs", bundle / info["CFBundleExecutable"]).stdout.decode().strip() == "arm64", "Unexpected mobile architecture.")
        if bundle == app:
            require(ent.get("com.apple.developer.game-center") is True, "Game Center is disabled.")
            require(ent.get("com.apple.developer.icloud-container-environment") == "Production", "CloudKit is not in Production.")
            require("CloudKit" in ent["com.apple.developer.icloud-services"] and CONTAINER in ent["com.apple.developer.icloud-container-identifiers"], "Missing CloudKit service.")
            require(info.get("CloudLibraryCloudKitEnabled") is True, "Cloud library is disabled.")
            if args.platform == "ios":
                require(info.get("LemmingsCloudProgressEnabled") is True and "CloudDocuments" in ent["com.apple.developer.icloud-services"] and CONTAINER in ent["com.apple.developer.ubiquity-container-identifiers"], "iOS cloud progress is incomplete.")
            else:
                require(ent.get("aps-environment") == "production", "tvOS push is not in production.")
            require(json.loads((bundle / "GameCenter/leaderboards.json").read_text())["enabled"] is True, "Game Center resources are disabled.")
        privacy_path = bundle / "PrivacyInfo.xcprivacy"
        privacy = read_plist(privacy_path) if privacy_path.exists() else None
        if privacy:
            expected = read_plist(ROOT / "Apps" / ("UltimateLemmixIOS" if args.platform == "ios" else "UltimateLemmixTVOS") / "PrivacyInfo.xcprivacy")
            require(privacy == expected and privacy.get("NSPrivacyTracking") is False and not privacy.get("NSPrivacyTrackingDomains"), "Wrong privacy manifest.")
        else:
            require(args.platform == "tvos" and bundle != app, "Missing app privacy manifest.")
        records.append({"bundleID": bid, "version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"], "authorities": authorities,
                        "entitlements": ent, "profileUUID": profile["UUID"], "profileName": profile["Name"], "profileExpires": profile["ExpirationDate"].isoformat(), "privacyManifest": privacy})
    require({r["bundleID"] for r in records} == expected_ids, "Missing extension.")
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", app)
    resources, signatures = verify_resources(app, args.resources, args.platform, True)
    result = {"platform": args.platform, "ipa": str(ipa), "sha256": digest(ipa), "bytes": ipa.stat().st_size,
              "checkedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(), "bundles": records,
              "resources": resources, "resourceSignatures": signatures, "appStoreInfoProductErrors": [],
              "helperSHA256": digest(Path(__file__)), "allChecksPassed": True}
    (args.output / "verification.json").write_text(json.dumps(result, indent=2) + "\n")
    shutil.rmtree(inspection)
    print(json.dumps({k: result[k] for k in ["ipa", "sha256", "bytes", "allChecksPassed"]}, indent=2))


def export_archive(args):
    require(not args.output.exists(), "The export destination must not exist.")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.temporary.mkdir(parents=True, exist_ok=True)
    options = args.output.with_suffix(".ExportOptions.plist")
    options.write_bytes(plistlib.dumps({"method": "app-store-connect", "destination": "export", "signingStyle": "automatic", "teamID": TEAM,
        "iCloudContainerEnvironment": "Production", "manageAppVersionAndBuildNumber": False, "uploadSymbols": True,
        "generateAppStoreInformation": True, "stripSwiftSymbols": True}))
    environment = {**os.environ, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "DEVELOPER_DIR": str(args.developer), "TMPDIR": str(args.temporary) + "/"}
    with args.output.with_suffix(".log").open("w") as log:
        completed = subprocess.run(["/usr/bin/xcodebuild", "-exportArchive", "-archivePath", str(args.archive), "-exportPath", str(args.output),
            "-exportOptionsPlist", str(options), "-allowProvisioningUpdates"], env=environment, stdout=log, stderr=subprocess.STDOUT)
    require(completed.returncode == 0, f"Export failed. Read {args.output.with_suffix('.log')}.")
    validate_export(args)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ["prepare-archive", "export", "verify"]:
        sub = commands.add_parser(name)
        sub.add_argument("--platform", choices=["ios", "tvos"], required=True)
        sub.add_argument("--resources", type=Path, required=True)
        sub.add_argument("--output", type=Path, required=True)
        if name != "verify":
            sub.add_argument("--archive", type=Path, required=True)
        if name == "prepare-archive":
            sub.add_argument("--identity", required=True)
        if name == "export":
            sub.add_argument("--temporary", type=Path, required=True)
            sub.add_argument("--developer", type=Path, default=Path("/Applications/Xcode.app/Contents/Developer"))
    args = parser.parse_args()
    try:
        if args.command in {"prepare-archive", "export"}:
            subprocess.run([sys.executable, str(ROOT / "Tools/Localisation/catalogue.py"), "--release"], check=True)
        {"prepare-archive": prepare_archive, "export": export_archive, "verify": validate_export}[args.command](args)
    except (ValueError, subprocess.CalledProcessError, OSError, KeyError, StopIteration) as error:
        print(f"Mobile Store packaging failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
