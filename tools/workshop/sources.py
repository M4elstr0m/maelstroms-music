"""The single sources of the Workshop page (item.json, description.md, CHANGELOG.md, mod.info) and what is rendered from them."""
import json
import re
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
    """Raised for a problem in the sources, reported without a stack trace."""
    pass


def load_item():
    """Loads and validates workshop/item.json."""
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
    """Converts workshop/description.md to the BBCode lines of the description."""
    try:
        return bbcode.convert(DESCRIPTION.read_text(encoding="utf-8"))
    except bbcode.ConversionError as error:
        raise BuildError(f"workshop/description.md: {error}") from error


def render_workshop_txt(item, lines):
    """Renders workshop.txt in the field order the game's uploader writes."""
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
    """Parses CHANGELOG.md."""
    return changelog.parse(CHANGELOG.read_text(encoding="utf-8"))


def change_note(version=None, plain=False):
    """Renders the change note of a version (default: the newest) as BBCode, or as plain text."""
    try:
        release = changelog.select(load_releases(), version)
    except LookupError as error:
        raise BuildError(str(error)) from error
    markdown = changelog.change_note_markdown(release)
    if plain:
        return markdown.replace("**", "")
    return "\n".join(bbcode.convert(markdown)) + "\n"


def release_notes(version=None):
    """Renders the release notes of a version (default: the newest) as Markdown."""
    try:
        release = changelog.select(load_releases(), version)
    except LookupError as error:
        raise BuildError(str(error)) from error
    return changelog.release_notes_markdown(release)


def mod_version():
    """The modversion declared in mod.info."""
    match = re.search(r"^modversion=(.+)$", MOD_INFO.read_text(encoding="utf-8"), re.MULTILINE)
    return match.group(1).strip()


def release_title():
    """The GitHub release title: the version and the Workshop title."""
    return f"v{mod_version()} - {load_item()['title']}"


def release_body():
    """The GitHub release page, from its template with the title filled in."""
    return RELEASE_TEMPLATE.read_text(encoding="utf-8").replace("{{title}}", release_title())


def check_changelog_matches_mod_info():
    """Raises when the newest released changelog section is not the version in mod.info."""
    latest = changelog.latest_released(load_releases())
    if latest is None or latest.version != mod_version():
        found = latest.version if latest else "none"
        raise BuildError(f"mod.info is at {mod_version()} but the newest released changelog section is {found}")


def build_text():
    """The full content workshop.txt should have."""
    return render_workshop_txt(load_item(), description_lines())
