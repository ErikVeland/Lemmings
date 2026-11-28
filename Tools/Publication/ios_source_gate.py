"""Run unsigned iOS source checks using the product selected by this checkout."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from publication import ROOT, guard_product_branch, load_manifest


def project_for(root):
    edition = json.loads((root / "Product.json").read_text())["product"]
    manifest = load_manifest(root)
    guard_product_branch(root, manifest, edition)
    return edition, manifest["editions"][edition]["platforms"]["ios"]


def prepare_fixture(directory):
    sys.path.insert(0, str(ROOT / "Tools/AlternativeAssets"))
    from prepare_lemmix_base import prepare_about
    from prepare_open_starter import resources

    files = {"Ports/ultimate_lemmix_starter/" + name: data for name, data in resources().items()}
    bundle = ROOT / "Sources/NxlvKit/Resources/Localization.bundle"
    files.update({str(p.relative_to(bundle.parent)): p.read_bytes() for p in bundle.rglob("*") if p.is_file()})
    prepare_about(directory)
    files.update({str(p.relative_to(directory)): p.read_bytes() for p in (directory / "About").glob("*.md")})
    rows = []
    for name, data in sorted(files.items()):
        path = directory / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        rows.append({"path": name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
    manifest = {"schemaVersion": 1, "kind": "ultimate-lemmix-ios-source-fixture", "files": rows}
    (directory / "ultimate-lemmix-mobile-resources.json").write_text(json.dumps(manifest))


def build_command(edition, profile, stage, fixture, device=None, result_bundle=None):
    target = profile["appTarget"]
    command = ["xcodebuild", "-project", profile["project"]]
    if stage == "ui":
        command += ["test", "-scheme", profile["scheme"], "-destination", "platform=iOS Simulator,id=" + device,
                    "-only-testing:" + target + "UITests/MobileCoreIOSSmokeTests", "-resultBundlePath", result_bundle]
    else:
        simulator = stage != "device"
        build_dir = str(ROOT / ".build" / (target + "-" + stage))
        command += ["-quiet", "-target", target + "UITests" if stage == "debug" else target,
                    "-configuration", "Debug" if stage == "debug" else "Release",
                    "-sdk", "iphonesimulator" if simulator else "iphoneos",
                    "-clonedSourcePackagesDirPath", str(ROOT / ".build/ios-packages"),
                    "OBJROOT=" + build_dir + "/obj", "SYMROOT=" + build_dir + "/products", "build"]
        if simulator:
            command.append("ONLY_ACTIVE_ARCH=NO")
    if edition == "ultimate-lemmix":
        command += ["-xcconfig", "Apps/UltimateLemmixSupport/Store.xcconfig",
                    "ULTIMATE_LEMMIX_RESOURCES_DIR=" + str(fixture)]
    return command + ["CODE_SIGNING_ALLOWED=NO", "IOS_SOURCE_GATE_ONLY=1"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["project", "debug", "release", "device", "ui"])
    parser.add_argument("--device")
    parser.add_argument("--result-bundle")
    parser.add_argument("--without-asset-catalogue", action="store_true")
    args = parser.parse_args()
    if args.stage == "ui" and not (args.device and args.result_bundle):
        parser.error("UI tests require a simulator identifier and a result bundle.")
    edition, profile = project_for(ROOT)
    if args.stage == "project":
        print(profile["project"])
        return 0
    with tempfile.TemporaryDirectory(prefix="ios-source-resources-") as path:
        fixture = Path(path)
        if edition == "ultimate-lemmix":
            prepare_fixture(fixture)
        command = build_command(edition, profile, args.stage, fixture, args.device, args.result_bundle)
        if args.without_asset_catalogue:
            command.append("EXCLUDED_SOURCE_FILE_NAMES=Assets.xcassets")
        return subprocess.run(command, cwd=ROOT, env={**os.environ, "LEMMINGS_TEST_AUDIO": "muted"}).returncode


if __name__ == "__main__":
    sys.exit(main())
