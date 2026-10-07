#!/usr/bin/env python3
"""Report L3 fixtures with more than one action on an actor in one tick."""

from collections import Counter
from pathlib import Path
import json


ROOT = Path(__file__).resolve().parent.parent
FIXTURE_DIRS = {
    "standalone": ROOT / "Tests/Lemmings3CompletionTests/Fixtures",
    "carried": ROOT / "Tests/Lemmings3CampaignTests/Fixtures",
}


def audit(directory: Path) -> dict:
    files = sorted(directory.glob("*.json"))
    affected = {}
    repeated_slots = 0
    extra_actions = 0
    largest_group = 0
    for path in files:
        fixture = json.loads(path.read_text())
        groups = Counter(
            (item["tick"], item["lemming"])
            for item in fixture["inputs"]
            if "lemming" in item
        )
        repeated = [size for size in groups.values() if size > 1]
        if repeated:
            affected[path.name] = len(repeated)
            repeated_slots += len(repeated)
            extra_actions += sum(size - 1 for size in repeated)
            largest_group = max(largest_group, *repeated)
    return {
        "fixtures": len(files),
        "affectedFixtures": affected,
        "repeatedActorTicks": repeated_slots,
        "additionalActionsInThoseTicks": extra_actions,
        "largestActionGroup": largest_group,
    }


print(json.dumps({name: audit(path) for name, path in FIXTURE_DIRS.items()},
                 indent=2, sort_keys=True))
