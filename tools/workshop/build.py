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
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import changelog
import sources


def copy_to_clipboard(text):
    """Copies text with the first clipboard tool found and returns its name."""
    for command in (["wl-copy"], ["xclip", "-selection", "clipboard"], ["xsel", "--clipboard", "--input"]):
        if shutil.which(command[0]):
            subprocess.run(command, input=text.encode("utf-8"), check=True)
            return command[0]
    raise sources.BuildError("no clipboard tool found (wl-copy, xclip or xsel), print it and copy it by hand")


def draft_entries():
    """Drafts changelog entries from the conventional commits since the last tag."""
    tags = subprocess.run(["git", "-C", str(sources.ROOT), "describe", "--tags", "--abbrev=0"], capture_output=True, text=True)
    revisions = f"{tags.stdout.strip()}..HEAD" if tags.returncode == 0 else "HEAD"
    log = subprocess.run(["git", "-C", str(sources.ROOT), "log", "--first-parent", "--format=%s", revisions],
                         capture_output=True, text=True, check=True)
    return changelog.draft(log.stdout.splitlines())


def run(arguments):
    """Runs the command chosen on the command line."""
    if arguments.command == "build":
        sources.WORKSHOP_TXT.write_text(sources.build_text(), encoding="utf-8", newline="\n")
        print(f"wrote {sources.WORKSHOP_TXT.relative_to(sources.ROOT)}")
    elif arguments.command == "check":
        if not sources.WORKSHOP_TXT.exists() or sources.WORKSHOP_TXT.read_text(encoding="utf-8") != sources.build_text():
            raise sources.BuildError("workshop.txt is stale, run: python3 tools/workshop/build.py build")
        sources.check_changelog_matches_mod_info()
        print("workshop.txt is up to date and the changelog matches mod.info")
    elif arguments.command == "changenote":
        note = sources.change_note(arguments.version, arguments.plain)
        print(note, end="")
        if arguments.copy:
            print(f"copied with {copy_to_clipboard(note)}", file=sys.stderr)
    elif arguments.command == "release-notes":
        print(sources.release_notes(arguments.version), end="")
    elif arguments.command == "github-release":
        print(sources.release_title() if arguments.title else sources.release_body(), end="\n" if arguments.title else "")
    elif arguments.command == "draft":
        print(draft_entries(), end="")


def main():
    """Parses the command line and runs the command, turning a BuildError into an exit code."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", nargs="?", default="build", choices=("build", "check", "changenote", "release-notes", "github-release", "draft"))
    parser.add_argument("--version")
    parser.add_argument("--plain", action="store_true")
    parser.add_argument("--copy", action="store_true")
    parser.add_argument("--title", action="store_true")
    try:
        run(parser.parse_args())
    except sources.BuildError as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
