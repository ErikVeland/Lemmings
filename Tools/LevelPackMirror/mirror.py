#!/usr/bin/env python3
"""Mirrors the fan level packs from the Lemmings Level Database.

The database holds several hundred packs written by many different people. This
downloads them for offline use.

The script is deliberately slow. It asks for one pack at a time and waits
between requests, because the site is run by volunteers and a mirror is not
worth degrading it for anybody else. It also skips packs it already has, so a
run that stops part way can be repeated without asking for the same files again.

robots.txt disallows /level/play/, /level/random/, /level/solution/ and
/search. None of those are touched here.

Usage:
    python3 Tools/LevelPackMirror/mirror.py [output-directory]
"""
import html
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

SITE = "https://lldb.camanis.net"
LIST = SITE + "/levelpack/list"
AGENT = "LemmingsLocal-archive/0.1 (personal offline mirror; one request at a time)"
DELAY = 1.5          # seconds between requests
RETRIES = 3
TIMEOUT = 60


UNSAFE = re.compile(r"[^A-Za-z0-9_-]+")


def component(text, fallback):
    """Reduces a name from the site to one harmless path component.

    The slug and the download filename both arrive from the server, and the
    slug is read straight out of the page markup. Neither is allowed to choose
    where a file lands, so a separator or a parent reference is replaced rather
    than escaped. A name that holds nothing usable falls back.
    """
    name = UNSAFE.sub("-", text).strip("-")
    return name or fallback


def get(url, binary=False):
    request = urllib.request.Request(url, headers={"User-Agent": AGENT})
    last = None
    for attempt in range(RETRIES):
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                data = response.read()
                name = response.headers.get_filename()
                return (data, name) if binary else (data.decode("utf-8", "replace"), name)
        except (urllib.error.URLError, TimeoutError) as error:
            last = error
            # Back off further each time rather than hammering a failing server.
            time.sleep(DELAY * (attempt + 2))
    raise SystemExit(f"giving up on {url}: {last}")


def pages():
    """Yields every listing page, following the pagination the first one shows."""
    first, _ = get(LIST)
    numbers = [int(n) for n in re.findall(r"page=(\d+)", first)]
    last = max(numbers) if numbers else 1
    yield first
    for number in range(2, last + 1):
        time.sleep(DELAY)
        page, _ = get(f"{LIST}?sort=-date&page={number}")
        yield page


def packs():
    """Every pack on the site, as (id, slug, title), without repeats."""
    seen = {}
    for page in pages():
        for match in re.finditer(
            r'href="/levelpack/(\d+)/([^"]+)"[^>]*>([^<]*)</a>', page
        ):
            identifier = int(match.group(1))
            seen.setdefault(identifier, (
                identifier, match.group(2), html.unescape(match.group(3)).strip()))
    return [seen[key] for key in sorted(seen)]


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "Content/LevelPacks")
    root.mkdir(parents=True, exist_ok=True)

    listing = packs()
    print(f"found {len(listing)} packs")
    (root / "packs.json").write_text(json.dumps(
        [{"id": i, "slug": s, "title": t} for i, s, t in listing], indent=2) + "\n")

    got = skipped = failed = 0
    for number, (identifier, slug, title) in enumerate(listing, start=1):
        target = root / f"{identifier:04d}-{component(slug, 'pack')}"
        existing = list(root.glob(f"{identifier:04d}-*"))
        if any(path.stat().st_size > 0 for path in existing):
            skipped += 1
            continue
        url = f"{SITE}/levelpack/download/{identifier}/{urllib.parse.quote(slug)}?i={identifier}"
        time.sleep(DELAY)
        try:
            data, filename = get(url, binary=True)
        except SystemExit as error:
            print(f"  [{number}/{len(listing)}] FAILED {identifier} {title}: {error}")
            failed += 1
            continue
        # Keep the extension the server gives, since packs are not all zips.
        given = Path(filename).suffix.lstrip(".") if filename else ""
        suffix = "." + component(given, "zip")
        path = target.with_suffix(suffix)
        # The names above are already reduced to one component each. This says
        # so out loud, so a later change to either cannot quietly write outside
        # the output directory.
        if not path.resolve().is_relative_to(root.resolve()):
            raise SystemExit(f"refusing to write outside {root}: {path}")
        path.write_bytes(data)
        got += 1
        print(f"  [{number}/{len(listing)}] {identifier:4d} {title[:44]:<44} "
              f"{len(data):>9,} bytes -> {path.name}")

    print(f"\ndownloaded {got}, already had {skipped}, failed {failed}")


if __name__ == "__main__":
    main()
