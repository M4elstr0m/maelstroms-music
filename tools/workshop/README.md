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
5. Run `sync-mods.sh release maelstroms-music` from the workspace folder (on the maintainer's Linux machine use `steam_publish.py` instead of the game's uploader, see "Publishing without the game's dialog") (it copies like `sync` but leaves out `GeneratedRadios.txt` and `_radios_manifest.txt`, which the game generates from the maintainer's addons and must not be uploaded), open the game's Workshop uploader (Mods > Workshop > Update existing item): the title, description, tags and visibility are filled from `workshop.txt`. On the change note step, paste the clipboard.
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
- The uploader shows those values in editable fields and rewrites `workshop.txt` from them before uploading, in the order `version`, `id`, `title`, `description`, `tags`, `visibility`, which is the order `build.py` writes, so the file only differs after an upload if a field was edited in the dialog. Edit the sources instead and run `build` again.
- There is no change note key. The change note can only be typed or pasted into the dialog.
- On upload the game appends `Workshop ID: <id>` and `Mod ID: <id>` lines to the description. Do not write them in `description.md`.
- The uploaded folder is `<item>/Contents` and the preview is `<item>/preview.png`. Valid tags are the lines of `media/WorkshopTags.txt` in the game folder, and `build.py` rejects any other.
- Whether Steam renders BBCode in the change note field is not documented. If it shows the tags literally, use `changenote --plain`.

## Publishing without the game's dialog

The game's uploader asks for a confirmation through an operating system message box before it does anything (`TinyFileDialogs`, "WARNING: Steam Workshop upload requested!"). Inside the Steam Linux runtime that box most likely never appears, the call returns false and the screen says "error requesting Steam to update the item" without a single Steam request being made (reasoning and evidence in [ADR 0010](../../docs/adr/0010-workshop-page-from-single-sources.md)). `steam_publish.py` makes the same Steam calls through the game's own `libsteam_api.so` and the Steam session that is logged in (no password), then submits and prints Steam's `EResult` (1 is OK, anything else is Steam's reason).

1. `sync-mods.sh release maelstroms-music`, immediately before the next step. A running game regenerates `GeneratedRadios.txt` and `_radios_manifest.txt` inside the upload folder, and the script refuses to run while they are there.
2. `python3 tools/workshop/steam_publish.py` is a dry run: it prints the item, the title and the sizes, prepares the update and submits nothing.
3. `python3 tools/workshop/steam_publish.py --submit` publishes the title, description (with the `Workshop ID` and `Mod ID` lines the game would append), tags, visibility, content, preview and the change note of the `mod.info` version. Only the changed files are transferred.

`PZ_NATIVES` points at the game's `natives` folder when the game is not in the default Steam library. SteamCMD is not used.

## The GitHub release

The page of a release keeps one strict layout, kept in `workshop/github-release.md` (four centred headings: the version and item title, the tagline, the star request, the Workshop link) with no changelog in the body. `build.py github-release` prints the body and `--title` prints the title (`v<mod.info version> - <item title>`). After the Workshop upload and the tag:

```bash
gh release create vX.Y.Z --verify-tag --latest --title "$(python3 tools/workshop/build.py github-release --title)" --notes "$(python3 tools/workshop/build.py github-release)"
```
