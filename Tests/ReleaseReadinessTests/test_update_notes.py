import sys
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Tools/ReleaseReadiness"))
from update_notes import render_update_notes


class UpdateNotesTests(unittest.TestCase):
    NOTES = (
        "# Ultimate Lemmings 1.5 (build 47)\n\n"
        "[Download the Mac app](https://example.invalid/app.zip)\n\n"
        "Build: 47\nRelease commit: " + "a" * 40 + "\nRelease base: v1.2-build41\n\n"
        "## Fixes\n\n- One **bold** fix with `code`\n  that wraps.\n- A second fix.\n\n"
        "Plain <text> & more.\n"
    )

    def test_renders_player_facing_html(self):
        html = render_update_notes(self.NOTES)
        self.assertNotIn("<h1", html)
        self.assertNotIn("Download the Mac app", html)
        self.assertIn("<h3>Fixes</h3>", html)
        self.assertIn("<li>One <b>bold</b> fix with <code>code</code> that wraps.</li>", html)
        self.assertIn("Plain &lt;text&gt; &amp; more.", html)

    def test_keeps_the_release_commit_for_the_publication_check(self):
        html = render_update_notes(self.NOTES)
        self.assertIn("Release commit: " + "a" * 40, html)
        self.assertLess(html.index("A second fix"), html.index("Release commit"))


if __name__ == "__main__":
    unittest.main()
