"""Prevent version changes and beta packaging from bypassing Classic closure."""
from pathlib import Path
import plistlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'Tools/ReleaseReadiness'))
from package_scope import package_scope


class PackageScopeTests(unittest.TestCase):
    def test_current_beta_can_ship_with_explicit_gaps(self):
        self.assertEqual(package_scope({'CFBundleShortVersionString': '0.1'}, [{'status': 'open'}]), 'beta')

    def test_one_zero_and_later_require_closed_classic_gates(self):
        for version in ['1.0', '1.0.1', '2.0']:
            for status in ['open', 'partial', 'external', 'not-run', None]:
                with self.subTest(version=version, status=status), self.assertRaises(ValueError):
                    package_scope({'CFBundleShortVersionString': version}, [{'area': 'Classic', 'status': status}])

    def test_sequel_fidelity_is_separate_but_unclassified_gates_are_required(self):
        gates = [{'area': 'Classic', 'status': 'closed', 'scopes': ['classic-1.0', 'all']},
                 {'area': 'L2/L3 fidelity', 'status': 'open', 'scopes': ['all']}]
        self.assertEqual(package_scope({'CFBundleShortVersionString': '1.0'}, gates), 'classic-1.0')
        gates.append({'area': 'New blocker', 'status': 'open'})
        with self.assertRaisesRegex(ValueError, 'New blocker'):
            package_scope({'CFBundleShortVersionString': '1.0'}, gates)

    def test_invalid_version_or_missing_gates_fails_closed(self):
        for version in ['', '1.0-beta', None]:
            with self.assertRaises(ValueError):
                package_scope({'CFBundleShortVersionString': version}, [])
        for gates in [[], {}, [None], [{'status': 'closed', 'scopes': ['all']}]]:
            with self.assertRaises(ValueError):
                package_scope({'CFBundleShortVersionString': '1.0'}, gates)
        for scopes in [[], None, 'all', ['classic'], ['all', None]]:
            with self.subTest(scopes=scopes), self.assertRaises(ValueError):
                package_scope({'CFBundleShortVersionString': '1.0'},
                              [{'status': 'closed'}, {'status': 'open', 'scopes': scopes}])

    def test_fresh_audit_failure_blocks_archive_after_resource_changes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)

            def write(relative, text, executable=False):
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text)
                if executable:
                    path.chmod(0o755)

            for relative in ['Scripts/package-beta.sh', 'Tools/ReleaseReadiness/package_scope.py']:
                write(relative, (ROOT / relative).read_text())
            write('Resources/Info.plist', plistlib.dumps(
                {'CFBundleShortVersionString': '1.0', 'CFBundleVersion': '31'}).decode())
            write('Documentation/ReleaseReadiness/gates.json', '[{"status":"closed"}]')
            write('Documentation/ReleaseNotes-beta31.md', 'Candidate test')
            write('Tools/TrolleyVerification/catalogue.py', '')
            write('Resources/Trolley/verified-maxima.json', '{"engineSourceFingerprint":"test"}')
            write('Resources/Hints/classic.json', '{"engineFingerprint":"test"}')
            write('Scripts/build-local-app.sh',
                  'mkdir -p "$LEMMINGS_BUILD_DIR/Ultimate Lemmings.app/Contents/Resources/Music"\n')
            write('Scripts/strip-recorded-music.sh', 'touch "$1/stripped"\n')
            write('bin/codesign', '#!/bin/zsh\ntouch "$LEMMINGS_BUILD_DIR/signed"\n', True)
            write('Tools/ReleaseReadiness/audit.py', '''
def scoped_gates(gates, scope):
    return gates
if __name__ == '__main__':
    import json, os, sys
    from pathlib import Path
    build = Path(os.environ['LEMMINGS_BUILD_DIR'])
    assert (build / 'signed').exists()
    assert (build / 'Ultimate Lemmings.app/Contents/Resources/Music/stripped').exists()
    (build / 'audit-args.json').write_text(json.dumps(sys.argv[1:]))
    raise SystemExit(17)
''')
            build = root / '.build/test'
            env = dict(os.environ, PATH=str(root / 'bin') + os.pathsep + os.environ['PATH'],
                       LEMMINGS_BUILD_DIR=str(build), BETA_SIGNING_IDENTITY='test',
                       BETA_GAME_CENTER='0', BETA_SLIM='1')
            result = subprocess.run(['zsh', str(root / 'Scripts/package-beta.sh')], env=env,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 17, result.stdout + result.stderr)
            args = json.loads((build / 'audit-args.json').read_text())
            self.assertEqual(args[:6], ['--scope', 'classic-1.0', '--require-closure', '--app',
                                       '--app-bundle', str((build / 'Ultimate Lemmings.app').resolve())])
            self.assertNotIn('==> Compressing', result.stdout)
            self.assertEqual(list(build.glob('*.zip')), [])

    def test_real_packager_stops_before_build_or_signing(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for relative in ['Scripts/package-beta.sh', 'Tools/ReleaseReadiness/package_scope.py',
                             'Tools/ReleaseReadiness/audit.py']:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / relative, path)
            (root / 'Resources').mkdir()
            (root / 'Resources/Info.plist').write_bytes(plistlib.dumps(
                {'CFBundleShortVersionString': '1.0', 'CFBundleVersion': '31'}))
            path = root / 'Documentation/ReleaseReadiness/gates.json'
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps([{'area': 'Classic campaign', 'status': 'open'}]))
            result = subprocess.run(['zsh', str(root / 'Scripts/package-beta.sh')], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Classic 1.0 packaging blocked: Classic campaign', result.stderr)
            self.assertNotIn('==> Building', result.stdout)
            self.assertFalse((root / '.build').exists())


if __name__ == '__main__':
    unittest.main()
