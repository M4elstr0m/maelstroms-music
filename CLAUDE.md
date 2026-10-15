# Maelstrom's Music

Project Zomboid (Build 42) Lua mod that turns user audio files (mp3, ogg, flac, wav) into tunable radio stations, TV channels, an adaptive background soundtrack and a main menu theme. Content is declared with a JSON file plus a sibling folder, no custom UI. Other Workshop mods plug in as "addons" with the same convention (see `ADDONS.md`).

The mod ID is `maelstromsmusic`. The Lua namespace is the single global `MaelstromMusic`.

Deeper engine knowledge (quirks, confirmed limitations, reverted approaches) lives in @docs/ENGINE_NOTES.md. Read it before touching anything audio related.

## Repository layout

```txt
Contents/mods/maelstroms-music/
  42/mod.info, 42/media/lua/{shared,client,server}/   Lua source (Build 42 only)
  common/media/{radios,televisions,backgrounds,mainmenu,deaths}/   user content (JSON + folders)
workshop.txt, preview.png    Steam Workshop item metadata (repo root, outside Contents/)
README.md, ADDONS.md         user and addon author documentation
docs/                        developer notes (not shipped to the Workshop)
```

Only `Contents/` is uploaded to the Workshop. Everything else in the repo is development material.

## Architecture map

- `shared/Namespace.lua`: the `MaelstromMusic` table, directory names, shared constants (`FREQ_STEP`, `AUDIOFILE_EXTENSIONS`).
- `shared/Json.lua`: hand written JSON decoder (the Lua sandbox has none).
- `shared/Fs.lua`: file access through `getModFileReader`, `listFilesInModDirectory`, `getModFileWriter`.
- `shared/Frequency.lua`: deterministic frequency assignment (hash plus linear probing over a universal band then an extended band). Fixed `frequency` values are reserved first.
- `shared/Scanner/`: `Scanner.lua` discovers stations from the base mod and addons, merges `mergeTracks` stations, assigns frequencies and regenerates the sound script when the manifest changed. `Station.lua` validates one JSON file. `Manifest.lua` builds the generated sound script, the diffable manifest and the runtime station tables (including `sequences` gating).
- `shared/Addons/`: addon discovery (`getActivatedMods`, `require=maelstromsmusic`, `maelstroms-music-addon.json` marker with `apiVersion`).
- `client/Sound.lua`: thin wrapper over an FMOD emitter with manual fades.
- `client/Playback/`: radio and TV engine. `Hooks.lua` wraps vanilla radio actions and preset loading, `Device.lua` starts tracks (2 track lookahead), `Tick.lua` handles range, volume and track end, `Discovery.lua` finds powered devices near the player, `Warmup.lua` pre-decodes tracks, `Cache.lua` and `DeviceRange.lua` hold state helpers.
- `client/Backgrounds/`: `Director.lua` is the adaptive soundtrack state machine, `Mood.lua` computes the 0 to 10 drama value from zombie counts.
- `client/MainMenu.lua`: main menu theme, carried through the loading screen.
- `client/VanillaMusic.lua`: claim based suppression of the vanilla soundtrack.
- `client/DeathMusic.lua`: plays the pooled game over tracks on player death, at the music volume.
- `client/VoicePreview.lua`: detects the character creation voice preview so the menu theme can step aside.
- `client/Options.lua`: the mod options page (`PZAPI.ModOptions`) and typed accessors for its values.
- `server/Channels.lua`: registers each station as a `DynamicRadioChannel`.

Design principles: never modify base game files, work through Lua and generated sound scripts only, keep content declarative (JSON plus folders), prefer opt-in behaviour over opt-out when an action could silently discard an author's configuration.

## Code standards

The code must always be clean and professional.

- No comments, except a short line explaining a non-obvious WHY (hidden engine constraint, workaround, subtle invariant). Never describe what the code does. No commented-out code, no TODO markers, no debug leftovers.
- Self-documenting names. Functions are small and do one thing. Prefer guard clauses over deep nesting.
- Follow the existing style: 4 space indentation, double quotes, `local` for everything that is not part of the public namespace, constants in `UPPER_SNAKE_CASE` at the top of the file, one module per file under the `MaelstromMusic.<Area>.<Module>` hierarchy, `require` lines at the top.
- Wrap calls into engine APIs that can fail in `MaelstromMusic.Safe.call` and report through `MaelstromMusic.Log.write`. Do not swallow errors silently.
- Folder names are lowercase. Documentation uses GitHub callouts (`> [!NOTE]`, `> [!IMPORTANT]`, `> [!CAUTION]`) and tables, matching the existing README.
- Keep the scope of a change exactly what was asked. No drive-by refactors.
- Never use an em dash or a spaced hyphen as a clause connector in code, docs, commit messages or PR text.

Lua runs on Kahlua (a Lua 5.1 style VM embedded in the game), not stock Lua:

- Java collections are zero based and accessed with `:size()` and `:get(i)`.
- You cannot assign to a public Java field (`obj.field = value` throws). Use a method.
- Avoid `next()`. Use `pairs` with an early return instead.
- `ZombRand(a, b)` excludes `b`.
- `getCore():getOptionMusicVolume()` is an integer from 0 to 10, divide by 10 before passing it to FMOD.
- A mod toggle or "Quit to Menu" reloads the entire Lua VM and wipes every Lua table. State that must survive lives on Java singletons.

