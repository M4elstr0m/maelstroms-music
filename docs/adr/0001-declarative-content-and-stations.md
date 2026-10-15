# 0001 Declarative content and one channel per station

Status: Accepted

## Context

The goal is a framework where players and addon authors add radios, TV channels, a background soundtrack, a main menu theme and game over music by dropping audio files in folders, with no Lua and no UI to learn. The first implementation was a custom Boombox and vinyl tab. It only worked for one item type, cut audio off at range and restarted tracks when the player came back, so it was replaced.

## Decision

- Content is a JSON file plus a sibling folder of the same name under `common/media/{radios,televisions,backgrounds,mainmenu,deaths}/`. Addons use the identical convention, discovered through `getActivatedMods`, `require=maelstromsmusic` and a `common/maelstroms-music-addon.json` marker with an `apiVersion`.
- The scanner turns every track into a generated sound script (`GeneratedRadios.txt`) and every radio or TV station into a `DynamicRadioChannel`, so vanilla radios, TVs, car radios and presets work without any custom UI. A manifest text is diffed to know when to regenerate and call `reloadSoundFiles()`. `SCRIPT_SCHEMA_VERSION` forces regeneration when the generator output changes.
- Frequencies are assigned by a deterministic hash with linear probing over a universal band then an extended band, so a station keeps its frequency across restarts. A fixed `frequency` is reserved first. The dial steps in 0.2 MHz.
- `mergeTracks` is opt-in and compares titles, so two addons never merge by accident. `sequences` (before and after) force a track order and gate the "after" tracks; cycles are logged, never silently broken.
- The background soundtrack is exclusive (the base mod wins, then addons by mod id); radios, TVs, the main menu theme and game over music always merge.
- The JSON decoder is hand written because the Lua sandbox has none.

## Consequences

Authors never write Lua. Station identity is mod id plus folder name, but the game resolves audio by relative path across mods, so folder and file names must be distinctive (documented). Track file names must not contain a comma, the sound script parser drops them (the scanner skips and logs them).
