#!/usr/bin/env python3
"""Validate the data-independent application update release inputs."""

import argparse
import base64
from pathlib import Path
import plistlib
import re
from urllib.parse import urlparse
from xml.etree import ElementTree


SPARKLE_NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
SPARKLE_VERSION = "2.7.3"
REQUIRED_SCRIPTS = (
    "Scripts/ensure-sparkle.sh",
    "Scripts/generate-appcast.sh",
    "Scripts/publish-github-release.sh",
)


def _https_url(value, name):
    if not isinstance(value, str):
        raise ValueError(f"{name} must be a string.")
    parsed = urlparse(value)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password:
        raise ValueError(f"{name} must be an HTTPS URL without credentials.")


def validate_info_plist(path):
    with Path(path).open("rb") as source:
        info = plistlib.load(source)
    version = info.get("CFBundleShortVersionString")
    build = info.get("CFBundleVersion")
    if not isinstance(version, str) or not re.fullmatch(r"1\.2(?:\.\d+)?", version):
        raise ValueError("Info.plist must identify a 1.2 application.")
    if not isinstance(build, str) or not re.fullmatch(r"\d+", build):
        raise ValueError("Info.plist must contain a numeric build number.")
    _https_url(info.get("SUFeedURL"), "SUFeedURL")
    public_key = info.get("SUPublicEDKey")
    if not isinstance(public_key, str):
        raise ValueError("SUPublicEDKey is missing.")
    try:
        if len(base64.b64decode(public_key, validate=True)) != 32:
            raise ValueError
    except (ValueError, TypeError):
        raise ValueError("SUPublicEDKey must contain a base64 Ed25519 public key.")
    for key in ("SUEnableAutomaticChecks", "SUAutomaticallyUpdate",
                "SUAllowsAutomaticUpdates", "SUVerifyUpdateBeforeExtraction"):
        if info.get(key) is not True:
            raise ValueError(f"{key} must be true.")
    if not isinstance(info.get("SUScheduledCheckInterval"), int) or info["SUScheduledCheckInterval"] < 3600:
        raise ValueError("SUScheduledCheckInterval must be at least one hour.")
    return version, build


def validate_appcast(path, allow_empty=False, expected_release=None):
    root = ElementTree.parse(path).getroot()
    if root.tag != "rss":
        raise ValueError("The appcast root must be rss.")
    channel = root.find("channel")
    if channel is None:
        raise ValueError("The appcast must contain a channel.")
    items = channel.findall("item")
    if not items:
        if allow_empty:
            return 0
        raise ValueError("The release appcast must contain an update item.")
    for item in items:
        enclosure = item.find("enclosure")
        if enclosure is None:
            raise ValueError("Every appcast item must contain an enclosure.")
        _https_url(enclosure.get("url"), "appcast enclosure URL")
        if not enclosure.get(f"{{{SPARKLE_NAMESPACE}}}edSignature"):
            raise ValueError("Every appcast enclosure needs sparkle:edSignature.")
        for attribute in ("version", "shortVersionString"):
            tag = f"{{{SPARKLE_NAMESPACE}}}{attribute}"
            if item.find(tag) is None and not enclosure.get(tag):
                raise ValueError(f"Every appcast item needs sparkle:{attribute}.")
    if expected_release is not None:
        releases = []
        for item in items:
            enclosure = item.find("enclosure")
            values = []
            for attribute in ("shortVersionString", "version"):
                tag = f"{{{SPARKLE_NAMESPACE}}}{attribute}"
                value = item.findtext(tag) or enclosure.get(tag)
                values.append(value)
            if not re.fullmatch(r"\d+", values[1] or ""):
                raise ValueError("Release appcast build numbers must be numeric.")
            releases.append(tuple(values))
        latest = max(releases, key=lambda release: int(release[1]))
        if latest != expected_release:
            raise ValueError(
                f"Newest appcast release {latest} does not match application {expected_release}.")
    return len(items)


def validate_repository(root, allow_empty=False):
    root = Path(root)
    version, build = validate_info_plist(root / "Resources/Info.plist")
    package = (root / "Package.swift").read_text()
    if f'exact: "{SPARKLE_VERSION}"' not in package:
        raise ValueError(f"Package.swift must pin Sparkle {SPARKLE_VERSION}.")
    resolved = root / "Package.resolved"
    if not resolved.is_file() or SPARKLE_VERSION not in resolved.read_text():
        raise ValueError(f"Package.resolved must contain Sparkle {SPARKLE_VERSION}.")
    for relative in REQUIRED_SCRIPTS:
        path = root / relative
        if not path.is_file() or not path.stat().st_mode & 0o111:
            raise ValueError(f"Required release script is not executable: {relative}")
    items = validate_appcast(root / "appcast.xml", allow_empty=allow_empty,
                             expected_release=(version, build))
    return version, build, items


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--allow-empty-appcast", action="store_true")
    args = parser.parse_args()
    version, build, items = validate_repository(args.root, args.allow_empty_appcast)
    print(f"PASS 1.2 update inputs: version {version}, build {build}, appcast items {items}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, ElementTree.ParseError) as error:
        print(f"FAILED: {error}")
        raise SystemExit(1)