## Working method

1. Analyse first. For a bug or a non-trivial feature, investigate, then present findings and a short plan, and wait for confirmation before editing. Small, precisely scoped edits do not need ceremony.
2. Do not guess engine behaviour. Decompile the game and read the bytecode (see "Decompiling the game"). Do not hesitate to do this, it is how most real root causes were found.
3. After a fix, state its blast radius on the other audio systems (radios, backgrounds, main menu). Several early fixes regressed other systems.
4. Check @docs/ENGINE_NOTES.md "Approaches that failed" before proposing a design, to avoid repeating a dead end.
5. Syntax check every edited Lua file: `luac5.1 -p <file>`. There is no automated test suite, so verify behaviour in game and read the console log.

## Decompiling the game

The game is a Java application and its API is not documented. When behaviour is unclear, read the engine. The tooling is a JDK (`jdk-openjdk` on Arch Linux) and `binutils`.

```bash
# locate the game jar: <steam-library>/steamapps/common/ProjectZomboid/projectzomboid/projectzomboid.jar
# steam libraries are listed in ~/.local/share/Steam/steamapps/libraryfolders.vdf
JAR=<path to projectzomboid.jar>

javap -p -c -cp "$JAR" zombie.SoundManager | less        # bytecode of one class
javap -p -cp "$JAR" fmod.fmod.FMODSoundEmitter           # members only
unzip -p "$JAR" zombie/SoundManager.class | strings      # string constants of a class
strings <game dir>/natives/libfmod.so | grep -i flac     # which codecs the native audio library contains
```

To find which class uses a string or event name, scan the jar for it with a short script (read every `.class` entry from the zip and test for the bytes). The vanilla Lua sources are plain text under `projectzomboid/media/lua/` and the vanilla sound scripts under `projectzomboid/media/scripts/`, grep them freely.

Write scratch material (extracted classes, throwaway scripts) outside the repo.

## Git and GitHub workflow

Every `feat` or `fix` has its own issue, its own branch and its own pull request.

- Branch from an up to date `main`, named `<type>/<short-slug>`, for example `feat/bgm-gap-setting` or `fix/tv-pickup-sound`. Types: `feat`, `fix`, `docs`, `refactor`, `perf`, `chore`.
- Commit messages follow Conventional Commits: `type(scope): imperative summary`, lowercase, at most 72 characters, no trailing period. Scopes in use: `playback`, `backgrounds`, `mainmenu`, `deaths`, `scanner`, `addons`, `frequency`, `options`, `docs`. Add a body when the why is not obvious.
- Keep commits atomic and small: roughly 200 changed lines at most per commit. If a change is larger, split it into a logical series (for example engine change, then UI, then docs).
- A pull request links its issue (`Closes #<n>`), summarises the change and lists the in game steps used to verify it. One concern per pull request.
- Never add a `Co-Authored-By` trailer, and never add a "Generated with Claude Code" line or any similar attribution, in commits or pull request descriptions.
- Line endings are LF. If every file suddenly shows as modified, it is a line ending problem, normalise it instead of committing the noise.
- Run `git commit`, `git push` and `gh` commands only when explicitly asked to in the current session. Never touch the contents of the Steam Workshop or the local game mod folders to "sync" changes, the maintainer deploys manually or with a sync script described below.
- The repository is public. Do not commit usernames, home directory paths, machine names, tokens or personal information. Use `~` and placeholders in docs.

## Local development and Workshop layout (Linux)

- The game user directory is `~/Zomboid`. Workshop upload staging items live in `~/Zomboid/Workshop/<item>/` and mirror this repository root: `workshop.txt`, `preview.png`, `Contents/mods/<mod id>/{42,common}`. `~/Zomboid/Workshop/ModTemplate` is the reference layout.
- Subscribed Workshop items are installed under `<steam-library>/steamapps/workshop/content/108600/<workshop id>/mods/<mod id>/`.
- The active mod list is `~/Zomboid/mods/default.txt`. Logs are `~/Zomboid/console.txt` and `~/Zomboid/Logs/`.
- A mod ID must exist only once. If the maintainer is subscribed to their own published item, unsubscribe it (or disable it) while testing a local copy, otherwise two copies with the same ID compete.
- Never symlink a mod into `~/Zomboid/Workshop` or `~/Zomboid/mods`. The game resolves mod directories with `getCanonicalFile()` when it loads scripts, so a mod reached through a symlink loses its script files and its sounds stay silent (see @docs/ENGINE_NOTES.md).
- Edit in this repository and deploy by copying `Contents/`, `workshop.txt` and `preview.png` into `~/Zomboid/Workshop/<item>/` as real files, with a small sync script kept outside the repository. The files the game generates at runtime (`GeneratedRadios.txt`, `_radios_manifest.txt`) must survive a sync.

## Related repositories

Sibling folders next to this repository hold the addons that depend on it: `maelstroms-music-fallout-radio-addon`, `maelstroms-music-rdr-addon`, `maelstroms-music-tlou-addon` and a throwaway `testaddon`. They contain only JSON and audio, no Lua. Keep the addon API (`apiVersion` in the marker file) backward compatible, and bump it deliberately when the contract changes.
