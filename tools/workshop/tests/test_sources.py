import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import sources


class RenderTest(unittest.TestCase):
    def test_workshop_txt_layout(self):
        item = {"id": "42", "title": "T", "tags": ["Audio", "QoL"], "visibility": "public"}
        self.assertEqual(sources.render_workshop_txt(item, ["a", "", "b"]),
                         "version=1\nid=42\ntitle=T\ndescription=a\ndescription=\ndescription=b\ntags=Audio;QoL\nvisibility=public\n")


class RepositoryTest(unittest.TestCase):
    def test_the_item_is_valid(self):
        self.assertEqual(sources.load_item()["id"], "3775149796")

    def test_the_description_converts(self):
        self.assertGreater(len(sources.description_lines()), 10)

    def test_workshop_txt_is_up_to_date(self):
        self.assertEqual(sources.WORKSHOP_TXT.read_text(encoding="utf-8"), sources.build_text())

    def test_the_changelog_matches_mod_info(self):
        sources.check_changelog_matches_mod_info()

    def test_the_plain_change_note_has_no_markup(self):
        note = sources.change_note("1.0.8", plain=True)
        self.assertTrue(note.startswith("Version 1.0.8\n"))
        self.assertNotIn("**", note)
        self.assertNotIn("[b]", note)

    def test_the_github_release_title_names_the_version_and_the_item(self):
        self.assertEqual(sources.release_title(), f"v{sources.mod_version()} - {sources.load_item()['title']}")

    def test_the_github_release_body_follows_the_template(self):
        body = sources.release_body()
        self.assertNotIn("{{", body)
        self.assertTrue(body.startswith(f'###### <h1 align="center">{sources.release_title()}</h1>'))
        self.assertEqual(body.count("######"), 4)
        self.assertIn("stargazers", body)
        self.assertIn(f"filedetails/?id={sources.load_item()['id']}", body)

    def test_the_change_note_is_bbcode(self):
        note = sources.change_note()
        self.assertTrue(note.startswith("[b]"))
        self.assertIn("[list]", note)


if __name__ == "__main__":
    unittest.main()
