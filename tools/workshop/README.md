# Workshop publishing tools

One source for the Workshop page and one for the change notes, so nothing is copied by hand into the game's uploader. Python 3, standard library only.

| Source (edit this) | Generates |
| ------------------ | --------- |
| `workshop/description.md` (Markdown subset) | the `description=` lines of `workshop.txt` (Steam BBCode) |
| `workshop/item.json` (id, title, tags, visibility) | the other fields of `workshop.txt` |
| `CHANGELOG.md` (Keep a Changelog layout) | the Workshop change note, the GitHub release notes, a check against `mod.info` |

`workshop.txt` is generated and committed, never edit it by hand.

## Publishing a release

1. Move the entries of `## [Unreleased]` in `CHANGELOG.md` under a new `## [X.Y.Z] - YYYY-MM-DD` heading and set `modversion` in `mod.info` to `X.Y.Z`. `python3 tools/workshop/build.py draft` lists the merged `feat` and `fix` commits since the last tag as a starting point.
2. Edit `workshop/description.md` if the page changes (the roadmap, for example).
3. `python3 tools/workshop/build.py build`, then `python3 tools/workshop/build.py check`.
4. `python3 tools/workshop/build.py changenote --version X.Y.Z --copy` puts the change note on the clipboard (`wl-copy`, `xclip` or `xsel`). Without `--copy` it is printed.
5. Run `sync-mods.sh release maelstroms-music` from the workspace folder (it copies like `sync` but leaves out `GeneratedRadios.txt` and `_radios_manifest.txt`, which the game generates from the maintainer's addons and must not be uploaded), open the game's Workshop uploader (Mods > Workshop > Update existing item): the title, description, tags and visibility are filled from `workshop.txt`. On the change note step, paste the clipboard.
6. After the upload succeeded, tag with `git tag -a vX.Y.Z` when asked, run a normal `sync-mods.sh` again and start the game twice so it regenerates the two files. For GitHub release notes, `python3 tools/workshop/build.py release-notes --version X.Y.Z`.

## The Markdown subset

Steam does not understand Markdown, so the converter accepts a small subset and fails with a line number on anything else.

| Write | Becomes |
| ----- | ------- |
| `# A`, `## B`, `### C` | `[h1]`, `[h2]`, `[h3]` |
| `**bold**`, `*italic*`, `_italic_` | `[b]`, `[i]` |
| `` `code` `` | bold (Steam has no inline code) |
| `[text](url)`, `![alt](url)` | `[url=...]`, `[img]` (an image inside a link works) |
| `- item`, `* item`, `1. item` | `[list]` and `[olist]` with `[*]` |
| `- [x] item`, `- [ ] item` | an item starting with a check mark or an empty box |
| `---` | `[hr][/hr]` |
| `> quote` | `[quote]` |
| fenced block | `[code]` |
| `\*` `\[` `\]` | the literal character |

Line breaks are kept exactly as written, so there is no paragraph reflow. A blank line ends a list or a quote. Tables, nested lists and HTML are rejected.

## What the game's uploader does (verified in `WorkshopSubmitScreen.lua` and `SteamWorkshopItem`)

- `workshop.txt` is read for `id`, `title`, `description` (one `description=` line per line), `tags` (`;` separated), `visibility` (`public`, `friendsOnly`, `private`, `unlisted`) and `version`. Lines starting with `#` or `//` are comments.
- The uploader shows those values in editable fields and rewrites `workshop.txt` from them before uploading, so the file may differ from the generated one after an upload. Run `build` again.
- There is no change note key. The change note can only be typed or pasted into the dialog.
- On upload the game appends `Workshop ID: <id>` and `Mod ID: <id>` lines to the description. Do not write them in `description.md`.
- The uploaded folder is `<item>/Contents` and the preview is `<item>/preview.png`. Valid tags are the lines of `media/WorkshopTags.txt` in the game folder, and `build.py` rejects any other.
- Whether Steam renders BBCode in the change note field is not documented. If it shows the tags literally, use `changenote --plain`.

## Optional: skipping the dialog with SteamCMD

Not implemented, recorded in [ADR 0010](../../docs/adr/0010-workshop-page-from-single-sources.md) with the reasons.
