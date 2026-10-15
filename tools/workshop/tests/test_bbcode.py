import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import bbcode


class InlineTest(unittest.TestCase):
    def test_bold_and_italic(self):
        self.assertEqual(bbcode.convert_inline("**a** and *b* and _c_"), "[b]a[/b] and [i]b[/i] and [i]c[/i]")

    def test_link_and_bold_around_it(self):
        self.assertEqual(bbcode.convert_inline("**[Site](https://example.com/a_b)**"), "[b][url=https://example.com/a_b]Site[/url][/b]")

    def test_image_inside_a_link(self):
        self.assertEqual(bbcode.convert_inline("[![x](https://i.example/a.png)](https://example.com)"),
                         "[url=https://example.com][img]https://i.example/a.png[/img][/url]")

    def test_snake_case_is_not_italic(self):
        self.assertEqual(bbcode.convert_inline("the some_file_name here"), "the some_file_name here")

    def test_escapes(self):
        self.assertEqual(bbcode.convert_inline(r"1 \* 2 \[x\]"), "1 * 2 [x]")

    def test_inline_code_becomes_bold(self):
        self.assertEqual(bbcode.convert_inline("use `shuffle`"), "use [b]shuffle[/b]")


class BlockTest(unittest.TestCase):
    def test_headings_and_rule(self):
        self.assertEqual(bbcode.convert("# A\n## B\n### C\n---"), ["[h1]A[/h1]", "[h2]B[/h2]", "[h3]C[/h3]", "[hr][/hr]"])

    def test_lists_close_on_a_blank_line(self):
        self.assertEqual(bbcode.convert("- a\n- b\n\ntext"), ["[list]", "[*]a", "[*]b", "[/list]", "", "text"])

    def test_numbered_list(self):
        self.assertEqual(bbcode.convert("1. a\n2. b"), ["[olist]", "[*]a", "[*]b", "[/olist]"])

    def test_checkboxes(self):
        self.assertEqual(bbcode.convert("- [x] done\n- [ ] todo"), ["[list]", "[*]✅ done", "[*]⬜ todo", "[/list]"])

    def test_quote_and_code(self):
        self.assertEqual(bbcode.convert("> hi\n```\nraw *text*\n```"), ["[quote]", "hi", "[/quote]", "[code]", "raw *text*", "[/code]"])

    def test_lines_are_kept_as_written(self):
        self.assertEqual(bbcode.convert("one\ntwo\n\nthree"), ["one", "two", "", "three"])

    def test_nested_lists_are_rejected(self):
        with self.assertRaises(bbcode.ConversionError):
            bbcode.convert("- a\n  - b")

    def test_tables_are_rejected(self):
        with self.assertRaises(bbcode.ConversionError):
            bbcode.convert("| a | b |")

    def test_html_is_rejected(self):
        with self.assertRaises(bbcode.ConversionError) as raised:
            bbcode.convert("fine\n<b>no</b>")
        self.assertEqual(raised.exception.line_number, 2)

    def test_unclosed_code_block_is_rejected(self):
        with self.assertRaises(bbcode.ConversionError):
            bbcode.convert("```\nnever closed")


if __name__ == "__main__":
    unittest.main()
