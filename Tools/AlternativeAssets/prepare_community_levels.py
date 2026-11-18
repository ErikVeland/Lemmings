#!/usr/bin/env python3
"""Prepare the reviewed community corpus for a personal Mac test, not Store distribution."""
import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Content/LevelPacks'
POLICY = ROOT / 'Resources/AlternativeAssets/community-levels-policy.json'
OUTPUT = ROOT / '.build/personal-preview-assets/LevelPacks'
MANIFEST = 'community-manifest.json'
CACHE = ROOT / '.build/personal-preview-community-cache'
_DECODED_MEMO = {}


def encoded(value):
    """Serialise reproducible records without local timestamps."""
    return (json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + '\n').encode()


def sha(data):
    """Identify exact source or output bytes."""
    return hashlib.sha256(data).hexdigest()


def checked(path, row):
    """Reject linked, missing or changed inputs."""
    if path.is_symlink() or not path.is_file():
        raise ValueError('A reviewed community input is missing or linked: ' + str(path))
    data = path.read_bytes()
    if len(data) != row['bytes'] or sha(data) != row['sha256']:
        raise ValueError('A reviewed community input changed: ' + str(path))
    return data


def safe_name(name):
    """Accept one relative archive member without an extraction path."""
    path = PurePosixPath(name)
    if (not name or path.is_absolute() or path.as_posix() != name or '\\' in name
            or '..' in path.parts or any(ord(c) < 32 for c in name)):
        raise ValueError('An archive member path is unsupported.')
    return name


NATIVE_SOURCE = r'''
import Foundation
import CryptoKit

private struct Input: Decodable { let key: String; let name: String; let data: Data }
private struct Record: Encodable {
    let physicalSection: Int?
    let title: String
    let sha256: String
    let rawSHA256: String?
}
private struct Output: Encodable { let key: String; let records: [Record]; let error: String? }
private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
private func record(_ level: ClassicLevel, raw: Data?, section: Int?) throws -> Record {
    var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(level)) as! [String: Any]
    object["skills"] = ClassicSkill.allCases.map { [$0.rawValue, level.skills[$0] ?? 0] as [Any] }
    let canonical = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    return Record(physicalSection: section, title: level.title, sha256: digest(canonical),
                  rawSHA256: raw.map { digest(Data($0.prefix(ClassicLevel.recordSize))) })
}
@main private struct DecodeCommunity {
    static func main() throws {
        let inputs = try JSONDecoder().decode([Input].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        let outputs = inputs.map { input -> Output in
            do {
                let records: [Record]
                if input.name.lowercased().hasSuffix(".dat") {
                    records = try ClassicDATArchive.decode(input.data).enumerated().compactMap { index, section -> Record? in
                        guard section.data.count >= ClassicLevel.recordSize,
                              let level = try? ClassicLevel(data: section.data.prefix(ClassicLevel.recordSize)) else { return nil }
                        return try record(level, raw: section.data, section: index)
                    }
                } else if input.name.lowercased().hasSuffix(".lvl")
                    || (input.data.count == ClassicLevel.recordSize && input.data.prefix(32).contains(0)) {
                    records = [try record(FanLevelReader.level(fromLVL: input.data), raw: input.data, section: nil)]
                } else {
                    let text = String(data: input.data, encoding: .utf8)
                        ?? String(data: input.data, encoding: .isoLatin1)
                        ?? String(decoding: input.data, as: UTF8.self)
                    records = [try record(FanLevelReader.level(fromINI: text), raw: nil, section: nil)]
                }
                return Output(key: input.key, records: records, error: nil)
            } catch {
                return Output(key: input.key, records: [], error: String(describing: error))
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(outputs).write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic)
    }
}
'''


def native_decoder(directory):
    """Compile the repository's existing level readers without the app or original assets."""
    CACHE.mkdir(parents=True, exist_ok=True)
    sources = [ROOT / 'Sources/NxlvKit' / name for name in (
        'ClassicDATArchive.swift', 'ClassicLevel.swift', 'FanLevelReader.swift')]
    binary = directory / 'decode-levels'
    helper = directory / 'decoder.swift'
    helper.write_text(NATIVE_SOURCE)
    developer = Path(os.environ.get('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer'))
    compiler = developer / 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'
    sdk = developer / 'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'
    command = [str(compiler), '-swift-version', '6', '-O', '-warnings-as-errors',
               '-parse-as-library', '-sdk', str(sdk), '-module-cache-path', str(CACHE / 'ModuleCache'),
               *map(str, sources), str(helper), '-o', str(binary)]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode:
        raise ValueError('The independent native level reader did not compile:\n' + result.stderr[-4000:])
    return binary


