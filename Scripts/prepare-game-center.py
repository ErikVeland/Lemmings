#!/usr/bin/env python3
"""Prepare exact-condition Game Center boards from the bundled rescue catalogue."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=root / 'Resources/GameCenter')
parser.add_argument('--enable', action='store_true', help='Enable only after the Apple registration and signing setup is complete.')
args = parser.parse_args()
source = json.loads((root / 'Resources/Trolley/verified-maxima.json').read_text())
stamp = datetime.datetime.fromisoformat(source['generatedAt'].replace('Z', '+00:00'))
reference = datetime.datetime(2001, 1, 1, tzinfo=datetime.timezone.utc)
evidence_date = (stamp - reference).total_seconds()
# Distinguish repeated level titles in App Store Connect.
reference_names = {
    'ul.v1.level.f81ce4044366425f5062': 'We all fall down (80) - Most Saved',
    'ul.v1.level.01bc4487b197741dfbf7': 'We all fall down (60) - Most Saved',
    'ul.v1.level.1fc47f14184a0f2a27dd': 'We all fall down (40) - Most Saved',
    'ul.v1.level.893bc90ebcb6229f2c4d': 'This Corrosion (Oh No) - Most Saved',
}
levels, apple = [], []
for row in source['levels']:
    c = row.get('conditions')
    if not c or row['status'] not in ('VERIFIED', 'REPLAY_RECORD'):
        continue
    digest = hashlib.sha256(json.dumps(c, sort_keys=True, separators=(',', ':')).encode()).hexdigest()[:20]
    board = 'ul.v1.level.' + digest
    maximum = row.get('maximumSaveable') if row['status'] == 'VERIFIED' else row.get('bestSaved')
    if maximum is None:
        continue
    levels.append({'conditions': c, 'maximum': {'value': maximum, 'status': row['status'],
                   'source': 'Ranked release catalogue v1', 'date': evidence_date,
                   'buildVersion': source['engineSourceFingerprint']}, 'leaderboardID': board})
    apple.append({'id': board, 'name': reference_names.get(board, row.get('title', c['levelID']) + ' - Most Saved'),
                  'unit': 'rescued', 'minimum': 0, 'maximum': c['population'], 'sort': 'descending', 'submission': 'best-score'})
config = {'enabled': args.enable, 'starsID': 'ul.v1.career.stars', 'clearsID': 'ul.v1.career.cleared',
          'perfectID': 'ul.v1.career.three_star', 'levels': levels}
for key, name, unit, factor in [('starsID', 'Ranked Career Stars', 'stars', 3), ('clearsID', 'Ranked Levels Cleared', 'levels', 1), ('perfectID', 'Ranked Three-Star Levels', 'levels', 1)]:
    apple.insert(0, {'id': config[key], 'name': name, 'unit': unit, 'minimum': 0, 'maximum': len(levels) * factor,
                     'sort': 'descending', 'submission': 'best-score'})
for index, row in enumerate(apple):
    row['set'] = 'ul.v1.set.' + str(index // 100 + 1)
args.output.mkdir(parents=True, exist_ok=True)
(args.output / 'leaderboards.json').write_text(json.dumps(config, indent=2, sort_keys=True) + '\n')
(args.output / 'app-store-connect-boards.json').write_text(json.dumps({'bundleID': 'academy.glasscode.lemmings', 'leaderboards': apple}, indent=2) + '\n')
print(f'Prepared {len(apple)} Apple boards for {len(levels)} ranked configurations. Enabled: {args.enable}')
