"""Stamp each TV build and bundle its maintained changes before code signing."""
import argparse
import datetime
import json
from pathlib import Path
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--changes", type=Path, required=True)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    args = parser.parse_args()
    changes = json.loads(args.changes.read_text())["changes"]
    if not isinstance(changes, list) or not changes or any(
        not isinstance(item, str) or not item.strip() for item in changes
    ):
        parser.error("TV build changes must contain non-empty text entries")
    payload = {
        "version": args.version,
        "build": args.build,
        "identity": str(uuid.uuid4()),
        "builtAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "changes": changes,
    }
    args.app.mkdir(parents=True, exist_ok=True)
    destination = args.app / "BuildInfo.json"
    temporary = destination.with_suffix(".tmp")
    temporary.write_text(json.dumps(payload, indent=2) + "\n")
    temporary.replace(destination)


if __name__ == "__main__":
    main()
