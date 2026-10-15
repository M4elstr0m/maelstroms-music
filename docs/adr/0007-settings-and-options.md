# 0007 Settings through the mod options page

Status: Accepted

## Decision

- Settings are client side and per player, on the game's own `PZAPI.ModOptions` page. `client/Options.lua` creates the page, moves it to the front of `PZAPI.ModOptions.Data` (pages are otherwise listed in mod load order), calls `PZAPI.ModOptions:load()` itself (the game only does it when the options screen is built) and exposes typed accessors. Labels live in `Translate/EN/UI.json`; a `%` in a label makes `Translator.getText` throw and aborts the whole Mods page.
- Hide the example station: filtered where presets are injected (`Hooks.lua`), existing presets are removed from devices that already received them. The station stays tunable by frequency, so no other frequency shifts and multiplayer is unaffected. Addon authors get an `autoPreset` JSON field for the same purpose.
- Background pause: two sliders in seconds (default 30 to 80, which is the old 1800 to 4800 ticks at 60 per second), measured with `getTimestampMs()` so it no longer depends on the frame rate.
- Values read from the saved file were verified against the real vanilla `ModOptions.lua` with a stubbed file reader (the vanilla writer ends lines with `\r\n`, the game's reader strips it).
