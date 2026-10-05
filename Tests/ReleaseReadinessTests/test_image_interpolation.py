"""Catch image hints that newer AppKit versions may tolerate but Ventura rejects."""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]


class ImageInterpolationTests(unittest.TestCase):
    def test_image_hints_do_not_box_swift_enums(self):
        # AppKit expects NSNumber and sends unsignedIntegerValue to this value.
        # A bare Swift enum in the Any-valued hints dictionary becomes __SwiftValue.
        bare_enum = re.compile(
            r"\.interpolation\s*:\s*NSImageInterpolation\.\w+\s*(?=[,\]])"
        )
        failures = []
        for source in (ROOT / "Sources").rglob("*.swift"):
            text = source.read_text()
            for match in bare_enum.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                failures.append(f"{source.relative_to(ROOT)}:{line}")
        self.assertEqual(failures, [], "Use the interpolation enum's numeric rawValue")


if __name__ == "__main__":
    unittest.main()
