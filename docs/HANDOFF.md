# Handoff

Where the project stands, what is verified, and what comes next. Update this file at the end of every working session. Decisions and their reasoning are in [adr/README.md](adr/README.md), verified engine facts in [ENGINE_NOTES.md](ENGINE_NOTES.md).

## Snapshot (2026-10-16)

- Version `1.1.0` released on 2026-10-15: Workshop item updated with `tools/workshop/steam_publish.py` (the game's uploader cannot ask its confirmation box on this Linux setup, ADR 0010), tag `v1.1.0` pushed, GitHub release created from the strict template. Never move a pushed tag.
- The maintainer works on Arch Linux. The game is under `~/Games/Steam`, user data in `~/Zomboid`. The workspace folder that contains this repository and the addon repositories has `sync-mods.sh`, run it after every change (ADR 0002). Own published Workshop items are unsubscribed while testing.
- Addons live next to this repository: `maelstroms-music-fallout-radio-addon` (radio stations), `maelstroms-music-rdr-addon` and `maelstroms-music-tlou-addon` (backgrounds, main menu, the TLOU one also ships the game over track "Grieving"). They are not git repositories except this one.

## What exists

Radios and TV channels (engine 3D, ADR 0003), adaptive background soundtrack, main menu theme carried through loading, game over music (ADR 0006), mod options page (ADR 0007), addon system and `mergeTracks` and `sequences` (ADR 0001), device lifecycle (ADR 0004), vanilla music suppression (ADR 0005).

## Verified in game by the maintainer

Menu theme and suppression, options persistence, background pause sliders, hide example station, TV pickup, voice preview, game over music and its volume, Quit to Menu with a radio playing, picking up and placing a radio keeping its track, no `require` warnings, radios and TVs at their true position with muffling through walls, and stereo safe positioning (ADR 0009) in the isometric view and in Viewpoint first person: pan, muffling, no more silence ahead or behind. The loading screen overlap (PR 37) is only mitigated.

## Stereo safe positioning (ADR 0009)

Root cause of "silent dead ahead and behind" on the maintainer's Linux machine: the game mixes in 5.1 and FMOD's PulseAudio output keeps only the front left and right speakers (`tools/fmod-lab/stage_probe.py`). Opt-in setting: a left and a right emitter per device 40 degrees to each side, equal power pan, placed on squares with the same engine occlusion as the real one so the muffling stays, with the closest square plus a volume make up when none matches, per frame smoothing and a glide between squares. Code: `Playback/Occlusion.lua`, `Stage.lua`, `Staging.lua`, `ListenerFrame.lua`, wiring in `Device.lua` and `Tick.lua`, option in `Options.lua`. The listener frame is automatic: the engine screen vector, or `getLookAngleRadians()` while Viewpoint's first or third person view is active (`Viewpoint.View.next()`). Known limits: behind a wall the muffling of a radio behind the player may be lighter than in front when no square of the same rating exists in the audible arc; third person pan under Viewpoint is approximate. Not verified on Windows or macOS (the default path is the base game's own 3D sound; the option is the fallback).

## Open issues

- 10: Viewpoint spatialization. Expected to work with true positions, needs a test. FMOD alone only dips 3 dB straight ahead or behind (offline probe), a bigger dip would come from occlusion (`isCouldSee`, Viewpoint patches vision) and should be investigated with the probes and the log.
- 1: vanilla music mixing with the mod (older report), 2: multiplayer generated script mismatch (expected, not fixable from the mod).
- The loading screen overlap cannot be fully closed from Lua (ADR 0005).

## Working notes

- Offline checks: `luac5.1 -p` on every Lua file, `lua5.1 tools/lua-tests/playback_test.lua` (stubbed engine: placed, picked up, adopted, TV staying removed, car radio changing state), and `tools/fmod-lab` for anything about sound.
- The permission classifier blocks `git reset --hard`, `git stash`, a `for` loop around `gh pr merge`; use follow up commits and one merge per command. A GitHub 502 can leave a merge stuck "in progress" for about a minute.
- Written output follows the maintainer's global rules: no em dash, no spaced hyphen as a connector, no attribution lines, anonymized content.
