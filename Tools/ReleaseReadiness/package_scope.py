"""Reject 1.0-or-later packaging while a Classic release gate is open."""
import json
from pathlib import Path
import plistlib
import re
import sys

from audit import scoped_gates


def package_scope(info, gates):
    version = info.get('CFBundleShortVersionString', '')
    if not isinstance(version, str) or not re.fullmatch(r'\d+(?:\.\d+){0,2}', version):
        raise ValueError('Invalid release version in Info.plist.')
    if int(version.split('.')[0]) < 1:
        return 'beta'
    if not isinstance(gates, list) or not gates or any(not isinstance(g, dict) for g in gates):
        raise ValueError('Classic release gates are missing or malformed.')
    for gate in gates:
        scopes = gate.get('scopes', ['classic-1.0', 'all'])
        if (not isinstance(scopes, list) or not scopes
                or any(scope not in ('classic-1.0', 'all') for scope in scopes)):
            raise ValueError('Classic release gate scope is missing or malformed.')
    selected = scoped_gates(gates, 'classic-1.0')
    if not selected:
        raise ValueError('No Classic release gates are defined.')
    pending = [g.get('area', 'Unnamed release gate') for g in selected if g.get('status') != 'closed']
    if pending:
        raise ValueError('Classic 1.0 packaging blocked: ' + '; '.join(pending))
    return 'classic-1.0'


if __name__ == '__main__':
    try:
        root = Path(sys.argv[1])
        info = plistlib.loads((root / 'Resources/Info.plist').read_bytes())
        gates = json.loads((root / 'Documentation/ReleaseReadiness/gates.json').read_text())
        print(package_scope(info, gates))
    except (ValueError, OSError, KeyError, IndexError, TypeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
