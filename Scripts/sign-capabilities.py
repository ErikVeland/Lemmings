#!/usr/bin/env python3
"""Sign a macOS app with its Game Center and Spatial Audio Profile capabilities."""
import argparse
import datetime
import hashlib
import json
import pathlib
import plistlib
import re
import shutil
import subprocess
import tempfile

BUNDLE_ID = 'academy.glasscode.lemmings'
CAPABILITIES = ('com.apple.developer.game-center', 'com.apple.developer.spatial-audio.profile-access')


def select_profile(paths, identities):
    for path in paths:
        result = subprocess.run(['security', 'cms', '-D', '-i', str(path)], capture_output=True)
        if result.returncode:
            continue
        profile = plistlib.loads(result.stdout)
        entitlements = profile.get('Entitlements', {})
        app_id = entitlements.get('com.apple.application-identifier', '')
        if app_id != entitlements.get('com.apple.developer.team-identifier', '') + '.' + BUNDLE_ID:
            continue
        if 'OSX' not in profile.get('Platform', []):
            continue
        if not all(entitlements.get(key) is True for key in CAPABILITIES):
            continue
        if profile.get('ExpirationDate', datetime.datetime.min) <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
            continue
        for certificate in profile.get('DeveloperCertificates', []):
            fingerprint = hashlib.sha1(certificate).hexdigest().upper()
            if fingerprint in identities:
                return path, entitlements, fingerprint
    raise SystemExit('No valid macOS provisioning profile for academy.glasscode.lemmings with both capabilities and an installed signing identity. Download the profile from Apple Developer, then retry.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=pathlib.Path)
    parser.add_argument('--profile', type=pathlib.Path)
    parser.add_argument('--check', action='store_true', help='Validate signing prerequisites without changing the app.')
    args = parser.parse_args()
    contents = args.app / 'Contents'
    info = plistlib.loads((contents / 'Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != BUNDLE_ID:
        raise SystemExit('The app bundle identifier does not match ' + BUNDLE_ID)
    identities = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning'], text=True)
    roots = [pathlib.Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles',
             pathlib.Path.home() / 'Library/MobileDevice/Provisioning Profiles']
    paths = [args.profile] if args.profile else [p for root in roots for p in sorted(root.glob('*.provisionprofile'))]
    path, allowed, identity = select_profile(paths, identities)
    print('Selected profile: ' + str(path))
    if args.check:
        return
    # Only request app capabilities and the identifiers authorised by this profile.
    entitlements = {key: True for key in CAPABILITIES}
    for key in ('com.apple.application-identifier', 'com.apple.developer.team-identifier', 'get-task-allow'):
        if key in allowed:
            entitlements[key] = allowed[key]
    board_path = contents / 'Resources/GameCenter/leaderboards.json'
    config = json.loads(board_path.read_text())
    ids = [config[key] for key in ('starsID', 'clearsID', 'perfectID')] + [row['leaderboardID'] for row in config['levels'] if row.get('leaderboardID')]
    if len(set(ids)) != len(ids) or any(not re.fullmatch(r'[A-Za-z0-9_.]{1,100}', identifier) for identifier in ids):
        raise SystemExit('The catalogue contains duplicate or invalid Apple leaderboard IDs.')
    config['enabled'] = True
    board_path.write_text(json.dumps(config, indent=2, sort_keys=True) + '\n')
    shutil.copy2(path, contents / 'embedded.provisionprofile')
    with tempfile.TemporaryDirectory(prefix='lemmings-sign-') as temporary:
        entitlements_path = pathlib.Path(temporary) / 'app.entitlements'
        entitlements_path.write_bytes(plistlib.dumps(entitlements))
        for library in sorted((contents / 'Frameworks').glob('*.dylib')):
            subprocess.run(['codesign', '--force', '--options', 'runtime', '--timestamp', '--sign', identity, str(library)], check=True)
        subprocess.run(['codesign', '--force', '--options', 'runtime', '--timestamp', '--sign', identity,
                        '--entitlements', str(entitlements_path), str(args.app)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(args.app)], check=True)
    signed = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(args.app)], capture_output=True, check=True)
    actual = plistlib.loads(signed.stdout)
    if not all(actual.get(key) is True for key in CAPABILITIES):
        raise SystemExit('The finished signature is missing a required capability.')
    print('Signed and verified both capabilities: ' + str(args.app))


if __name__ == '__main__':
    main()
