#!/usr/bin/env python3
"""Install structurally complete draft packs for local in-app testing."""
import json
import plistlib
from pathlib import Path
import sys

from validate import LANGUAGES, read_json, validate_plurals, validate_texts

ROOT = Path(__file__).resolve().parents[2]
DRAFTS = ROOT / 'Tools/Localisation/drafts'
BUNDLE = ROOT / 'Sources/NxlvKit/Resources/Localization.bundle'
CATALOGUE = ROOT / 'Documentation/LocalisationCatalogue.json'
UNCHANGED = ROOT / 'Tools/Localisation/unchanged.json'


def write_strings(path, values):
    lines = ['/* Draft localisation. For in-app testing only. */', '']
    for key, value in sorted(values.items()):
        lines.append(f'{json.dumps(key, ensure_ascii=False)} = {json.dumps(value, ensure_ascii=False)};')
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def plural_table(forms):
    entries = {}
    for key, categories in sorted(forms.items()):
        count = {
            'NSStringFormatSpecTypeKey': 'NSStringPluralRuleType',
            'NSStringFormatValueTypeKey': 'ld',
            **categories,
        }
        entries[key] = {
            'NSStringLocalizedFormatKey': '%#@count@',
            'count': count,
        }
    return plistlib.dumps(entries, fmt=plistlib.FMT_XML, sort_keys=True)


def main():
    if sys.argv[1:] != ['--for-in-app-testing']:
        print('Usage: python3 Tools/Localisation/install_drafts_for_testing.py --for-in-app-testing', file=sys.stderr)
        return 2

    catalogue = read_json(CATALOGUE)
    text_keys = {key for key, row in catalogue.items() if row['kind'] == 'text'}
    plural_keys = {key for key, row in catalogue.items() if row['kind'] == 'plural'}
    unchanged = read_json(UNCHANGED)

    packs = {}
    errors = []
    for locale in LANGUAGES:
        text_path = DRAFTS / f'{locale}.json'
        plural_path = DRAFTS / f'{locale}.plurals.json'
        texts = read_json(text_path)
        plurals = read_json(plural_path)
        text_errors, missing_text = validate_texts(text_keys, texts, unchanged.get(locale, {}))
        plural_errors, missing_plurals = validate_plurals(plural_keys, plurals)
        if text_errors or missing_text or plural_errors or missing_plurals:
            errors.append(f'{locale}: {len(text_errors)} text errors, {len(missing_text)} missing texts, '
                          f'{len(plural_errors)} plural errors, {len(missing_plurals)} missing plurals')
        else:
            packs[locale] = (texts, plurals)

    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1

    for locale, (texts, plurals) in packs.items():
        target = BUNDLE / f'{locale}.lproj'
        target.mkdir(parents=True, exist_ok=True)
        write_strings(target / 'Interface.strings', texts)
        (target / 'Interface.stringsdict').write_bytes(plural_table(plurals))
    print(f'Installed {len(packs)} draft locales for in-app testing. Human review remains required.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
