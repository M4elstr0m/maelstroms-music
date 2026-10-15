import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import changelog

SAMPLE = """# Changelog

## [Unreleased]

### Added
- A new thing (#5)

## [1.0.8] - 2026-10-12

### Fixed
- A bug (#4)
- Another bug

### Added
- Something
"""


class ChangelogTest(unittest.TestCase):
    def setUp(self):
        self.releases = changelog.parse(SAMPLE)

    def test_parses_releases_in_order(self):
        self.assertEqual([r.version for r in self.releases], ["Unreleased", "1.0.8"])
        self.assertEqual(self.releases[1].date, "2026-10-12")
        self.assertEqual(self.releases[1].groups["Fixed"], ["A bug (#4)", "Another bug"])

    def test_select_prefers_a_non_empty_unreleased_section(self):
        self.assertEqual(changelog.select(self.releases).version, "Unreleased")

    def test_select_skips_an_empty_unreleased_section(self):
        releases = changelog.parse("## [Unreleased]\n\n## [1.0.8] - 2026-10-12\n### Added\n- x\n")
        self.assertEqual(changelog.select(releases).version, "1.0.8")

    def test_select_a_version(self):
        self.assertEqual(changelog.select(self.releases, "1.0.8").version, "1.0.8")
        with self.assertRaises(LookupError):
            changelog.select(self.releases, "9.9.9")

    def test_latest_released_ignores_unreleased(self):
        self.assertEqual(changelog.latest_released(self.releases).version, "1.0.8")

    def test_change_note_orders_groups(self):
        note = changelog.change_note_markdown(self.releases[1])
        self.assertEqual(note, "**Version 1.0.8**\n\n**Added**\n- Something\n\n**Fixed**\n- A bug (#4)\n- Another bug\n")

    def test_release_notes_use_headings(self):
        self.assertEqual(changelog.release_notes_markdown(self.releases[0]), "### Added\n- A new thing (#5)\n")

    def test_draft_groups_conventional_commits(self):
        subjects = ["feat(playback): add the staging (#7)", "fix(options): list the page first (#6)", "docs: update", "chore: tidy", "Merge x"]
        self.assertEqual(changelog.draft(subjects), "### Added\n- Add the staging (#7)\n\n### Fixed\n- List the page first (#6)\n")

    def test_draft_is_empty_without_entries(self):
        self.assertEqual(changelog.draft(["docs: update"]), "")


if __name__ == "__main__":
    unittest.main()
