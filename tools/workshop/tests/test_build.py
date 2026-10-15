import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import build


class RenderTest(unittest.TestCase):
    def test_workshop_txt_layout(self):
        item = {"id": "42", "title": "T", "tags": ["Audio", "QoL"], "visibility": "public"}
        self.assertEqual(build.render_workshop_txt(item, ["a", "", "b"]),
                         "version=1\nid=42\ntitle=T\ndescription=a\ndescription=\ndescription=b\ntags=Audio;QoL\nvisibility=public\n")


class RepositoryTest(unittest.TestCase):
    def test_the_item_is_valid(self):
        self.assertEqual(build.load_item()["id"], "3775149796")

    def test_the_description_converts(self):
        self.assertGreater(len(build.description_lines()), 10)

    def test_workshop_txt_is_up_to_date(self):
        self.assertEqual(build.WORKSHOP_TXT.read_text(encoding="utf-8"), build.build_text())

    def test_the_changelog_matches_mod_info(self):
        build.check_changelog_matches_mod_info()

    def test_the_plain_change_note_has_no_markup(self):
        note = build.change_note("1.0.8", plain=True)
        self.assertTrue(note.startswith("Version 1.0.8\n"))
        self.assertNotIn("**", note)
        self.assertNotIn("[b]", note)

    def test_the_change_note_is_bbcode(self):
        note = build.change_note()
        self.assertTrue(note.startswith("[b]"))
        self.assertIn("[list]", note)


if __name__ == "__main__":
    unittest.main()
