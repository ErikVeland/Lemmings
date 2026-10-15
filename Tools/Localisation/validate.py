#!/usr/bin/env python3
"""Validate complete language packs. Structural checks do not replace language or device review."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
LANGUAGES = ('es-419', 'de', 'fr', 'pt-BR', 'it', 'nl', 'nb')
PLACEHOLDERS = re.compile(r'\{\d+\}')
CATEGORIES = {'zero', 'one', 'two', 'few', 'many', 'other'}


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate translation key: ' + key)
        result[key] = value
    return result


def read_json(path):
    return json.loads(path.read_text(), object_pairs_hook=unique_pairs)


def count_formats(text):
    return re.findall(r'%(?:%|ld|[^%]?)', text)


def validate_texts(source, values, unchanged=()):
    errors = []
    for key, value in values.items():
        if key not in source:
            errors.append(f'Unknown text key: {key!r}')
        if not isinstance(value, str) or not value.strip():
            errors.append(f'Empty or invalid translation: {key!r}')
            continue
        if set(PLACEHOLDERS.findall(key)) != set(PLACEHOLDERS.findall(value)):
            errors.append(f'Invalid placeholders: {key!r}')
        if value == key and key not in unchanged and any(c.isalpha() for c in key):
            errors.append(f'English text requires an explicit unchanged-text review: {key!r}')
        if '\ufffd' in value or any(ord(c) < 32 and c not in '\n\r\t' for c in value):
            errors.append(f'Invalid text character: {key!r}')
    missing = sorted(set(source) - set(values))
    return errors, missing


def validate_plurals(source, values):
    errors = []
    for key, categories in values.items():
        if key not in source:
            errors.append(f'Unknown plural key: {key!r}')
        if not isinstance(categories, dict) or not {'one', 'other'} <= categories.keys() or categories.keys() - CATEGORIES:
            errors.append(f'Invalid plural categories: {key!r}')
            continue
        for category, text in categories.items():
            if not isinstance(text, str) or not text.strip() or count_formats(text).count('%ld') != 1 or any(f not in {'%ld', '%%'} for f in count_formats(text)):
                errors.append(f'Invalid count format: {key!r}/{category}')
    return errors, sorted(set(source) - set(values))


def validate_source_messages(messages):
    errors = []
    for row in messages:
        key = row['key']
        if (re.search(r'(?i)<(?:!doctype|script|html)\b|^HTTP/\d|^text/html;|^webkitdirectory\b', key)
                or re.fullmatch(r'\s*(?:[0-9a-f]+:[0-9a-f]+\s*){3,}', key)
                or key == 'TVTransfer-'):
            errors.append(f"Technical data is translated at {row['file']}:{row['line']}: {key[:70]!r}")
    return errors


def inspect(directory):
    catalogue = read_json(ROOT / 'Documentation/LocalisationCatalogue.json')
    texts = {k for k,v in catalogue.items() if v['kind'] == 'text'}
    plurals = {k for k,v in catalogue.items() if v['kind'] == 'plural'}
    reviews_path = ROOT / 'Tools/Localisation/unchanged.json'
    unchanged = read_json(reviews_path) if reviews_path.exists() else {}
    results = {}
    for language in LANGUAGES:
        path = directory / (language + '.json')
        plural_path = directory / (language + '.plurals.json')
        values = read_json(path) if path.exists() else {}
        forms = read_json(plural_path) if plural_path.exists() else {}
        errors, missing = validate_texts(texts, values, unchanged.get(language, {}))
        plural_errors, missing_plurals = validate_plurals(plurals, forms)
        results[language] = dict(text_keys=len(values), total_text_keys=len(texts),
            missing_text=missing, plural_keys=len(forms), total_plural_keys=len(plurals),
            missing_plurals=missing_plurals, errors=errors + plural_errors,
            sha256=hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None,
            complete=not (errors or missing or plural_errors or missing_plurals))
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, default=ROOT / 'Tools/Localisation/drafts')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    results = inspect(args.directory)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(results, ensure_ascii=False, sort_keys=True, indent=2) + '\n')
    for language, result in results.items():
        print(f"{language}: {result['text_keys']}/{result['total_text_keys']} texts; "
              f"{result['plural_keys']}/{result['total_plural_keys']} plurals; "
              f"{len(result['errors'])} errors; {'PASS' if result['complete'] else 'INCOMPLETE'}")
        for error in result['errors'][:5]:
            print('  ' + error)
    return 0 if all(r['complete'] for r in results.values()) else 1


if __name__ == '__main__':
    sys.exit(main())
