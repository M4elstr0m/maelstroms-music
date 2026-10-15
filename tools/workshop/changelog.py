"""Reads CHANGELOG.md (Keep a Changelog layout) and drafts entries from conventional commits."""
import re

RELEASE = re.compile(r"^## \[([^\]]+)\](?: - (\d{4}-\d{2}-\d{2}))?\s*$")
GROUP = re.compile(r"^### (.+?)\s*$")
ITEM = re.compile(r"^- (.+)$")
COMMIT = re.compile(r"^(?P<type>[a-z]+)(?:\((?P<scope>[^)]+)\))?!?: (?P<summary>.+)$")
DRAFT_GROUPS = {"feat": "Added", "fix": "Fixed", "perf": "Changed", "refactor": "Changed"}
GROUP_ORDER = ("Added", "Changed", "Fixed", "Removed")
UNRELEASED = "Unreleased"


class Release:
    def __init__(self, version, date):
        self.version = version
        self.date = date
        self.groups = {}

    def is_empty(self):
        return not any(self.groups.values())


def parse(text):
    releases, release, group = [], None, None
    for line in text.replace("\r\n", "\n").split("\n"):
        match = RELEASE.match(line)
        if match:
            release, group = Release(match.group(1), match.group(2)), None
            releases.append(release)
            continue
        match = GROUP.match(line)
        if match and release:
            group = release.groups.setdefault(match.group(1), [])
            continue
        match = ITEM.match(line)
        if match and group is not None:
            group.append(match.group(1))
    return releases


def select(releases, version=None):
    if version:
        for release in releases:
            if release.version == version:
                return release
        raise LookupError(f"no section for version {version} in the changelog")
    for release in releases:
        if release.version != UNRELEASED or not release.is_empty():
            return release
    raise LookupError("the changelog has no entries")


def latest_released(releases):
    for release in releases:
        if release.version != UNRELEASED:
            return release
    return None


def ordered_groups(release):
    names = [name for name in GROUP_ORDER if name in release.groups]
    names += [name for name in release.groups if name not in GROUP_ORDER]
    return [(name, release.groups[name]) for name in names if release.groups[name]]


def change_note_markdown(release):
    title = "Upcoming changes" if release.version == UNRELEASED else f"Version {release.version}"
    lines = [f"**{title}**"]
    for name, items in ordered_groups(release):
        lines.append("")
        lines.append(f"**{name}**")
        lines.extend(f"- {item}" for item in items)
    return "\n".join(lines) + "\n"


def release_notes_markdown(release):
    lines = []
    for name, items in ordered_groups(release):
        lines.append(f"### {name}")
        lines.extend(f"- {item}" for item in items)
        lines.append("")
    return "\n".join(lines).rstrip("\n") + "\n"


def draft(subjects):
    groups = {}
    for subject in subjects:
        match = COMMIT.match(subject.strip())
        if not match or match.group("type") not in DRAFT_GROUPS:
            continue
        summary = match.group("summary")
        entry = summary[0].upper() + summary[1:]
        groups.setdefault(DRAFT_GROUPS[match.group("type")], []).append(entry)
    release = Release(UNRELEASED, None)
    release.groups = groups
    return release_notes_markdown(release) if groups else ""
