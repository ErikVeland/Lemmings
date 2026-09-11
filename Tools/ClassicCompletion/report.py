#!/usr/bin/env python3
"""Refresh the completion report after the native replay gate passes."""
import argparse
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / 'Documentation/ClassicCompletion'
FIXTURES = ROOT / 'Tests/ClassicDOSCompletionTests/Fixtures'
RANKS = ['Fun', 'Tricky', 'Taxing', 'Mayhem']
SOURCE = 'https://www.lemmingsforums.net/index.php?topic=1383.0'
# DOS records include documented glitches. A record is not an impossibility proof.
RECORD_LOSSES = {
    ('Fun', 3): 3, ('Fun', 6): 2, ('Fun', 18): 5,
    ('Tricky', 15): 3, ('Tricky', 16): 4, ('Tricky', 17): 2,
    ('Tricky', 18): 1, ('Tricky', 23): 1,
    ('Taxing', 7): 1, ('Taxing', 19): 5, ('Taxing', 27): 3, ('Taxing', 28): 10,
    ('Mayhem', 5): 4, ('Mayhem', 10): 2, ('Mayhem', 19): 2,
    ('Mayhem', 26): 4, ('Mayhem', 29): 2,
}


def build():
    previous = json.loads((REPORT / 'evidence.json').read_text())
    old = {Path(row['fixture']).name: row for row in previous['fixtures']}
    references = {}
    for path in sorted((ROOT / '.build/classic-completion/checked-candidates').glob('*.json')):
        source = json.loads(path.read_text())
        for offset in [0, 1, -1, 2, -2, 3, -3]:
            events = [dict(event, tick=event['tick'] + offset) for event in source['events']]
            key = json.dumps(events, sort_keys=True)
            references.setdefault(key, []).append(dict(origin=source.get('origin'),
                tickOffset=offset, title=source['title']))
    rows = []
    table = []
    unresolved = []
    statuses = Counter()
    for rank in RANKS:
        for number in range(1, 31):
            path = FIXTURES / f'{rank.lower()}-{number:02}.json'
            replay = json.loads(path.read_text())
            assert replay['rank'] == rank and replay['number'] == number
            outcome = replay['expected']
            population = old[path.name]['population']
            assert outcome['didWin'] and outcome['required'] <= outcome['saved'] <= population
            digest = sha256(path.read_bytes()).hexdigest()
            matched = references.get(json.dumps(replay['events'], sort_keys=True))
            if matched is None:
                matched = old[path.name].get('matchingReferenceCandidates', []) if old[path.name]['sha256'] == digest else []
            known = population - RECORD_LOSSES.get((rank, number), 0)
            status = 'PROVED_FULL_RESCUE' if outcome['saved'] == population else 'UPPER_BOUND_UNPROVEN'
            statuses[status] += 1
            if outcome['saved'] == known:
                statuses['REFERENCE_RECORD_MATCHED'] += 1
            relative = str(path.relative_to(ROOT))
            rows.append(dict(fixture=relative, sha256=digest, population=population,
                expected=outcome, matchingReferenceCandidates=matched,
                publishedDOSRecord=known, maximumStatus=status))
            title = replay['title'].replace('|', '/')
            proof = '0 (proved)' if status == 'PROVED_FULL_RESCUE' else 'Unproven'
            table.append(f'| {rank} {number} | {title} | {population} | {outcome["required"]} | {outcome["saved"]} | {known} | {proof} | [Replay](../../{relative}) |')
            if status != 'PROVED_FULL_RESCUE':
                unresolved.append(f'| {rank} {number} | {title} | {outcome["saved"]}/{population} | {known}/{population} | {"Record matched; upper bound unproven" if outcome["saved"] == known else "Native route still below published record"} |')
    fingerprint = subprocess.check_output(['python3', str(ROOT / 'Tools/TrolleyVerification/catalogue.py'), 'fingerprint'], text=True).strip()
    evidence = dict(engineSourceFingerprint=fingerprint, dataFiles=previous['dataFiles'],
        referenceRecordSource=dict(url=SOURCE, retrieved='2026-09-09', scope='Original DOS; documented glitches included; not an upper-bound proof'),
        counts=dict(statuses), fixtures=rows)
    text = (REPORT / 'README.md').read_text().split('## Per-level results')[0].split('## Maximum-rescue status')[0]
    full = statuses['PROVED_FULL_RESCUE']
    text = re.sub(r'\*\*\d+ levels rescue their entire population\.\*\*.*?\n\n',
        f'**{full} levels rescue their entire population.** Those replays prove zero necessary sacrifices. '
        f'The other {120-full} have verified winning solutions, but their upper rescue bounds remain unproven. '
        'The maximum-rescue task is not complete.\n\n', text, count=1, flags=re.S)
    text += f'''## Maximum-rescue status

The saved replay count improved from 60 to {full} full rescues during the maximum-rescue pass. All 120 levels still have winning evidence. Native replays match the [published DOS record table]({SOURCE}) for {statuses['REFERENCE_RECORD_MATCHED']} levels. A matched nonzero-loss record is a reference result, not proof that our engine cannot save more. The bundled catalogue certifies full-population rescues only. It also supplies the other 17 replay counts as best-known targets for optional stars and leaderboards, without claiming proved minimum sacrifices.

The remaining levels are:

| Level | Title | Native saved | Published DOS record | Remaining work |
| --- | --- | ---: | ---: | --- |
'''+ '\n'.join(unresolved) + '''

## Per-level results

“Saved” is the native witness result. The reference column reports the published DOS record; it is not a native upper bound.

| Level | Title | Population | Required | Saved | DOS record | Minimum sacrifices | Evidence |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
'''+ '\n'.join(table)+'\n'
    return evidence, text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    evidence, text = build()
    payload = json.dumps(evidence, indent=2) + '\n'
    if args.check:
        assert (REPORT / 'evidence.json').read_text() == payload, 'Stale evidence manifest'
        assert (REPORT / 'README.md').read_text() == text, 'Stale completion report'
        print('PASS report, 120 fixture hashes, and current engine fingerprint')
    else:
        (REPORT / 'evidence.json').write_text(payload)
        (REPORT / 'README.md').write_text(text)
        print(evidence['counts'])


if __name__ == '__main__':
    main()
