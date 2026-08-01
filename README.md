<!-- markdownlint-disable MD033 -->
<!-- markdownlint-disable MD041 -->
<!-- markdownlint-disable MD036 -->
<!-- markdownlint-disable MD049 -->
<!-- markdownlint-disable MD028 -->

## <h1 align="center">Maelstrom's Music</h1>

<p align="center"><em>Because the apocalypse deserves a soundtrack.</em></p>

<div align="center">

![Visitor Badge](https://visitor-badge.laobi.icu/badge?page_id=M4elstr0m.maelstroms-music&left_text=Visitors&right_color=orange)
![Stars Badge](https://img.shields.io/github/stars/M4elstr0m/maelstroms-music?style=flat&color=yellow&label=Stars)
![License Badge](https://img.shields.io/badge/License-MIT-lightgrey)
![PZ Version Badge](https://img.shields.io/badge/Project%20Zomboid%20Version-42.20%2B-blue)

</div>

<p align="center">
  <img src="https://github.com/user-attachments/assets/641cb970-4a26-46cf-a925-2c4c2bb90a3f" width="140" alt="Maelstrom's Music icon">
</p>

---

## <p align="center">Please [star](https://github.com/M4elstr0m/maelstroms-music/stargazers) this repository if you find it useful ⭐</p>

<h6>
A Project Zomboid mod that turns your own mp3/ogg/wav files into fully tunable radio stations, TV channels, an adaptive background soundtrack, and a custom main menu theme.

No strange audio editing, no additional UIs, no sound-bank hacking, just audio files in mod folders.
</h6>

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Adding a Radio Station or TV Channel](#adding-a-radio-station-or-tv-channel)
- [Custom Background Soundtrack](#custom-background-soundtrack)
- [Main Menu Theme](#main-menu-theme)
- [Addon Mods](#addon-mods)
- [Limitations](#limitations)
- [Credits](#credits)
- [License](#license)

## Features

One mod to rule them all. It should basically gather every music mods in one.

> [!IMPORTANT]
> Without any addon installed, this mod only adds on his own a sample radio station with 4 free-of-use jazzy music.

- **Unlimited custom radio stations and TV channels**: Add as many as you like. New devices automatically get a random spread across the frequency range instead of always the same first few, so large libraries does not always show the first hundreds.
- **Adaptive background soundtrack**: replace the vanilla OST with your own, scored on the same 0–10 "drama" scale the game already uses, so it reacts to danger exactly like vanilla music does.
- **Custom main menu theme**: a single track that carries seamlessly through the loading screen into gameplay, with a smooth fade instead of a hard cut.
- **Distance-based volume**: handheld radios, car radios, and stationary devices all fade naturally with distance, the same engine that powers vanilla radio/TV.
- **Zero audio engineering**: just drop files in a folder next to a small JSON file. No sound-bank replacement, no base game files touched.

## Installation

1. Download the mod from the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3775149796).
2. Enable **Maelstrom's Music** from the in-game Mods menu.
3. [_Optional_] Restart your game to prevent unexpected bugs

> [!NOTE]
> The mod ships with an example radio station so you'll hear something immediately.

Everything below is about adding your own music to the game.

## Adding a Radio Station or TV Channel

> [!IMPORTANT]
> The `common/` folder mentioned below should be located in your Steam Workshop mod folder : `C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3773911887\mods\maelstroms-music\common\`

Radio stations and TV channels use the exact same convention: radio stations live in `common/media/radios/`, TV channels live in `common/media/televisions/`. Everything below applies to either; just swap the folder.

1. Create a JSON file describing the station, e.g. `common/media/radios/example.json`:

   ```json
   {
       "title": "Example Radio",
       "shuffle": true,
       "fade": true
   }
   ```

   | Field       | Type    | Required | Default | Description                                                                                                                                                            |
   | ----------- | ------- | -------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
   | `title`     | string  | Yes      | None    | Name shown in-game.                                                                                                                                                    |
   | `shuffle`   | boolean | No       | `false` | `false` plays tracks in order, looping back to the start. `true` plays them in random order.                                                                           |
   | `fade`      | boolean | No       | `false` | Ease each track in over a couple of seconds instead of starting at full volume. Nice for music, less so for talk radio where you don't want the first words swallowed. |
   | `frequency` | number  | No       | None    | Pin the station to an exact frequency (in MHz, e.g. `95.4`) instead of letting the mod assign one automatically. See [Manual Frequencies](#manual-frequencies) below.  |

2. Create a folder with the **exact same name** as the JSON file (without `.json` extension) next to it: `common/media/radios/example/`.

3. Drop your track files directly into that folder:

   ```txt
   common/media/radios/example/Bouillabaisse - VJazz Relaxing.mp3
   common/media/radios/example/L'art de préparer le parfait - VJazz Relaxing.mp3
   common/media/radios/example/Plat principal - VJazz Relaxing.mp3
   common/media/radios/example/Ratatouille - VJazz Relaxing.mp3
   ```

   `.mp3`, `.ogg` and `.wav` all work.

> [!CAUTION]
> **Track filenames must not contain a comma (`,`).** This applies everywhere in this mod: radios, TV channels, backgrounds, and the main menu theme. A comma breaks Project Zomboid's own sound script parser and silently drops that track entirely. If your file came from somewhere with a name like `Song Title, Pt. 2.mp3`, just remove the comma.

### Usage

Vanilla radios or TVs now feature your custom channels, just select the right channel and press the "Tune In" button.

Don't like the current track? Press "Tune In" again on the channel to skip to a new one.

> [!IMPORTANT]
> If something you just added doesn't show up yet, restart the game.

### Manual Frequencies

By default, every station is auto-assigned a frequency and automatically added as a preset on every radio/TV, so it's ready to listen to the moment you turn the device on. If you'd rather have players discover a station by scanning the dial themselves instead of it just showing up as a preset (cool for roleplay), give it a fixed `frequency` in its JSON:

```json
{
    "title": "Mystery Broadcast",
    "shuffle": true,
    "fade": true,
    "frequency": 95.4
}
```

Any station with a `frequency` field is pinned to that exact spot (matching what you'd see on an in-game dial, e.g. `95.4`) and is **not** auto-added as a preset - the player has to tune to it manually, or save their own preset once they find it. Stations without a `frequency` field are auto-assigned and auto-presetted.

> [!CAUTION]
> Changing or removing an existing station's `frequency` moves it, which can orphan presets players already saved on that station in an ongoing save. Pick a fixed frequency deliberately and try to stick with it once players are using it.

> [!IMPORTANT]
> Please set an **even** frequency. Otherwise, you will not be able to manually enter frequencies such as `95.5`, which cannot be selected.

## Custom Background Soundtrack

This replaces the game's own adaptive music with your own, it just plays automatically based on the situation.

1. Create a JSON file, e.g. `common/media/backgrounds/action.json`:

   ```json
   {
       "title": "Action",
       "drama": 8,
       "shuffle": true
   }
   ```

   | Field     | Type          | Required | Default | Description                                                                                                                                                                                                                                                               |
   | --------- | ------------- | -------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
   | `title`   | string        | Yes      | None    | Name for your reference.                                                                                                                                                                                                                                                  |
   | `drama`   | number (0–10) | Yes      | None    | `0` is completely calm, `10` is overwhelmed and being chased. The exact same scale vanilla already scores its own music by, based on how many zombies are visible or chasing you. A track scored `8` kicks in around the same intensity vanilla's own tense tracks would. |
   | `shuffle` | boolean       | No       | `false` | Same meaning as for stations.                                                                                                                                                                                                                                             |

2. Create a folder with the **exact same name** next to it, and drop your tracks in. Identical convention to radio stations and TV channels:

   ```txt
   common/media/backgrounds/action/Chase Theme.mp3
   common/media/backgrounds/action/DOOM OST.mp3
   ```

You can add as many `drama`-scored folders as you want (calm exploration music at `1`–`2`, tense-but-safe at `4`–`5`, full combat at `9`–`10`, etc.). The mod continuously checks the situation and switches to whichever folder's `drama` value is closest to what's actually happening, then plays a track from it (cycling through or shuffling, per that folder's own `shuffle` setting) until the situation changes enough to warrant switching again.

Background tracks always ease in and out rather than cutting, so switching moods, or a nearby radio taking over, sounds like a transition instead of a hard stop. There's no `fade` setting here, it's always on.

> [!IMPORTANT]
> While you have at least one background track defined, vanilla's own adaptive soundtrack is silenced so the two don't play over each other. **If `backgrounds/` is empty, this whole system stays off and the vanilla soundtrack plays exactly as normal**, nothing is disabled unless you actually add content.

## Main Menu Theme

Replace the music that plays on the main menu with a single track of your own. No JSON needed, just the file:

```txt
common/media/mainmenu/My Theme.mp3
```

That's it. Drop exactly one `.mp3`, `.ogg`, or `.wav` file in `common/media/mainmenu/`, and it replaces the vanilla main menu music.

## Addon Mods

Other Workshop mod authors can ship their own radio stations, TV channels, background soundtrack, or main menu theme in a **separate** mod that plugs directly into Maelstrom's Music. Players just subscribe to both, no manual file copying involved.

> [!NOTE]
> This section is for mod authors publishing their own addon. If you're just adding your own music to your own game, you don't need any of this, in that case, see the sections above.

At boot, Maelstrom's Music scans every other active mod that:

1. Declares `require=maelstromsmusic` in its `mod.info`.
2. Ships a `common/maelstroms-music-addon.json` marker file:

   ```json
   {
       "addon": "maelstroms-music-addon",
       "apiVersion": 1
   }
   ```

Any mod meeting both conditions gets scanned using the exact same `common/media/radios|televisions|backgrounds|mainmenu` convention described above.

- **Radio stations and TV channels always merge.** Every active addon's stations are added alongside the base mod's own and everyone else's, with frequencies assigned automatically across everything combined.
- **Background soundtrack and main menu theme are exclusive.** Only one active source supplies each. The base mod's own `backgrounds/`/`mainmenu/` wins if the player set one up themselves; otherwise the first addon (alphabetically by mod ID) wins, and every other contender is skipped with a clear line in the console log explaining why.

> [!CAUTION]
> Project Zomboid resolves audio files by relative path across *all* active mods. If two addons (or an addon and the base mod's own `example` station) use an identically named station folder, one can silently shadow the other's audio. Use a distinctive folder name for your stations.

See [ADDONS.md](ADDONS.md) for the full addon creation guide.

## Limitations

- **No cross-player sync:** in multiplayer, two players tuned to the same station may hear different tracks from it at the same moment (each player's game picks independently since it is based on local folders).
- **Large libraries:** with very large libraries (100+ tracks across everything combined), only the first 100 get pre-loaded at boot to keep memory use in check. Anything beyond 100, just loads the first time it's actually played instead, which may cause a brief lag on that first play.

## Roadmap

- [x] Steam Workshop addon system - see [Addon Mods](#addon-mods)
- [ ] Add "Loading addons..." pop-up on game load
- [ ] Add delay between Main Menu music replays
- [ ] Improve Background music transitions & moods
- [ ] Display music title when it starts playing on radio

## Credits

- The dynamic-channel and distance-based fade approach this mod is built on was learned from **[TrueMusicRadio](https://steamcommunity.com/sharedfiles/filedetails/?id=3631572046)**, a Project Zomboid mod that featured tunable custom radio stations. A few techniques here started as adaptations of ideas from that mod. Big thanks to its author for figuring that out first.
- The background music feature was inspired by **[The Last Of Us Peace Music](https://steamcommunity.com/sharedfiles/filedetails/?id=2864373983)**
- Example Radio musics were made by **VJazz Relaxing** from Pixabay.

## License

Released under a [MIT License (Non-Commercial Variant)](LICENSE) license.
