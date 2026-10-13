#!/usr/bin/env python3
"""Prepare the iOS Apple catalogue, or validate a recorded Apple-side activation."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
BUNDLE_ID = 'academy.glasscode.lemmings.ios'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def manifest(resources=ROOT / 'Resources'):
    directory = resources / 'GameCenter'
    boards = json.loads((directory / 'app-store-connect-boards.json').read_text())['leaderboards']
    catalogue = json.loads((directory / 'leaderboards.json').read_text())
    identifiers = {catalogue[key] for key in ('starsID', 'clearsID', 'perfectID')}
    for level in catalogue['levels']:
        identifiers.update(level[key] for key in ('leaderboardID', 'fastestClearID', 'fastestPerfectID') if level.get(key))
    if len(boards) > 500 or len({b['id'] for b in boards}) != len(boards) or {b['id'] for b in boards} != identifiers:
        raise ValueError('The setup manifest and client catalogue do not contain the same unique Apple IDs.')
    sets = [{'id': identifier, 'name': f'Classic Rankings {index + 1}',
             'leaderboards': [b['id'] for b in boards if b['set'] == identifier]}
            for index, identifier in enumerate(sorted({b['set'] for b in boards}))]
    if any(len(s['leaderboards']) > 100 for s in sets):
        raise ValueError('An Apple leaderboard set exceeds 100 boards.')
    return {'schemaVersion': 1, 'bundleID': BUNDLE_ID, 'platform': 'IOS', 'version': '2.0',
            'catalogueSHA256': sha(directory / 'leaderboards.json'),
            'leaderboards': boards, 'sets': sets,
            'verification': {'status': 'pending', 'appID': None, 'verifiedAtUTC': None}}


def validate_activation(path, resources=ROOT / 'Resources', bundle_id=BUNDLE_ID):
    record = json.loads(Path(path).read_text())
    expected = manifest(resources)
    if bundle_id != BUNDLE_ID or any(record.get(key) != value for key, value in expected.items() if key != 'verification'):
        raise ValueError('Game Center activation does not match this iOS bundle, version and full board catalogue.')
    verification = record.get('verification', {})
    if verification.get('status') != 'verified' or not re.fullmatch(r'[0-9]+', str(verification.get('appID', ''))):
        raise ValueError('Game Center requires a verified iOS App Store Connect app record.')
    try:
        checked = datetime.fromisoformat(verification['verifiedAtUTC'].replace('Z', '+00:00'))
        if checked.tzinfo is None or checked > datetime.now(timezone.utc):
            raise ValueError()
    except (ValueError, KeyError, TypeError):
        raise ValueError('Game Center activation needs a valid verification time.') from None
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_mutually_exclusive_group(required=True)
    actions.add_argument('--prepare', type=Path, help='Write a pending iOS setup manifest. Does not contact Apple.')
    actions.add_argument('--check', type=Path, help='Check an activation record after Apple-side verification.')
    args = parser.parse_args()
    if args.prepare:
        args.prepare.parent.mkdir(parents=True, exist_ok=True)
        args.prepare.write_text(json.dumps(manifest(), indent=2) + '\n')
        print('Prepared 359 boards and four sets. Apple-side verification is pending.')
    else:
        record = validate_activation(args.check)
        print('Validated iOS activation record for Apple app ' + str(record['verification']['appID']))


if __name__ == '__main__':
    main()
