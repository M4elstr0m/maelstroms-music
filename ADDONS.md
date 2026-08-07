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

   Same field names (`title`, `shuffle`, `fade`, `drama`, `frequency`, `mergeTracks`), same rules (comma-free filenames, JSON sitting next to the folder rather than inside it, `.mp3`/`.ogg`/`.flac`/`.wav` only).

## What merges, and what doesn't

- **Radio stations and TV channels always merge.** Every active addon's stations are added alongside the base mod's own and everyone else's - that's the entire point of this system. Frequencies are assigned automatically across everything combined, so you never need to coordinate frequency numbers with anyone - unless you pin one with `frequency` (see the main README's [Manual Frequencies](README.md#manual-frequencies) section), in which case it's checked for collisions against every other source too; if two stations (from any source, including the base mod) pin the same spot, one falls back to auto-assignment instead, logged clearly so you know it happened.
- **Main menu themes always merge.** Every active source's `common/media/mainmenu/` track(s) are pooled together into one big playlist and played in random order (never the same one twice in a row), with a 10-second pause between tracks, for as long as the player sits at the main menu. You can drop in more than one file yourself too, addon or not - it's not limited to "one file per source."
- **Background soundtrack is exclusive.** Only one active source gets to supply it - mixing two unrelated background soundtracks together wouldn't sound intentional, so only one wins. The base mod's own `common/media/backgrounds/` always takes priority if the player has set one up themselves; otherwise, whichever addon's mod ID sorts first alphabetically wins, and every other contender is skipped with a clear log line explaining why. If your addon's background soundtrack isn't playing, check the console log for that message first - it means another mod won that slot, not that something is broken.

## Sharing tracks with another station

Normally, every station (from every source) stays separate, even if two of them happen to have the same `title` - that's treated as a coincidence, not an instruction to combine them.

If you actually want your addon to add more tracks to an existing station (yours or someone else's) instead of creating a competing one, set `"mergeTracks": true` in your station's JSON **and** use the exact same `title` (case-insensitive) as the station you're adding to:

```json
{
    "title": "Jazz FM",
    "shuffle": true,
    "mergeTracks": true
}
```

Every active station with `mergeTracks: true` and that title (radio only merges with radio, TV only with TV - never with each other) is folded into one station with every contributor's tracks combined, on one shared frequency. Whichever source is found first (the base mod, then addons in mod ID order) keeps its own station ID and its own `shuffle`/`fade`/`frequency` settings for the merged station - if your JSON's settings differ from theirs, yours are simply ignored for the merge, only your tracks are used. Only `mergeTracks: true` stations are ever affected by this - if the field is missing or `false`, your station never merges with anything, regardless of what its title is.

Merging is decided purely by the `title` field - your station's JSON filename and folder should still be different from theirs. See [Avoiding folder-name collisions](#avoiding-folder-name-collisions) below: reusing someone else's folder name doesn't help the merge and can make your files, or theirs, resolve to the wrong audio.

## Avoiding folder-name collisions

Station identity (for merge/frequency purposes) is based on your mod ID plus your station's folder name, so two different addons naming a station folder the same thing won't collide with each other internally. However, Project Zomboid resolves audio file paths across *all* active mods by relative path, regardless of which mod owns them. If your addon and someone else's addon (or the base mod's own bundled `example` station) happen to use an identically named station folder (e.g. two addons both using `chill`), the audio files themselves can end up resolving to the wrong mod's files. Use a distinctive folder name for your stations - e.g. prefixed with your addon's own name - to avoid this entirely.

This still applies even when using [`mergeTracks`](#sharing-tracks-with-another-station): only the `title` field is compared to decide whether stations merge - the folder name and JSON filename are never part of that check, and can (and should) stay unique per station regardless. Two stations merging into one shared "Jazz FM" don't need matching folder names to do it - e.g. `your-addon-jazz.json` + `your-addon-jazz/` merging with someone else's `their-jazz.json` + `their-jazz/` works exactly the same as if the folder names matched, without the collision risk described above.

> [!CAUTION]
> `common/media/mainmenu/` has no per-station subfolder to fall back on - every active source's files sit directly in that same folder name across every mod. Since main menu themes always merge (see above), give your mainmenu track(s) distinctive filenames too, not just your radio/TV folders - if your addon and someone else's addon both ship a file literally named `Theme.mp3`, one can silently shadow the other's audio the same way a folder-name collision would.

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

Just download the [first Maelstrom's Music addon ever made](https://steamcommunity.com/sharedfiles/filedetails/?id=3775264398)!
