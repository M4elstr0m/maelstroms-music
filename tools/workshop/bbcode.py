"""Converts the Markdown subset used for the Workshop page into Steam BBCode."""
import re

HEADING = re.compile(r"^(#{1,3}) +(.+?) *$")
RULE = re.compile(r"^(-{3,}|\*{3,}|_{3,})$")
BULLET = re.compile(r"^[-*] +(.*)$")
NUMBERED = re.compile(r"^\d+\. +(.*)$")
QUOTE = re.compile(r"^> ?(.*)$")
FENCE = re.compile(r"^```")
INDENTED_ITEM = re.compile(r"^\s+([-*]|\d+\.) ")
TABLE_ROW = re.compile(r"^\s*\|")
HTML_TAG = re.compile(r"<[A-Za-z/][^>]*>")
IMAGE = re.compile(r"!\[([^\]]*)\]\(([^)\s]+)\)")
LINK = re.compile(r"\[([^\]]+)\]\(([^)\s]+)\)")
BOLD = re.compile(r"\*\*(.+?)\*\*")
ITALIC_STAR = re.compile(r"(?<![*\w])\*(?!\s)(.+?)(?<!\s)\*(?![*\w])")
ITALIC_UNDERSCORE = re.compile(r"(?<![\w])_(?!\s)(.+?)(?<!\s)_(?![\w])")
INLINE_CODE = re.compile(r"`([^`]+)`")
ESCAPED = re.compile(r"\\([*_`\[\]\\])")
CHECKBOX = re.compile(r"^\[( |x|X)\] +")
PLACEHOLDER = "\x00{}\x00"
CHECKED, UNCHECKED = "\u2705", "\u2b1c"


class ConversionError(ValueError):
    def __init__(self, line_number, message):
        super().__init__(f"line {line_number}: {message}")
        self.line_number = line_number


def _inline(text, held):
    def hold(bbcode):
        held.append(bbcode)
        return PLACEHOLDER.format(len(held) - 1)

    text = ESCAPED.sub(lambda m: hold(m.group(1)), text)
    text = IMAGE.sub(lambda m: hold(f"[img]{m.group(2)}[/img]"), text)
    text = LINK.sub(lambda m: hold(f"[url={m.group(2)}]{_inline(m.group(1), held)}[/url]"), text)
    text = INLINE_CODE.sub(lambda m: f"[b]{m.group(1)}[/b]", text)
    text = BOLD.sub(r"[b]\1[/b]", text)
    text = ITALIC_STAR.sub(r"[i]\1[/i]", text)
    return ITALIC_UNDERSCORE.sub(r"[i]\1[/i]", text)


def convert_inline(text):
    held = []
    text = _inline(text, held)
    while "\x00" in text:
        text = re.sub("\x00(\\d+)\x00", lambda m: held[int(m.group(1))], text)
    return text


def _item(text):
    checkbox = CHECKBOX.match(text)
    if checkbox:
        mark = CHECKED if checkbox.group(1) != " " else UNCHECKED
        text = mark + " " + text[checkbox.end():]
    return "[*]" + convert_inline(text)


def _reject_unsupported(line, number):
    if INDENTED_ITEM.match(line):
        raise ConversionError(number, "nested lists are not supported by Steam, flatten the list")
    if TABLE_ROW.match(line):
        raise ConversionError(number, "tables are not supported, use a list")
    if HTML_TAG.search(line):
        raise ConversionError(number, "HTML is not supported, write Markdown")


def convert(markdown):
    lines = markdown.replace("\r\n", "\n").split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    output = []
    open_block = None
    in_code = False

    def close_block():
        nonlocal open_block
        if open_block:
            output.append(f"[/{open_block}]")
            open_block = None

    def open_list(kind):
        nonlocal open_block
        if open_block != kind:
            close_block()
            output.append(f"[{kind}]")
            open_block = kind

    for number, line in enumerate(lines, start=1):
        if FENCE.match(line):
            if in_code:
                output.append("[/code]")
            else:
                close_block()
                output.append("[code]")
            in_code = not in_code
            continue
        if in_code:
            output.append(line)
            continue

        _reject_unsupported(line, number)
        bullet, numbered, quote = BULLET.match(line), NUMBERED.match(line), QUOTE.match(line)
        heading = HEADING.match(line)

        if bullet:
            open_list("list")
            output.append(_item(bullet.group(1)))
        elif numbered:
            open_list("olist")
            output.append(_item(numbered.group(1)))
        elif quote:
            open_list("quote")
            output.append(convert_inline(quote.group(1)))
        else:
            close_block()
            if RULE.match(line):
                output.append("[hr][/hr]")
            elif heading:
                level = len(heading.group(1))
                output.append(f"[h{level}]{convert_inline(heading.group(2))}[/h{level}]")
            else:
                output.append(convert_inline(line))

    if in_code:
        raise ConversionError(len(lines), "a code block is never closed")
    close_block()
    return output
