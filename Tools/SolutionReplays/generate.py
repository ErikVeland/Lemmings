#!/usr/bin/env python3
"""Bundle winning input records. The app revalidates each record before playback."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
replays = {}
for suite in ('ClassicDOSCompletionTests', 'ClassicFamilyCompletionTests'):
    for path in sorted((root / 'Tests' / suite / 'Fixtures').rglob('*.json')):
        replay = json.loads(path.read_text())
        if replay.get('expected', {}).get('didWin') is not True:
            continue
        key = replay['initialStateHash']
        if key not in replays or replay['expected']['ticks'] < replays[key]['expected']['ticks']:
            replays[key] = replay
output = root / 'Resources/Hints/solutions.json'
content = json.dumps(replays, sort_keys=True, separators=(',', ':')) + '\n'
if args.check:
    if not output.exists() or output.read_text() != content:
        raise SystemExit('Solution catalogue is stale. Run Tools/SolutionReplays/generate.py.')
    print(f'PASS {len(replays)} bundled winning replays match the fixtures')
else:
    output.write_text(content)
    print(f'{len(replays)} winning replays: {output}')
