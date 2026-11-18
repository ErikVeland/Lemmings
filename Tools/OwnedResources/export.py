#!/usr/bin/env python3
"""Export player-supplied preservation resources without application code."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import shutil
import tempfile

import cursors

MANIFEST = '.owned-resource-export.json'
FAMILIES = {'Ports', 'MacArtwork', 'AmigaArtwork', 'NeoLemmix', 'Music', 'Sounds', 'LevelPacks',
            'About', 'MenuArtwork', 'MacMusic', 'Localization.bundle', 'Cursors'}
PROTECTED = {'Hints', 'Progression', 'Trolley', 'GameCenter', 'AlternativeAssets', 'Provenance',
             'Licences', 'OpenStarter', 'Integration', 'AppIcon.icns', 'AppIcon.png',
             'PrivacyInfo.xcprivacy', 'store-resources-manifest.json', 'personal-preview-resources.json',
             'PERSONAL-PREVIEW-NOTICE.txt', '.DS_Store', MANIFEST}
CODE_EXTENSIONS = {'.exe', '.com', '.bat', '.cmd', '.sh', '.bash', '.zsh', '.py', '.pyc', '.js', '.mjs',
                   '.swift', '.dylib', '.dll', '.so', '.jar', '.class', '.wasm', '.xpc'}
MAX_BYTES, MAX_FILE_BYTES, MAX_ENTRIES = 8 * 1024**3, 1024**3, 50_000
MAGIC = (b'MZ', b'#!', b'\x7fELF', b'\xfe\xed\xfa\xce', b'\xce\xfa\xed\xfe',
         b'\xfe\xed\xfa\xcf', b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca',
         b'\xca\xfe\xba\xbf', b'\xbf\xba\xfe\xca', b'\0\0\x03\xf3')


def digest(path: Path) -> tuple[int, str]:
    """Hash bounded file bytes without loading a music library into memory."""
    value, size = hashlib.sha256(), 0
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            size += len(block)
            if size > MAX_FILE_BYTES:
                raise ValueError('A source asset exceeds the file size limit.')
            value.update(block)
    return size, value.hexdigest()


def safe_name(name: str) -> tuple[str, ...]:
    """Reject linked archive-style paths, control characters and traversal."""
    path = PurePosixPath(name)
    if (path.is_absolute() or path.as_posix() != name or '..' in path.parts or '\\' in name
            or not name or any(ord(char) < 32 for char in name) or len(path.parts) > 32):
        raise ValueError('An asset path is unsafe.')
    return path.parts


def omitted_source(name: str) -> bool:
    """Exclude unused standalone legacy code and Finder records from an old app."""
    lower = name.lower()
    utilities = {'echo', 'why', 'iconx', 'failat', 'holidaylemmings1994', 'type', 'cd', 'run'}
    return (lower in {'ports/amiga_extracted/holiday/' + item for item in utilities}
            or lower.startswith('ports/lemm2/music/') and lower.endswith('.bin')
            or lower.startswith('ports/lem3cd/') and lower.endswith('.drv')
            or lower.startswith('ports/') and lower.rsplit('/', 1)[-1]
            in {'icon\r', 'openfolderlistdf\r', 'icon\r.rsrc', 'openfolderlistdf\r.rsrc'})


def asset_name(name: str) -> bool:
    """Keep trusted app metadata outside the player-owned asset overlay."""
    parts = safe_name(name)
    if parts[0] in PROTECTED:
        return False
    if parts[0] == 'Fonts':
        if len(parts) >= 2 and parts[1] == 'OriginalLemmings':
            return True
        raise ValueError('Only the original bitmap font belongs in a font overlay.')
    if parts[0] not in FAMILIES:
        raise ValueError('The source contains an unsupported resource family: ' + parts[0])
    return True


def check_file(path: Path, name: str) -> None:
    """Reject standalone code while keeping historical source containers inert."""
    if omitted_source(name) or path.suffix.lower() in CODE_EXTENSIONS:
        raise ValueError('The resource selection contains standalone code: ' + name)
    if any(Path(part).suffix.lower() in {'.app', '.framework', '.xpc'} for part in PurePosixPath(name).parts[:-1]):
        raise ValueError('An application cannot be nested in the resource selection.')
    with path.open('rb') as stream:
        if stream.read(32).startswith(MAGIC):
            raise ValueError('The resource selection contains an executable header: ' + name)
    parts = PurePosixPath(name).parts
    if parts[0] == 'Cursors' and (name not in cursors.PINS or digest(path)[1] != cursors.PINS[name]):
        raise ValueError('The original cursor pixels differ from the supported source.')
    if parts[0] == 'Localization.bundle':
        if path.suffix.lower() not in {'.strings', '.stringsdict', '.plist', '.json', '.png', '.rgba', '.icns', '.txt'}:
            raise ValueError('The localisation bundle contains unsupported data.')
        if path.name == 'Info.plist' and 'CFBundleExecutable' in plistlib.loads(path.read_bytes()):
            raise ValueError('The localisation bundle must not contain executable code.')


def collect(source: Path) -> tuple[dict[str, Path | bytes], list[str], dict]:
    """Select asset files from the supplied app or resource directory."""
    source = source.absolute()
    if source.is_symlink() or not source.is_dir():
        raise ValueError('Choose a local preservation app or resource directory.')
    existing_app = source.suffix.lower() == '.app'
    resources = source / 'Contents/Resources' if existing_app else source
    if resources.name == 'Resources' and resources.parent.name == 'Contents' and resources.parent.parent.suffix.lower() == '.app':
        existing_app = True
    if not resources.is_dir() or resources.is_symlink():
        raise ValueError('The source app has no readable resource directory.')
    selected, omissions, total = {}, [], 0
    names = set()
    for path in sorted(resources.rglob('*')):
        name = path.relative_to(resources).as_posix()
        if path.is_symlink():
            raise ValueError('Resource sources must not contain symbolic links.')
        if path.is_dir():
            continue
        if not path.is_file():
            raise ValueError('Resource sources must contain regular files only.')
        if existing_app and omitted_source(name):
            omissions.append(name)
            continue
        if not asset_name(name):
            continue
        if name.lower() in names:
            raise ValueError('The resource selection contains duplicate names.')
        names.add(name.lower())
        check_file(path, name)
        size, _ = digest(path)
        total += size
        if len(selected) >= MAX_ENTRIES or total > MAX_BYTES:
            raise ValueError('The resource selection exceeds the import limits.')
        selected[name] = path
    if existing_app and 'MacArtwork/lemmings/manifest.json' in selected:
        selected.update(cursors.collect(source))
    if not selected:
        raise ValueError('The source has no supported preservation resources.')
    return selected, sorted(omissions), {'name': source.name, 'existingApp': existing_app}


def verify(output: Path) -> dict:
    """Check exact membership, asset safety and every exported file hash."""
    if output.is_symlink():
        raise ValueError('The export directory must not be a link.')
    record = json.loads((output / MANIFEST).read_bytes())
    if record.get('kind') != 'player-owned-preservation-resource-export' or record.get('redistributionCleared') is not False:
        raise ValueError('The export provenance is invalid.')
    expected, folded = set(), set()
    for row in record['files']:
        name = row['path']
        if not asset_name(name) or name.lower() in folded:
            raise ValueError('The export contains an invalid asset path.')
        expected.add(name)
        folded.add(name.lower())
        path = output / name
        if path.is_symlink() or not path.is_file():
            raise ValueError('An exported asset is linked or missing.')
        check_file(path, name)
        if digest(path) != (row['bytes'], row['sha256']):
            raise ValueError('An exported asset changed: ' + name)
    actual = set()
    for path in output.rglob('*'):
        if path.is_symlink():
            raise ValueError('Exported assets must not contain links.')
        if path.is_file():
            actual.add(path.relative_to(output).as_posix())
    if actual != expected | {MANIFEST}:
        raise ValueError('The export contains unexpected or missing files.')
    return record


def export(source: Path, output: Path) -> dict:
    """Publish a new local asset folder without replacing an existing selection."""
    selected, omissions, description = collect(source)
    output = output.absolute()
    if output.exists() or output.is_symlink():
        raise ValueError('Choose a new export directory; existing files will not be replaced.')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.owned-resource-export-', dir=output.parent) as temporary:
        staging = Path(temporary) / 'payload'
        staging.mkdir()
        rows = []
        for name, payload in sorted(selected.items()):
            target = staging / name
            target.parent.mkdir(parents=True, exist_ok=True)
            if isinstance(payload, bytes):
                target.write_bytes(payload)
            else:
                before = digest(payload)
                shutil.copyfile(payload, target)
                if digest(target) != before:
                    raise ValueError('A source asset changed during export: ' + name)
            target.chmod(0o644)
            size, sha = digest(target)
            rows.append({'path': name, 'bytes': size, 'sha256': sha})
        record = {'schemaVersion': 1, 'kind': 'player-owned-preservation-resource-export',
                  'requiresPlayerFiles': True, 'redistributionCleared': False,
                  'source': description, 'standaloneExecutableFilesIncluded': False,
                  'historicalContainersReadOnly': True, 'historicalContainersMayContainOriginalCode': True,
                  'codeExecuted': False, 'omittedSourceFiles': omissions,
                  'nativeFormatValidation': 'Performed when the app imports the exported folder.', 'files': rows}
        (staging / MANIFEST).write_text(json.dumps(record, indent=2) + '\n')
        verify(staging)
        staging.rename(output)
    return verify(output)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    if not args.verify and args.source is None:
        parser.error('--source is required to prepare a resource export.')
    record = verify(args.output) if args.verify else export(args.source, args.output)
    print(f"PASS local owned-resource export: {len(record['files'])} files; no app was launched.")


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, cursors.CursorError) as error:
        raise SystemExit('FAILED: ' + str(error))
