#!/usr/bin/env python3
"""Compare focused native resource runs without broad release or corpus checks."""
import json
from pathlib import Path
import sys


def compare(root):
    runs = {phase: json.loads((root / phase / 'result.json').read_text())
            for phase in ('reference', 'import', 'reopen')}
    failures = []
    reference = runs['reference']
    for phase in ('import', 'reopen'):
        current = runs[phase]
        for key in ('catalogue', 'browserCatalogue', 'homeActions', 'captures', 'menu', 'originalSkin'):
            if current[key] != reference[key]:
                failures.append(f'{phase}: {key} differs from the source-resource run')
        for engine in ('l2', 'l3'):
            for key in ('catalogue', 'frameHash', 'width', 'height', 'checkpointHash'):
                if current['mobileHostSessions'][engine][key] != reference['mobileHostSessions'][engine][key]:
                    failures.append(f'{phase}: {engine} {key} differs')
    for phase in ('import', 'reopen'):
        for key in ('catalogue', 'packID', 'levelID', 'terrainHash', 'stateMatchesReference', 'tick', 'capture'):
            if runs[phase]['neoNative'][key] != reference['neoNative'][key]:
                failures.append(f'{phase}: native NeoLemmix {key} differs')
    if not runs['reopen']['neoNative']['restoredAcrossProcesses']:
        failures.append('Native NeoLemmix did not restore across processes')
    for phase in ('import', 'reopen'):
        for key in ('roster', 'nextTurnIndex', 'queueIndex', 'archivedQueue', 'checkpointTick', 'checkpointStateHash', 'homeActions', 'savedHome'):
            if runs[phase]['persistence'][key] != reference['persistence'][key]:
                failures.append(f'{phase}: native persistence {key} differs')
    if not runs['reopen']['persistence']['restoredAcrossProcesses']:
        failures.append('Native saved state was not restored across processes')
    if runs['import']['contentID'] != runs['reopen']['contentID']:
        failures.append('The imported content ID changed after reopening')
    if not runs['reopen']['profileSurvivedReopen']:
        failures.append('The active player did not survive reopening')
    report = {'passed': not failures, 'failures': failures,
              'contentID': runs['import']['contentID'],
              'coverage': reference['coverage'],
              'limits': ['No unmodified baseline executable UI comparison',
                         'No UIKit, tvOS, physical-device, hosted-service or audible-audio acceptance',
                         'Folder-picker controls captured; import uses the real library API directly']}
    (root / 'comparison.json').write_text(json.dumps(report, indent=2) + '\n')
    for failure in failures:
        print('FAIL ' + failure, file=sys.stderr)
    print('PASS focused resource import/reopen parity' if not failures else 'FAIL focused resource import/reopen parity')
    return not failures


if __name__ == '__main__':
    raise SystemExit(0 if compare(Path(sys.argv[1])) else 1)
