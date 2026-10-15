# 0002 Development loop: real copies, never symlinks

Status: Accepted

## Context

Development moved to Linux. The obvious setup, symlinking each repository into `~/Zomboid/Workshop/<item>`, made every sound silent: the log showed `ScriptManager.Load> Exception thrown` with a `FileNotFoundException` on a lowercased path, Lua kept running so the mod looked alive, and the mod's own "sound is not registered" check could not fire because `GameSounds.getSound` never returns nil (it registers an empty placeholder).

## Decision

- `ScriptManager.Load` resolves each mod directory with `getCanonicalFile()`, lowercases it and relativizes script paths against it, so a mod reached through a symlink cannot load its generated script. Mods are deployed as real copies.
- The workspace folder (outside the repository, not a git repository) keeps `sync-mods.sh [sync|status|remove]`. It copies `Contents/`, `workshop.txt` and `preview.png` of every repository into `~/Zomboid/Workshop/<repo>/` and keeps the files the game generates at runtime (`GeneratedRadios.txt`, `_radios_manifest.txt`). There is no `rsync` on the machine, it uses `cp`.
- The script is run after every change, branch switch, merge or pull, and at the end of every task from an up to date `main`, without being asked. It is the only thing allowed to write into the game folders.
- The maintainer's own published Workshop items must be unsubscribed (or disabled) while testing local copies, two copies with the same mod id compete.
- Sound registration is checked with `GameSounds.isKnownSound` before `getSound`, which makes a missing script a logged error instead of silence.
- Line endings are LF (`.gitattributes`), files copied from a Windows checkout were converted.

## Consequences

Every test needs a sync, and a script change needs the game to be started twice (the first launch regenerates the script, the second loads it).
