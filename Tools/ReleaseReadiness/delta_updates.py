#!/usr/bin/env python3
"""Keep the previous shipped archive available and require its signed delta."""

import argparse
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
from urllib.parse import quote, unquote, urlparse, urlsplit, urlunsplit
from xml.etree import ElementTree as ET
import zipfile
from xml.sax.saxutils import escape

from automatic_updates import SPARKLE_NAMESPACE as NS, validate_appcast


def build_of(item):
    enclosure = item.find("enclosure")
    return int(item.findtext(f"{{{NS}}}version") or enclosure.get(f"{{{NS}}}version"))


def previous_item(items, build):
    older = [item for item in items if build_of(item) < build]
    return max(older, key=build_of) if older else None


def archive_build(archive):
    with zipfile.ZipFile(archive) as source:
        names = [name for name in source.namelist()
                 if name.count("/") == 2 and name.endswith(".app/Contents/Info.plist")]
        if len(names) != 1:
            raise ValueError("The update archive must contain one application.")
        return int(plistlib.loads(source.read(names[0]))["CFBundleVersion"])


def prepare_base(root, updates, feed, explicit=None):
    archives = list(updates.glob("*.zip"))
    if not archives:
        raise ValueError("No full update archive is ready.")
    build = max(archive_build(archive) for archive in archives)
    items = ET.parse(feed).getroot().findall("./channel/item") if feed.exists() else []
    previous = previous_item(items, build)
    if previous is None:
        return
    enclosure = previous.find("enclosure")
    name = Path(unquote(urlparse(enclosure.get("url")).path)).name
    candidates = ([explicit] if explicit else
                  [updates / name, root / ".build/updates" / name,
                   *sorted((root / ".build").glob(f"release-*/updates/{name}"))])
    archive = next((path for path in candidates if path and path.is_file()), None)
    if archive is None:
        raise ValueError(f"Missing shipped build {build_of(previous)} archive. "
                         "Set PREVIOUS_UPDATE_ZIP to its full signed ZIP; a delta is required.")
    if archive.name != name or str(archive.stat().st_size) != enclosure.get("length"):
        raise ValueError("The previous archive name or length differs from the published feed.")
    if archive_build(archive) != build_of(previous):
        raise ValueError("The previous archive contains the wrong application build.")
    target = updates / name
    if archive.resolve() != target.resolve():
        # APFS clones avoid copying gigabytes of unchanged soundtrack data.
        result = subprocess.run(["cp", "-c", str(archive), str(target)], capture_output=True)
        if result.returncode:
            shutil.copy2(archive, target)
    print(f"Delta base: shipped build {build_of(previous)} ({name})")


def delta_assets(feed, build, directory):
    validate_appcast(feed)
    items = ET.parse(feed).getroot().findall("./channel/item")
    matches = [item for item in items if build_of(item) == build]
    if len(matches) != 1:
        raise ValueError("The feed needs exactly one entry for the target build.")
    deltas = matches[0].findall(f"{{{NS}}}deltas/enclosure")
    previous = previous_item(items, build)
    if previous is not None and not any(
            delta.get(f"{{{NS}}}deltaFrom") == str(build_of(previous)) for delta in deltas):
        raise ValueError(f"Missing delta from previous shipped build {build_of(previous)}.")
    paths = []
    for delta in deltas:
        name = Path(unquote(urlparse(delta.get("url")).path)).name
        if not name.endswith(".delta") or name in (".delta", "..delta"):
            raise ValueError("Delta enclosure must name a .delta asset.")
        path = directory / name
        if not path.is_file() or path.is_symlink():
            raise ValueError(f"Missing local delta asset: {name}")
        if str(path.stat().st_size) != delta.get("length"):
            raise ValueError(f"Delta asset length differs from the signed feed: {name}")
        paths.append(path)
    return paths


def preserve_published_items(previous, generated, build):
    if not previous.exists() or not previous.stat().st_size:
        return
    old_text = previous.read_text()
    new_text = generated.read_text()
    pattern = re.compile(r"<item\b[^>]*>.*?</item>", re.S)

    def keyed(text):
        root_open = re.search(r"<rss\b[^>]*>", text).group()
        return {build_of(ET.fromstring(f"{root_open}{block}</rss>")[0]): block
                for block in pattern.findall(text)}

    old, new = keyed(old_text), keyed(new_text)
    # Sparkle can rewrite a base archive URL with the new release's prefix.
    # Keep every published base item (including its notes and older deltas).
    for key, block in old.items():
        if key == build:
            continue
        if key in new:
            new_text = new_text.replace(new[key], block, 1)
        else:
            new_text = new_text.replace("</channel>", block + "\n</channel>", 1)
    generated.write_text(new_text)


def normalize_delta_names(feed, build, directory):
    validate_appcast(feed)
    text = feed.read_text()
    tree = ET.fromstring(text)
    item = next(item for item in tree.findall("./channel/item") if build_of(item) == build)
    for delta in item.findall(f"{{{NS}}}deltas/enclosure"):
        url = delta.get("url")
        parts = urlsplit(url)
        old_name = Path(unquote(parts.path)).name
        # GitHub rewrites spaces in asset names. Use a stable portable filename
        # while leaving Sparkle's cached original available for the next run.
        name = f"UltimateLemmings-build{build}-from{delta.get(f'{{{NS}}}deltaFrom')}.delta"
        source, target = directory / old_name, directory / name
        if source != target:
            shutil.copy2(source, target)
        new_url = urlunsplit(parts._replace(path=parts.path.rsplit("/", 1)[0] + "/" + quote(name)))
        text = text.replace(escape(url), escape(new_url))
    feed.write_text(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    prepare = sub.add_parser("prepare")
    prepare.add_argument("root", type=Path)
    prepare.add_argument("updates", type=Path)
    prepare.add_argument("feed", type=Path)
    prepare.add_argument("--previous", type=Path)
    assets = sub.add_parser("assets")
    assets.add_argument("feed", type=Path)
    assets.add_argument("build", type=int)
    assets.add_argument("directory", type=Path)
    preserve = sub.add_parser("preserve")
    preserve.add_argument("previous", type=Path)
    preserve.add_argument("generated", type=Path)
    preserve.add_argument("build", type=int)
    normalize = sub.add_parser("normalize")
    normalize.add_argument("feed", type=Path)
    normalize.add_argument("build", type=int)
    normalize.add_argument("directory", type=Path)
    args = parser.parse_args()
    if args.command == "prepare":
        prepare_base(args.root, args.updates, args.feed, args.previous)
    elif args.command == "preserve":
        preserve_published_items(args.previous, args.generated, args.build)
    elif args.command == "normalize":
        normalize_delta_names(args.feed, args.build, args.directory)
    else:
        for path in delta_assets(args.feed, args.build, args.directory):
            print(path)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        raise SystemExit(f"FAILED: {error}")
