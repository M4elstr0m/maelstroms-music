# Handoff

Where the project stands, what is verified, and what comes next. Update this file at the end of every working session. Decisions and their reasoning are in [adr/README.md](adr/README.md), verified engine facts in [ENGINE_NOTES.md](ENGINE_NOTES.md).

## Snapshot (2026-10-16)

- `main` carries everything merged through PR 39 plus the documentation PR that added this file. Mod version `1.0.8` in `mod.info`. The tag `v1.0.8` was created earlier and predates several fixes, so a `v1.0.9` tag (tag only, no GitHub release) is the clean way to mark the current state once the maintainer is happy.
- The maintainer works on Arch Linux. The game is under `~/Games/Steam`, user data in `~/Zomboid`. The workspace folder that contains this repository and the addon repositories has `sync-mods.sh`, run it after every change (ADR 0002). Own published Workshop items are unsubscribed while testing.
- Addons live next to this repository: `maelstroms-music-fallout-radio-addon` (radio stations), `maelstroms-music-rdr-addon` and `maelstroms-music-tlou-addon` (backgrounds, main menu, the TLOU one also ships the game over track "Grieving"). They are not git repositories except this one.

## What exists

Radios and TV channels (engine 3D, ADR 0003), adaptive background soundtrack, main menu theme carried through loading, game over music (ADR 0006), mod options page (ADR 0007), addon system and `mergeTracks` and `sequences` (ADR 0001), device lifecycle (ADR 0004), vanilla music suppression (ADR 0005).

## Verified in game by the maintainer

Menu theme and suppression, options persistence, background pause sliders, hide example station, TV pickup, voice preview, game over music and its volume, Quit to Menu with a radio playing, picking up and placing a radio keeping its track (after PR 32), no `require` warnings.

## Not yet verified in game

- PR 39 (engine 3D again): head turn stereo, muffling through walls, car radio level when getting out, all with and without Viewpoint.
- PR 37 (earlier mute at loading events): how much shorter the vanilla music overlap during loading is.

## Stereo safe positioning (branch `feat/stereo-safe-spatialization`, issue 41)

Root cause of "silent dead ahead and behind" on the maintainer's machine: the game mixes in 5.1 and the PulseAudio output keeps only the front left and right speakers (ADR 0009, `tools/fmod-lab/stage_probe.py`). Implemented as an opt-in setting: a left and a right emitter per device 40 degrees to each side, equal power pan, placed on squares with the same engine occlusion as the real one so the muffle stays. Code: `Playback/Occlusion.lua`, `Stage.lua`, `Staging.lua`, wiring in `Device.lua` and `Tick.lua`, options in `Options.lua`. Offline checks all pass (`occlusion_test.lua`, `stage_test.lua`, `playback_test.lua`). To verify in game: with the setting on, turn around a placed radio (left, centre, right, behind), another room, a car, held radio, toggle the setting while a station plays, with and without Viewpoint (the Player frame uses the character facing, check it is not mirrored). Version target 1.1.0 if it works.

## Open issues

- 10: Viewpoint spatialization. Expected to work with true positions, needs a test. FMOD alone only dips 3 dB straight ahead or behind (offline probe), a bigger dip would come from occlusion (`isCouldSee`, Viewpoint patches vision) and should be investigated with the probes and the log.
- 1: vanilla music mixing with the mod (older report), 2: multiplayer generated script mismatch (expected, not fixable from the mod).
- The loading screen overlap cannot be fully closed from Lua (ADR 0005).

## Working notes

- Offline checks: `luac5.1 -p` on every Lua file, `lua5.1 tools/lua-tests/playback_test.lua` (stubbed engine: placed, picked up, adopted, TV staying removed, car radio changing state), and `tools/fmod-lab` for anything about sound.
- The permission classifier blocks `git reset --hard`, `git stash`, a `for` loop around `gh pr merge`; use follow up commits and one merge per command. A GitHub 502 can leave a merge stuck "in progress" for about a minute.
- Written output follows the maintainer's global rules: no em dash, no spaced hyphen as a connector, no attribution lines, anonymized content.
