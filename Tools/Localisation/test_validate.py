import json
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

import catalogue
import install_drafts_for_testing
from validate import fallback_errors, validate_texts, validate_plurals, validate_source_messages, unique_pairs


class PackValidationTests(unittest.TestCase):
    def test_missing_unknown_and_empty_messages_are_not_complete(self):
        errors, missing = validate_texts({'Start', 'Ready'}, {'Start': '', 'Stale': 'Alt'})
        self.assertEqual(missing, ['Ready'])
        self.assertEqual(len(errors), 2)

    def test_placeholder_reordering_is_allowed_but_loss_is_rejected(self):
        source = {'Saved {0} of {1}'}
        self.assertEqual(validate_texts(source, {'Saved {0} of {1}': '{1} / {0}'})[0], [])
        self.assertTrue(validate_texts(source, {'Saved {0} of {1}': '{0} / {0}'})[0])

    def test_english_requires_a_per_language_review(self):
        self.assertTrue(validate_texts({'Lemmings'}, {'Lemmings': 'Lemmings'})[0])
        self.assertEqual(validate_texts({'Lemmings'}, {'Lemmings': 'Lemmings'}, {'Lemmings': 'Original game title'})[0], [])

    def test_count_formats_cannot_lose_counts_or_change_argument_types(self):
        for bad in ['levels', '%@ levels', '%s levels', '%n', '%ld of %ld', '%ld %']:
            errors, _ = validate_plurals({'count.levels'}, {'count.levels': {'one': '%ld level', 'other': bad}})
            self.assertTrue(errors, bad)
        self.assertEqual(validate_plurals({'count.levels'}, {'count.levels': {'one': '%ld niveau', 'other': '%ld niveaux', 'many': '%ld niveaux'}}), ([], []))

    def test_release_rejects_waived_and_cosmetically_changed_english(self):
        values = {'Ready': ' READY! ', 'Start': 'Start', 'Lemmings': 'Lemmings'}
        retained = {'Start': 'Explicit English fallback. Review pending.',
                    'Lemmings': 'Original game title'}
        self.assertEqual(fallback_errors(values.keys(), values, retained),
                         ["English fallback: 'Ready'", "English fallback: 'Start'"])

    def test_release_requires_complete_draft_and_matching_runtime_and_registrations(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bundle = root / 'Localization.bundle'
            drafts = root / 'drafts'
            paths = [bundle / 'Info.plist', root / 'Resources/Info.plist',
                     root / 'Resources/UltimateLemmix/Info.plist']
            paths += [root / 'Apps' / app / 'Info.plist' for app in (
                'UltimateLemmingsIOS', 'UltimateLemmingsTV', 'UltimateLemmixIOS', 'UltimateLemmixTVOS')]
            for path in paths:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(plistlib.dumps({'CFBundleLocalizations': ['en', 'de']}))
            picker = root / 'Sources/NxlvKit/InterfaceLocalisation.swift'
            picker.parent.mkdir(parents=True)
            picker.write_text('    case english = "en"\n    case german = "de"\n')
            (bundle / 'en.lproj').mkdir()
            runtime = bundle / 'de.lproj'
            runtime.mkdir()
            drafts.mkdir()
            draft = drafts / 'de.json'
            draft.write_text(json.dumps({'Ready': 'Bereit'}))
            (drafts / 'de.plurals.json').write_text('{}')
            (runtime / 'Interface.stringsdict').write_bytes(plistlib.dumps({}))
            strings = runtime / 'Interface.strings'
            install_drafts_for_testing.write_strings(strings, {'Ready': 'Bereit'})
            with patch.multiple(catalogue, ROOT=root, BUNDLE=bundle, LANGUAGES=('de',)), \
                    patch.object(install_drafts_for_testing, 'DRAFTS', drafts):
                self.assertEqual(catalogue.release_errors({'Ready'}, {}), [])
                install_drafts_for_testing.write_strings(strings, {'Ready': 'Fertig'})
                self.assertIn('de: bundled text differs from its draft.',
                              catalogue.release_errors({'Ready'}, {}))
                draft.write_text('{}')
                paths[0].write_bytes(plistlib.dumps({'CFBundleLocalizations': ['en']}))
                errors = catalogue.release_errors({'Ready'}, {})
                self.assertTrue(any('1 missing texts' in error for error in errors))
                self.assertTrue(any('different locale list' in error for error in errors))

    def test_technical_formats_never_enter_a_pack(self):
        for value in ['HTTP/1.1 {0}\r\n', '<!doctype html><script>code</script>', '300:4\n304:14\n305:1', 'TVTransfer-']:
            self.assertTrue(validate_source_messages([{'key': value, 'file': 'test.swift', 'line': 1}]))

    def test_duplicate_keys_are_not_silently_overwritten(self):
        with self.assertRaises(ValueError):
            unique_pairs([('Start', 'Starten'), ('Start', 'Slutt')])


if __name__ == '__main__':
    unittest.main()
