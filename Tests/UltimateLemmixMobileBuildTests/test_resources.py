"""Check the independent mobile resource and review-archive boundaries."""
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'Tools/AlternativeAssets'))
import build_mobile
import mobile_resources
from store_resources import encoded
from byo_bundle import write_member
import io
import json
import plistlib


class MobileResourceTests(unittest.TestCase):
    """Reject unapproved game data, changed approved bytes and linked content."""

    def test_exact_resource_membership_and_bytes(self):
        files = {'Music/Lix/approved.mp3': b'approved recording',
                 'Licences/credits.txt': b'creator and CC0 notice'}
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name, value in files.items():
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(value)
            (root / mobile_resources.MANIFEST).write_bytes(encoded(mobile_resources.inventory(files)))
            mobile_resources.verify(root, files)
            for name in ('MAIN.DAT', 'Ports/level.dat', 'Music/Remixes/unknown.mp3', 'original-icon.png'):
                extra = root / name
                extra.parent.mkdir(parents=True, exist_ok=True)
                extra.write_bytes(b'unapproved')
                with self.subTest(name=name), self.assertRaises(ValueError):
                    mobile_resources.verify(root, files)
                extra.unlink()
            (root / 'Music/Lix/approved.mp3').write_bytes(b'changed recording')
            with self.assertRaises(ValueError):
                mobile_resources.verify(root, files)
            (root / mobile_resources.MANIFEST).write_bytes(encoded(mobile_resources.inventory({
                'Music/Lix/approved.mp3': b'changed recording', 'Licences/credits.txt': files['Licences/credits.txt']})))
            with self.assertRaises(ValueError):
                mobile_resources.verify(root, files)

    def test_resource_links_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / mobile_resources.MANIFEST).write_bytes(encoded(mobile_resources.inventory({})))
            (root / 'linked').symlink_to(root / mobile_resources.MANIFEST)
            with self.assertRaises(ValueError):
                mobile_resources.verify(root, {})

    def test_unsigned_archive_retains_bytes_and_payload(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            app = root / 'UltimateLemmix.app'
            app.mkdir()
            (app / 'UltimateLemmix').write_bytes(b'executable test bytes')
            (app / 'Info.plist').write_bytes(b'metadata test bytes')
            destination = root / 'unsigned.ipa'
            result = build_mobile.review_archive(app, destination, payload=True)
            self.assertFalse(result['installableWithoutSigning'])
            self.assertTrue(result['crcVerified'])
            with zipfile.ZipFile(destination) as archive:
                self.assertEqual(set(archive.namelist()), {
                    'Payload/UltimateLemmix.app/UltimateLemmix', 'Payload/UltimateLemmix.app/Info.plist'})
                self.assertEqual(archive.read('Payload/UltimateLemmix.app/UltimateLemmix'), b'executable test bytes')
            (app / 'linked').symlink_to(app / 'Info.plist')
            with self.assertRaises(ValueError):
                build_mobile.review_archive(app, destination, payload=True)

    def test_mobile_helper_is_classic_only_data_and_deterministic(self):
        contract = json.loads((mobile_resources.ROOT / 'Resources/UltimateLemmix/byo-integration.json').read_text())
        parent = io.BytesIO()
        with zipfile.ZipFile(parent, 'w') as archive:
            write_member(archive, 'byo-integration.json', encoded(contract))
        first = mobile_resources.mobile_helper(parent.getvalue())
        self.assertEqual(first, mobile_resources.mobile_helper(parent.getvalue()))
        with zipfile.ZipFile(io.BytesIO(first['Integration/Ultimate-Lemmix-BYO.zip'])) as archive:
            self.assertEqual(set(archive.namelist()), {'byo-integration.json', 'README.txt', 'manifest.json'})
            mobile = json.loads(archive.read('byo-integration.json'))
            self.assertEqual([game['id'] for game in mobile['games']], ['classic'])
            self.assertEqual(mobile['platforms'], ['ios', 'tvos'])
            self.assertFalse(mobile['containsExecutableCode'])
            self.assertFalse(mobile['containsCommercialAssets'])
            self.assertEqual(mobile['downloads'], [])

    def test_separate_build_output_rejects_escape_and_linked_ancestors(self):
        self.assertEqual(build_mobile.output_directory(Path('.build/ios-review-build2')),
                         mobile_resources.ROOT / '.build/ios-review-build2')
        for path in (Path('/tmp/mobile-review'), mobile_resources.ROOT / '.build',
                     mobile_resources.ROOT / '.build/../escape',
                     mobile_resources.ROOT / '.build/ultimate-lemmix-personal-preview',
                     mobile_resources.ROOT / '.build/ultimate-lemmix-app-store-build3-universal'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                build_mobile.output_directory(path)
        with tempfile.TemporaryDirectory(dir=mobile_resources.ROOT / '.build') as temporary:
            root = Path(temporary)
            (root / 'link').symlink_to(root, target_is_directory=True)
            with self.assertRaises(ValueError):
                build_mobile.output_directory(root / 'link/child')

    def test_default_mobile_outputs_use_current_numbered_build(self):
        for platform, target in (('ios', 'UltimateLemmixIOS'), ('tvos', 'UltimateLemmixTVOS')):
            self.assertEqual(build_mobile.default_output(platform, mobile_resources.ROOT / 'Apps' / target),
                             mobile_resources.ROOT / '.build' / f'ultimate-lemmix-{platform}-build4')

    def test_review_archive_name_uses_actual_bundle_build(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary)
            (app / 'Info.plist').write_bytes(plistlib.dumps({
                'CFBundleShortVersionString': '0.1', 'CFBundleVersion': '2'}))
            self.assertEqual(build_mobile.archive_name('ios', app, 'unsigned.ipa'),
                             'Ultimate-Lemmix-ios-0.1-build2-unsigned.ipa')


if __name__ == '__main__':
    unittest.main()
