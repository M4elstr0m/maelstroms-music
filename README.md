<h1 align="center">Maelstrom's Music</h1>

<p align="center">
  <img src="https://github.com/user-attachments/assets/641cb970-4a26-46cf-a925-2c4c2bb90a3f" width="140" alt="Maelstrom's Music icon">
</p>

<p align="center"><em>Because the apocalypse deserves a soundtrack.</em></p>

#

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/Project%20Zomboid-Build%2042.20%2B-2b2b2b.svg" alt="Project Zomboid Build 42.20+">
  <img src="https://img.shields.io/badge/formats-mp3%20%7C%20ogg%20%7C%20wav-2b2b2b.svg" alt="Supported formats: mp3, ogg, wav">
</p>

A Project Zomboid mod that turns your own mp3/ogg/wav files into fully tunable radio stations, TV channels, an adaptive background soundtrack, and a custom main menu theme — no audio editing, no sound-bank hacking, just files in folders.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Adding a Radio Station or TV Channel](#adding-a-radio-station-or-tv-channel)
- [Custom Background Soundtrack](#custom-background-soundtrack)
- [Main Menu Theme](#main-menu-theme)
- [Limitations](#limitations)
- [Credits](#credits)
- [License](#license)

## Features

- **Unlimited custom radio stations and TV channels** — no hard cap. Add as many as you like; new devices automatically get a random spread across the frequency range instead of always the same first few, so large libraries stay fresh across playthroughs.
- **Adaptive background soundtrack** — replace the vanilla OST with your own, scored on the same 0–10 "drama" scale the game already uses, so it reacts to danger exactly like vanilla music does.
- **Custom main menu theme** — a single track that carries seamlessly through the loading screen into gameplay, with a smooth fade instead of a hard cut.
- **Distance-based volume** — handheld radios, car radios, and stationary devices all fade naturally with distance, the same engine that powers vanilla radio/TV.
- **Optional fade-ins** — any station or channel can ease in instead of starting at full volume; backgrounds and the menu theme always do.
- **Zero audio engineering** — just drop files in a folder next to a small JSON file. No sound-bank replacement, no engine files touched.

## Installation

1. Download or clone this repository.
2. Copy the whole folder into your Project Zomboid `mods` directory, e.g. `Zomboid/mods/MaelstromsMusic/`.
3. Enable **Maelstrom's Music** from the in-game Mods menu and restart.

That's it — the mod ships with an example radio station so you'll hear something immediately. Everything below is about adding your own.

## Adding a Radio Station or TV Channel

Radio stations and TV channels use the exact same convention — radio stations live in `common/media/radios/`, TV channels live in `common/media/televisions/`. Everything below applies to either; just swap the folder.

1. Create a JSON file describing the station, e.g. `common/media/radios/example.json`:

   ```json
   {
       "title": "Example Radio",
       "shuffle": true,
       "fade": true
   }
   ```

   | Field | Type | Required | Default | Description |
   |---|---|---|---|---|
   | `title` | string | Yes | — | Name shown in-game. |
   | `shuffle` | boolean | No | `false` | `false` plays tracks in order, looping back to the start. `true` plays them in random order. |
   | `fade` | boolean | No | `false` | Ease each track in over a couple of seconds instead of starting at full volume. Nice for music, less so for talk radio where you don't want the first words swallowed. |

2. Create a folder with the **exact same name** (no `.json`) next to it: `common/media/radios/example/`.

3. Drop your track files directly into that folder:

   ```txt
   common/media/radios/example/Bouillabaisse - VJazz Relaxing.mp3
   common/media/radios/example/L'art de préparer le parfait - VJazz Relaxing.mp3
   common/media/radios/example/Plat principal - VJazz Relaxing.mp3
   common/media/radios/example/Ratatouille - VJazz Relaxing.mp3
   ```

   `.mp3`, `.ogg` and `.wav` all work.

> [!IMPORTANT]
> The JSON file has to sit **next to** the folder, not inside it — this is a limitation of what Project Zomboid's mod scripting API can see, not a stylistic choice. Content must go under the mod's `common/` folder specifically (not `42/`) — that's where the mod's own generated files always end up, and keeping your tracks there guarantees they're found correctly.
>
> **Track filenames must not contain a comma (`,`).** This applies everywhere in this mod — radios, TV channels, backgrounds, and the main menu theme. A comma breaks Project Zomboid's own sound script parser and silently drops that track entirely. If your file came from somewhere with a name like `Song Title, Pt. 2.mp3`, just remove the comma.

### Where to play it

Start the game (or, if it's already running, just leave the main menu and come back once — the mod checks for new stations at boot).

Each station becomes a real, tunable radio channel, and each TV channel becomes a real, tunable TV channel — turn on and scan the Channel dial on any portable radio, HAM radio, car radio, or television, and your content will show up under its title once you land on its frequency. Radio content only shows up on radios, and TV content only shows up on TVs, even though they share the same tuning system under the hood.

Don't like the current track? Press "Tune In" again on the same frequency to skip to a new one.

If something you just added doesn't show up yet, restart the game once — new sounds are normally picked up without a restart, but this is a safety net in case that doesn't happen on your setup.

## Custom Background Soundtrack

This replaces the game's own adaptive music with your own — no device, no tuning, it just plays automatically based on the situation.

1. Create a JSON file, e.g. `common/media/backgrounds/action.json`:

   ```json
   {
       "title": "Action",
       "drama": 8,
       "shuffle": true
   }
   ```

   | Field | Type | Required | Default | Description |
   |---|---|---|---|---|
   | `title` | string | Yes | — | Name for your reference. |
   | `drama` | number (0–10) | Yes | — | `0` is completely calm, `10` is overwhelmed and being chased — the exact same scale vanilla already scores its own music by, based on how many zombies are visible or chasing you. A track scored `8` kicks in around the same intensity vanilla's own tense tracks would. |
   | `shuffle` | boolean | No | `false` | Same meaning as for stations. |

2. Create a folder with the **exact same name** next to it, and drop your tracks in — identical convention to radio stations and TV channels:

   ```txt
   common/media/backgrounds/action/Chase Theme.mp3
   common/media/backgrounds/action/Last Stand.mp3
   ```

You can add as many `drama`-scored folders as you want (calm exploration music at `1`–`2`, tense-but-safe at `4`–`5`, full combat at `9`–`10`, etc.) — the mod continuously checks the situation and switches to whichever folder's `drama` value is closest to what's actually happening, then plays a track from it (cycling through or shuffling, per that folder's own `shuffle` setting) until the situation changes enough to warrant switching again.

Background tracks always ease in and out rather than cutting, so switching moods, or a nearby radio taking over, sounds like a transition instead of a hard stop. There's no `fade` setting here — it's always on.

> [!NOTE]
> While you have at least one background track defined, vanilla's own adaptive soundtrack is silenced so the two don't play over each other. **If `backgrounds/` is empty, this whole system stays off and the vanilla soundtrack plays exactly as normal** — nothing is disabled unless you actually add content.

## Main Menu Theme

Replace the music that plays on the main menu with a single track of your own — no JSON needed, just the file:

```txt
common/media/mainmenu/My Theme.mp3
```

That's it. Drop exactly one `.mp3`, `.ogg`, or `.wav` file in `common/media/mainmenu/`, and it replaces the vanilla main menu music — and the vanilla loading-screen music with it, so your theme carries you all the way from the menu through the loading screen without anything playing underneath it. It eases in when you reach the menu and eases back out once your game starts, so nothing cuts abruptly. If the folder is empty, the vanilla menu and loading music play as normal. If you drop in more than one file, the mod just picks one (alphabetically first) and ignores the rest.

## Limitations

- **No cross-player sync:** in multiplayer, two players tuned to the same station may hear different tracks from it at the same moment (each player's game picks independently — still only ever tracks from that station's own folder).
- **Large libraries:** with very large libraries (100+ tracks across everything combined), only the first 100 get pre-loaded at boot to keep memory use in check — anything beyond that just loads the first time it's actually played instead, which may cause a brief pause on that first play.

## Credits

The dynamic-channel and distance-based fade approach this mod is built on was learned from **TrueMusicRadio**, a Project Zomboid mod that pioneered tunable custom radio stations. A few techniques and code patterns here started as adaptations of ideas from that mod. Big thanks to its author for figuring that out first.

Example Radio music by VJazz Relaxing from Pixabay.

## License

Released under the [MIT License](LICENSE).