def source_inputs(policy):
    """Check every pinned source before classification or copying."""
    catalog_data = checked(SOURCE / 'packs.json', policy['catalogue'])
    counts_data = checked(SOURCE / 'level-counts.json', policy['levelCounts'])
    catalog = json.loads(catalog_data)
    counts = json.loads(counts_data)
    rows = policy['packs']
    expected = {row['archive'] for row in rows}
    actual = {path.name for path in SOURCE.glob('*.zip')}
    if len(rows) != len(expected) or actual != expected:
        raise ValueError('The community archive inventory changed.')
    if {row['id'] for row in rows} != {row['id'] for row in catalog}:
        raise ValueError('The reviewed policy does not cover every catalogue pack.')
    archives = {row['archive']: checked(SOURCE / row['archive'], row) for row in rows}
    for row in policy['canonicalFiles']:
        checked(ROOT / row['path'], row)
    for row in policy['readerSources']:
        checked(ROOT / row['path'], row)
    return catalog, counts, archives


def member_inputs(archives, canonical_files):
    """Read level members as data and preserve existing DAT source-slot identities."""
    packets, slots = [], {}
    for name, data in sorted(archives.items()):
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            members = archive.namelist()
            if len(members) != len(set(members)):
                raise ValueError('A source archive contains duplicate members: ' + name)
            mapping = json.loads(archive.read('classic-section-slots.json')) if 'classic-section-slots.json' in members else {}
            for info in archive.infolist():
                if info.is_dir():
                    continue
                member = safe_name(info.filename)
                suffix, base = Path(member).suffix.lower(), Path(member).name.lower()
                if (suffix not in ('.dat', '.lvl', '.ini') or base.endswith('levelpack.ini')
                        or base.startswith(('ground', 'vgagr', 'vgaspec'))):
                    continue
                key = name + '::' + member
                packets.append({'key': key, 'name': member, 'data': base64.b64encode(archive.read(info)).decode()})
                if member in mapping:
                    slots[key] = mapping[member]
    for row in canonical_files:
        packets.append({'key': '@canonical::' + row['path'], 'name': row['path'],
                        'data': base64.b64encode((ROOT / row['path']).read_bytes()).decode()})
    return packets, slots


def decode(archives, policy):
    """Recompute native results rather than trusting an editable generated cache."""
    packets, slots = member_inputs(archives, policy['canonicalFiles'])
    fingerprint = sha(encoded(packets) + encoded(policy['readerSources']))
    if fingerprint in _DECODED_MEMO:
        return _DECODED_MEMO[fingerprint], slots
    CACHE.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='decode-', dir=CACHE) as temporary:
        binary = native_decoder(Path(temporary))
        request, response = Path(temporary) / 'input.json', Path(temporary) / 'output.json'
        request.write_bytes(encoded(packets))
        subprocess.run([str(binary), str(request), str(response)], check=True,
                       env={**os.environ, 'LEMMINGS_TEST_AUDIO': 'muted', 'LEMMINGS_TEST_WINDOWS': 'offscreen'})
        decoded = json.loads(response.read_text())
    if len(decoded) != len(packets) or {row['key'] for row in decoded} != {row['key'] for row in packets}:
        raise ValueError('The native level inventory is inconsistent.')
    _DECODED_MEMO.clear()
    _DECODED_MEMO[fingerprint] = decoded
    return decoded, slots


def exclusions_for(decoded, policy, slots):
    """Find exact official/release-linked records without treating modified fan designs as official."""
    excluded_packs = {row['archive'] for row in policy['packs'] if not row['include']}
    canonical = {}
    for item in decoded:
        archive, member = item['key'].split('::', 1)
        if archive != '@canonical' and archive not in excluded_packs:
            continue
        for record in item['records']:
            source = item['key'] + ('#' + str(record['physicalSection']) if record.get('physicalSection') is not None else '')
            for key in ('sha256', 'rawSHA256'):
                if record.get(key):
                    canonical.setdefault(record[key], []).append(source)
    hashes = {row['archive']: row['sha256'] for row in policy['packs']}
    exclusions = []
    decoded_counts = {}
    for item in decoded:
        archive, member = item['key'].split('::', 1)
        if archive == '@canonical':
            continue
        decoded_counts[archive] = decoded_counts.get(archive, 0) + len(item['records'])
        if archive in excluded_packs:
            continue
        for record in item['records']:
            matches = canonical.get(record['sha256'], []) + canonical.get(record.get('rawSHA256'), [])
            if not matches:
                continue
            physical = record.get('physicalSection')
            original = slots.get(item['key'])
            if original is not None and (physical is None or not isinstance(original, list) or physical >= len(original)):
                raise ValueError('An original DAT section mapping is invalid.')
            exclusions.append({'archive': archive, 'archiveSHA256': hashes[archive], 'file': member,
                               'section': original[physical] if original is not None else physical,
                               'title': record['title'], 'matchSHA256': record['sha256'],
                               'canonicalSources': sorted(set(matches)),
                               'reason': 'exact-record-match-to-excluded-official-or-release-linked-source'})
    return exclusions, decoded_counts


