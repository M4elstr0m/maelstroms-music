"""Builds workshop.txt and the change note from the single sources.

usage: python3 tools/workshop/build.py [build|check|changenote|release-notes|github-release|draft] [--version X] [--plain] [--copy] [--title]

  build          write workshop.txt from workshop/item.json and workshop/description.md
  check          fail when workshop.txt is stale or the changelog does not match mod.info
  changenote     print the change note as Steam BBCode, or as plain text with --plain (--copy puts it on the clipboard)
  release-notes  print the changelog section as Markdown for a GitHub release
  github-release print the body of the GitHub release page from workshop/github-release.md (--title prints its title)
  draft          list the merged feat and fix commits since the last tag as changelog entries
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bbcode
import changelog

ROOT = Path(__file__).resolve().parents[2]
ITEM = ROOT / "workshop" / "item.json"
DESCRIPTION = ROOT / "workshop" / "description.md"
CHANGELOG = ROOT / "CHANGELOG.md"
RELEASE_TEMPLATE = ROOT / "workshop" / "github-release.md"
WORKSHOP_TXT = ROOT / "workshop.txt"
MOD_INFO = next((ROOT / "Contents" / "mods").glob("*/42/mod.info"), None)

WORKSHOP_TXT_VERSION = 1
VISIBILITIES = ("public", "friendsOnly", "private", "unlisted")
ALLOWED_TAGS = (
    "Build 40", "Build 41", "Build 42", "Animals", "Audio", "Balance", "Building", "Clothing/Armor", "Farming", "Food",
    "Framework", "Hardmode", "Interface", "Items", "Language/Translation", "Literature", "Map", "Military", "Misc",
    "Models", "Multiplayer", "Pop Culture", "Realistic", "Silly/Fun", "Skills", "Textures", "Traits", "Vehicles", "QoL",
    "WIP", "Weapons",
)


class BuildError(Exception):
    pass


def load_item():
    item = json.loads(ITEM.read_text(encoding="utf-8"))
    if not re.fullmatch(r"\d+", str(item.get("id", ""))):
        raise BuildError("workshop/item.json: id must be the numeric Workshop id")
    if not item.get("title"):
        raise BuildError("workshop/item.json: title is required")
    unknown = [tag for tag in item.get("tags", []) if tag not in ALLOWED_TAGS]
    if unknown:
        raise BuildError(f"workshop/item.json: tags the game does not offer: {', '.join(unknown)}")
    if item.get("visibility") not in VISIBILITIES:
        raise BuildError(f"workshop/item.json: visibility must be one of {', '.join(VISIBILITIES)}")
    return item


def description_lines():
    try:
        return bbcode.convert(DESCRIPTION.read_text(encoding="utf-8"))
    except bbcode.ConversionError as error:
        raise BuildError(f"workshop/description.md: {error}") from error


def render_workshop_txt(item, lines):
    header = [
        f"version={WORKSHOP_TXT_VERSION}",
        f"id={item['id']}",
        f"title={item['title']}",
    ]
    footer = [
        f"tags={';'.join(item.get('tags', []))}",
        f"visibility={item['visibility']}",
    ]
    return "\n".join(header + [f"description={line}" for line in lines] + footer) + "\n"


def load_releases():
    return changelog.parse(CHANGELOG.read_text(encoding="utf-8"))


def change_note(version=None, plain=False):
    try:
        release = changelog.select(load_releases(), version)
    except LookupError as error:
        raise BuildError(str(error)) from error
    markdown = changelog.change_note_markdown(release)
    if plain:
        return markdown.replace("**", "")
    return "\n".join(bbcode.convert(markdown)) + "\n"


def release_notes(version=None):
    try:
        release = changelog.select(load_releases(), version)
    except LookupError as error:
        raise BuildError(str(error)) from error
    return changelog.release_notes_markdown(release)


def mod_version():
    match = re.search(r"^modversion=(.+)$", MOD_INFO.read_text(encoding="utf-8"), re.MULTILINE)
    return match.group(1).strip()


def release_title():
    return f"v{mod_version()} - {load_item()['title']}"


def release_body():
    return RELEASE_TEMPLATE.read_text(encoding="utf-8").replace("{{title}}", release_title())


def check_changelog_matches_mod_info():
    latest = changelog.latest_released(load_releases())
    if latest is None or latest.version != mod_version():
        found = latest.version if latest else "none"
        raise BuildError(f"mod.info is at {mod_version()} but the newest released changelog section is {found}")


def build_text():
    return render_workshop_txt(load_item(), description_lines())


def copy_to_clipboard(text):
    for command in (["wl-copy"], ["xclip", "-selection", "clipboard"], ["xsel", "--clipboard", "--input"]):
        if shutil.which(command[0]):
            subprocess.run(command, input=text.encode("utf-8"), check=True)
            return command[0]
    raise BuildError("no clipboard tool found (wl-copy, xclip or xsel), print it and copy it by hand")


def draft_entries():
    tags = subprocess.run(["git", "-C", str(ROOT), "describe", "--tags", "--abbrev=0"], capture_output=True, text=True)
    revisions = f"{tags.stdout.strip()}..HEAD" if tags.returncode == 0 else "HEAD"
    log = subprocess.run(["git", "-C", str(ROOT), "log", "--first-parent", "--format=%s", revisions],
                         capture_output=True, text=True, check=True)
    return changelog.draft(log.stdout.splitlines())


def run(arguments):
    if arguments.command == "build":
        WORKSHOP_TXT.write_text(build_text(), encoding="utf-8", newline="\n")
        print(f"wrote {WORKSHOP_TXT.relative_to(ROOT)}")
    elif arguments.command == "check":
        if not WORKSHOP_TXT.exists() or WORKSHOP_TXT.read_text(encoding="utf-8") != build_text():
            raise BuildError("workshop.txt is stale, run: python3 tools/workshop/build.py build")
        check_changelog_matches_mod_info()
        print("workshop.txt is up to date and the changelog matches mod.info")
    elif arguments.command == "changenote":
        note = change_note(arguments.version, arguments.plain)
        print(note, end="")
        if arguments.copy:
            print(f"copied with {copy_to_clipboard(note)}", file=sys.stderr)
    elif arguments.command == "release-notes":
        print(release_notes(arguments.version), end="")
    elif arguments.command == "github-release":
        print(release_title() if arguments.title else release_body(), end="\n" if arguments.title else "")
    elif arguments.command == "draft":
        print(draft_entries(), end="")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", nargs="?", default="build", choices=("build", "check", "changenote", "release-notes", "github-release", "draft"))
    parser.add_argument("--version")
    parser.add_argument("--plain", action="store_true")
    parser.add_argument("--copy", action="store_true")
    parser.add_argument("--title", action="store_true")
    try:
        run(parser.parse_args())
    except BuildError as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
