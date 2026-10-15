"""Reject packaging while a gate for the release's Mac scope is open."""
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
    major = int(version.split('.')[0])
    if major < 1:
        return 'beta'
    scope = 'macos-2.0' if major >= 2 else 'classic-1.0'
    label = 'macOS 2.0' if major >= 2 else 'Classic 1.0'
    if not isinstance(gates, list) or not gates or any(not isinstance(g, dict) for g in gates):
        raise ValueError('Release gates are missing or malformed.')
    for gate in gates:
        scopes = gate.get('scopes', ['classic-1.0', 'all'])
        if (not isinstance(scopes, list) or not scopes
                or any(scope not in ('classic-1.0', 'all', 'macos-2.0') for scope in scopes)):
            raise ValueError('Release gate scope is missing or malformed.')
    if scope == 'macos-2.0' and not any(scope in g.get('scopes', []) for g in gates):
        raise ValueError('No macOS 2.0 release gates are defined.')
    selected = scoped_gates(gates, scope)
    if not selected:
        raise ValueError('No ' + label + ' release gates are defined.')
    pending = [g.get('area', 'Unnamed release gate') for g in selected if g.get('status') != 'closed']
    if pending:
        raise ValueError(label + ' packaging blocked: ' + '; '.join(pending))
    return scope


if __name__ == '__main__':
    try:
        root = Path(sys.argv[1])
        info = plistlib.loads((root / 'Resources/Info.plist').read_bytes())
        gates = json.loads((root / 'Documentation/ReleaseReadiness/gates.json').read_text())
        print(package_scope(info, gates))
    except (ValueError, OSError, KeyError, IndexError, TypeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