def collect():
    """Rebuild approved personal-preview bytes from pinned policy and source archives."""
    policy = json.loads(POLICY.read_text())
    if policy.get('scope') != 'personal-test-not-cleared' or policy.get('distributionApproved') is not False:
        raise ValueError('The personal-preview distribution boundary changed.')
    catalog, counts, archives = source_inputs(policy)
    decoded, slots = decode(archives, policy)
    exclusions, decoded_counts = exclusions_for(decoded, policy, slots)
    by_archive = {}
    for row in exclusions:
        by_archive.setdefault(row['archive'], []).append(row)
    policy_rows = {row['id']: row for row in policy['packs']}
    output, packs, adjusted, inventory = {}, [], {}, []
    mismatches = []
    for item in catalog:
        row = policy_rows[item['id']]
        name = row['archive']
        if decoded_counts.get(name, 0) != counts[name]:
            mismatches.append({'archive': name, 'indexed': counts[name], 'nativeDecoded': decoded_counts.get(name, 0)})
        removed = by_archive.get(name, [])
        remaining = counts[name] - len(removed)
        if remaining < 0:
            raise ValueError('The exclusion count exceeds a source pack count.')
        include = row['include'] and remaining > 0
        if include:
            output[name] = archives[name]
            packs.append(item)
            adjusted[name] = remaining
        inventory.append({**row, 'archiveSHA256': row['sha256'], 'included': include, 'sourceLevels': counts[name],
                          'includedLevels': remaining if include else 0,
                          'excludedEntries': removed})
    output['packs.json'] = encoded(packs)
    output['level-counts.json'] = encoded(adjusted)
    manifest = {'schemaVersion': 1, 'scope': policy['scope'], 'distributionApproved': False,
                'policySHA256': sha(POLICY.read_bytes()), 'creatorRights': 'pending',
                'summary': {'sourcePacks': len(catalog), 'sourceLevels': sum(counts.values()),
                            'includedPacks': len(packs), 'includedLevels': sum(adjusted.values()),
                            'excludedPacks': len(catalog) - len(packs), 'excludedEntries': len(exclusions)},
                'packs': inventory, 'entryExclusions': exclusions,
                'nativeIndexMismatches': mismatches, 'limitations': policy['limitations'],
                'files': [{'path': name, 'bytes': len(data), 'sha256': sha(data)}
                          for name, data in sorted(output.items())]}
    output[MANIFEST] = encoded(manifest)
    return output


def verify(output=OUTPUT):
    """Reject modified output even when its manifest was changed to match."""
    files = collect()
    if output.is_symlink() or not output.is_dir():
        raise ValueError('The prepared community folder is missing or linked.')
    actual = set()
    for path in output.rglob('*'):
        if path.is_symlink() or path.is_dir():
            raise ValueError('The prepared community folder contains a link or subdirectory.')
        actual.add(path.name)
    if actual != set(files):
        raise ValueError('The prepared community folder contains missing or extra files.')
    for name, data in files.items():
        if (output / name).read_bytes() != data:
            raise ValueError('A prepared community file changed: ' + name)
    return json.loads(files[MANIFEST])


def prepare(output=OUTPUT):
    """Replace only an owned generated output folder after source verification."""
    output = output.absolute()
    if ROOT / '.build' not in output.parents or output.name != 'LevelPacks' or output.is_symlink():
        raise ValueError('Community output must be a LevelPacks folder inside this checkout’s .build directory.')
    files = collect()
    if output.exists():
        previous = json.loads((output / MANIFEST).read_text())
        if previous.get('scope') != 'personal-test-not-cleared':
            raise ValueError('The existing output folder is not a personal preview.')
        known = {row['path']: row for row in previous['files']}
        actual = {path.name for path in output.iterdir()}
        if actual != set(known) | {MANIFEST}:
            raise ValueError('The output folder contains unrelated files.')
        for name, row in known.items():
            checked(output / safe_name(name), row)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='community-', dir=output.parent) as temporary:
        staging = Path(temporary) / 'LevelPacks'
        staging.mkdir()
        for name, data in files.items():
            (staging / name).write_bytes(data)
        if output.exists():
            shutil.rmtree(output)
        staging.replace(output)
    return verify(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    record = verify() if args.verify else prepare()
    print('Personal-test community corpus only: ' + json.dumps(record['summary'], sort_keys=True))
    if record['nativeIndexMismatches']:
        print('Native/index count differences retained as explicit evidence: '
              + json.dumps(record['nativeIndexMismatches'], sort_keys=True))


if __name__ == '__main__':
    main()
