<!-- markdownlint-disable MD033 -->
<!-- markdownlint-disable MD041 -->

# Maelstrom's Music - Addon Guide

For Workshop mod authors who want to ship their own radio stations, TV channels, background soundtrack, or main menu theme that plugs directly into [Maelstrom's Music](README.md), without asking players to do anything beyond subscribing to both mods.

## How it works

Maelstrom's Music scans every currently active Workshop mod at boot. Any mod that declares itself as an addon (see below) gets scanned using the exact same JSON+folder convention as the base mod's own `common/media/...` folders. Your content shows up as real, tunable stations right alongside everyone else's.

## Setting it up

> [!CAUTION]
> The following steps **ARE NOT** optional.

1. **Declare the dependency** in your addon's `mod.info`:

   ```txt
   require=maelstromsmusic
   ```

   This makes Steam Workshop pull in Maelstrom's Music automatically when someone subscribes to your addon, and guarantees load order.

2. **Add the marker file** at `common/maelstroms-music-addon.json` in your mod:

   ```json
   {
       "addon": "maelstroms-music-addon",
       "apiVersion": 1
   }
   ```

   This is what actually tells Maelstrom's Music to scan your mod's folders, without it, your content is ignored even if you use the right folder names. `apiVersion` lets this contract evolve later without silently breaking existing addons; if a future version of Maelstrom's Music no longer supports `1`, your addon will be skipped with a clear log line instead of failing unpredictably.

3. **Add your content** using the exact same convention as the [main README](README.md):

   - `common/media/radios/<Name>.json` + `common/media/radios/<Name>/` for radio stations
   - `common/media/televisions/<Name>.json` + `common/media/televisions/<Name>/` for TV channels
   - `common/media/backgrounds/<Name>.json` + `common/media/backgrounds/<Name>/` for a background soundtrack
   - `common/media/mainmenu/<file>` for a main menu theme

   Same field names (`title`, `shuffle`, `fade`, `drama`), same rules (comma-free filenames, JSON sitting next to the folder rather than inside it, `.mp3`/`.ogg`/`.wav` only).

## What merges, and what doesn't

- **Radio stations and TV channels always merge.** Every active addon's stations are added alongside the base mod's own and everyone else's - that's the entire point of this system. Frequencies are assigned automatically across everything combined, so you never need to coordinate frequency numbers with anyone.
- **Background soundtrack and main menu theme are exclusive.** Only one active source gets to supply each of these - mixing two unrelated background soundtracks or two main menu themes together wouldn't sound intentional, so only one wins. The base mod's own `common/media/backgrounds/` or `common/media/mainmenu/` always takes priority if the player has set one up themselves; otherwise, whichever addon's mod ID sorts first alphabetically wins, and every other contender is skipped with a clear log line explaining why. If your addon's background soundtrack or menu theme isn't playing, check the console log for that message first - it means another mod won that slot, not that something is broken.

## Avoiding folder-name collisions

Station identity (for merge/frequency purposes) is based on your mod ID plus your station's folder name, so two different addons naming a station folder the same thing won't collide with each other internally. However, Project Zomboid resolves audio file paths across *all* active mods by relative path, regardless of which mod owns them. If your addon and someone else's addon (or the base mod's own bundled `example` station) happen to use an identically named station folder (e.g. two addons both using `chill`), the audio files themselves can end up resolving to the wrong mod's files. Use a distinctive folder name for your stations - e.g. prefixed with your addon's own name - to avoid this entirely.

## A minimal example

```txt
YourAddonMod/
├── mod.info                                  (require=maelstromsmusic)
└── common/
    ├── maelstroms-music-addon.json
    └── media/
        └── radios/
            ├── your-addon-jazz.json
            └── your-addon-jazz/
                └── Track One.mp3
```

`your-addon-jazz.json`:

```json
{
    "title": "Jazz FM",
    "shuffle": true
}
```

That's it, no Lua required, just files in folders.

## Wanna see it in action?

Just download the [first Maelstrom's Music addon ever made]()!
