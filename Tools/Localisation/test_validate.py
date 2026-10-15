import unittest
from validate import validate_texts, validate_plurals, validate_source_messages, unique_pairs


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

    def test_technical_formats_never_enter_a_pack(self):
        for value in ['HTTP/1.1 {0}\r\n', '<!doctype html><script>code</script>', '300:4\n304:14\n305:1', 'TVTransfer-']:
            self.assertTrue(validate_source_messages([{'key': value, 'file': 'test.swift', 'line': 1}]))

    def test_duplicate_keys_are_not_silently_overwritten(self):
        with self.assertRaises(ValueError):
            unique_pairs([('Start', 'Starten'), ('Start', 'Slutt')])


if __name__ == '__main__':
    unittest.main()
