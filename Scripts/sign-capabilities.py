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


def sign(identity, path, *extra):
    subprocess.run(['codesign', '--force', '--options', 'runtime', '--timestamp', '--sign', identity, *extra, str(path)], check=True)


def sign_framework(identity, framework):
    # Sign nested code inside-out, as Sparkle's documentation requires. The
    # Downloader service keeps its own sandbox entitlements.
    version = framework / 'Versions/Current'
    for service in sorted((version / 'XPCServices').glob('*.xpc')):
        extra = ('--preserve-metadata=entitlements',) if service.stem == 'Downloader' else ()
        sign(identity, service, *extra)
    for helper in (version / 'Autoupdate', version / 'Updater.app'):
        if helper.exists():
            sign(identity, helper)
    sign(identity, framework)


def team_identifier(path):
    details = subprocess.run(['codesign', '-dv', str(path)], capture_output=True, text=True).stderr
    match = re.search(r'^TeamIdentifier=(.+)$', details, re.MULTILINE)
    return match.group(1) if match else 'not set'


def require_one_team(app):
    # Hardened runtime refuses to load code from a different team at launch.
    # codesign --verify --deep does not detect this.
    frameworks = app / 'Contents/Frameworks'
    code = [app] + sorted(frameworks.glob('*.dylib'))
    for framework in sorted(frameworks.glob('*.framework')):
        version = framework / 'Versions/Current'
        code += [framework] + sorted((version / 'XPCServices').glob('*.xpc'))
        code += [path for path in (version / 'Autoupdate', version / 'Updater.app') if path.exists()]
    expected = team_identifier(app)
    wrong = [str(path.relative_to(app)) + ' (' + team_identifier(path) + ')' for path in code if team_identifier(path) != expected]
    if expected == 'not set' or wrong:
        raise SystemExit('Signed code does not match the app team ' + expected + ': ' + ', '.join(wrong))


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
            sign(identity, library)
        for framework in sorted((contents / 'Frameworks').glob('*.framework')):
            sign_framework(identity, framework)
        sign(identity, args.app, '--entitlements', str(entitlements_path))
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(args.app)], check=True)
    require_one_team(args.app)
    signed = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(args.app)], capture_output=True, check=True)
    actual = plistlib.loads(signed.stdout)
    if not all(actual.get(key) is True for key in CAPABILITIES):
        raise SystemExit('The finished signature is missing a required capability.')
    print('Signed and verified both capabilities: ' + str(args.app))


if __name__ == '__main__':
    main()
