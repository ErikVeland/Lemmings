#!/usr/bin/env python3
"""Bundle winning input records. The app revalidates each record before playback."""
import json
from pathlib import Path

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
output.write_text(json.dumps(replays, sort_keys=True, separators=(',', ':')) + '\n')
print(f'{len(replays)} winning replays: {output}')
