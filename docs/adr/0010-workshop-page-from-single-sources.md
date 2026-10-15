# 0010 Workshop page and change notes from single sources

Status: Accepted. The in game uploader stays the publishing step, SteamCMD is recorded as an option.

## Context

Publishing meant copying the mod page by hand into the game's uploader and typing a change note every time, with the description and the changes kept in several places (`workshop.txt`, `README.md`, the dialog, commit history).

What the game does (read from `WorkshopSubmitScreen.lua` and the decompiled `SteamWorkshopItem`):

- `workshop.txt` holds `id`, `title`, `description` (one `description=` line per line, joined with newlines), `tags` (`;` separated, must be in `media/WorkshopTags.txt`), `visibility` and `version`. The uploader pre fills its fields from it and **rewrites it from the fields** before uploading.
- No key carries the change note, it exists only as the text box of the dialog (`setChangeNote`).
- `getSubmitDescription` appends `Workshop ID: <id>` and one `Mod ID: <id>` line per mod to the description.
- The uploaded content is `<item>/Contents`, the preview is `<item>/preview.png`.
- Steam descriptions are BBCode (h1 to h3, b, i, u, strike, spoiler, noparse, hr, url, list, olist, quote, code, and images), not Markdown. Steam documents no table tag.

## Decision

- The Workshop page is written once as `workshop/description.md`, a Markdown subset converted by `tools/workshop/bbcode.py` that rejects what Steam cannot show (tables, nested lists, HTML). The metadata lives in `workshop/item.json`. `workshop.txt` is generated from them and committed, and a test fails when it is stale.
- The changes are written once in `CHANGELOG.md` (Keep a Changelog layout, an `Unreleased` section collects entries between releases). The Workshop change note, the GitHub release notes and the check that the newest released section equals `mod.info`'s `modversion` all read it. `build.py draft` proposes entries from the merged conventional commits since the last tag.
- Publishing remains the game's own dialog: the page is already filled from `workshop.txt`, and the change note is pasted from the clipboard (`changenote --copy`). Nothing leaves the machine through a script, no credentials are handled.
- The generated page was diffed against the one published at the time: identical line for line (one stray blank line in the old roadmap aside).

## SteamCMD, not adopted

`steamcmd +login <user> +workshop_build_item <vdf>` could set title, description, change note, visibility, preview and content without the dialog. Checked against Valve's Steamworks documentation and community guides:

- The VDF keys documented are `appid`, `publishedfileid`, `contentfolder`, `previewfile`, `visibility`, `title`, `description` and `changenote`. There is no documented `tags` key and community reports say SteamCMD does not set tags, so they would stay as last set in the game (omitted keys are left unchanged on an update).
- It needs the Steam account password and a Steam Guard code (a cached session can expire), and Valve describes the tool as for testing.
- The game's appended `Workshop ID` and `Mod ID` lines would have to be reproduced by the script, otherwise server admins lose the Mod ID on the page.
- A wrong run publishes to a public item, and it cannot be tested without doing so.

Revisit if the manual paste of the change note becomes a burden. The generator already produces everything the VDF needs.

## Consequences

The staging folder the uploader reads also contains the files the game generates at runtime, which list the stations of the maintainer's addons. `sync-mods.sh release` copies without them, always use it for an upload.


`workshop.txt` must not be edited by hand and may be rewritten by the game after an upload (run `build`). The roadmap in `description.md` is still maintained by hand, separately from the one in `README.md`. Whether Steam renders BBCode in the change note field is unverified, `changenote --plain` is the fallback.
