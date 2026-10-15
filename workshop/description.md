# Maelstrom's Music
*Because the apocalypse deserves a soundtrack.*

A Project Zomboid mod that lets you turn your own MP3, OGG, FLAC, or WAV files into fully tunable radio stations, TV channels, an adaptive background soundtrack, or a custom main menu theme.
**No complex audio editing, no extra UIs, no sound-bank hacking: just drop audio files in your mod folder or install an addon.** Designed to merge a lot of music related features in a single mod.
**Compatible with [Project Viewpoint](https://steamcommunity.com/sharedfiles/filedetails/?id=3809306528)**, the first person view mod.

**[Github Link 🔗](https://github.com/M4elstr0m/maelstroms-music)**
**If you like my work**, please support it by liking and rewarding this item AND **starring my [Github repository](https://github.com/M4elstr0m/maelstroms-music)** ⭐

---

## Features
One mod to rule them all. It should basically gather every music mods in one.
Without any addon installed, this mod only adds on his own a sample radio station with 4 free-of-use jazzy music.

- **Unlimited Radio & TV Stations:** Add as many as you like! Frequency numbers are randomly spread out so large music libraries won't clump together on lower channels.
- **Adaptive Background OST:** Replaces vanilla background music with your own tracks mapped to the game's dynamic 0–10 "drama" scale (reacts live to zombie threats).
- **Custom Main Menu Theme:** Seamlessly carries your custom menu music through the loading screen into gameplay.
- **Distance-Based Volume:** Handhelds, car stereos, and stationary TVs naturally fade with distance using vanilla audio physics.
- **Zero Engineering Needed (when using addons):** Drop your audio files into a folder alongside a tiny JSON configuration file.

---

## Compatibility & Save Games
- **Save Games:** Safe to add or remove mid-save.
- **Multiplayer:** Fully compatible (Build 42.20+). *Note: Track selection is client-side, so different players tuned into the same station may hear different songs at the same moment.*
- **Other Mods:** Zero vanilla soundbank files are modified, minimizing mod conflicts.

Please report your bugs & suggestions on Github (see above link).

---

## 🔴 Troubleshooting
Radios or TVs go silent when you face them or turn your back to them, or only play on your left and right?
Open **Options > Mods > Maelstrom's Music** and turn on **Stereo safe positioning**.
*Some audio setups (mostly PulseAudio or PipeWire on Linux) drop the centre and rear speakers of the game's surround mix. This option keeps every radio and TV audible from any direction and keeps the muffling through walls.*

---

## Quick Setup Guide
Simply download a Maelstrom's Music Addon (available in Steam Workshop) and enable the concerned mods.
**Or** (if you want to add your own music manually) please refer to the project's [Github](https://github.com/M4elstr0m/maelstroms-music) page for full documentation.

---

## Addon Support for Mod Creators
Creating a music pack mod for Maelstrom's Music?
Please refer to the project's **[Github](https://github.com/M4elstr0m/maelstroms-music)** page for full documentation.

---

## Roadmap
- ✅ v1.0.0 - Steam Workshop addon system - see above
- ✅ v1.0.2 - Optimize loading time, removing start-up lags (gradual loading, can't do better I think for now)
- ✅ v1.0.2 - Improve Background music transitions & moods (drama override & replay on skip)
- ✅ v1.0.3 - Allow multiple addons to share the same radio / TV station with the same config
- ✅ v1.0.3 - Add delay between Main Menu music replays & allow multiple main menu music
- ✅ v1.0.6 - Compatibility with .flac files
- ✅ v1.0.7 - Allow ordering even with shuffle=true
- ✅ v1.1.0 - Fixes for issues reported by users, Options, and Viewpoint Project compatibility
- ⬜ Display music title when it starts playing on radio
- ⬜ [NOT PLANNED FOR NOW] Music VHS and CDs (vanilla integrated)

---

## Credits
- Dynamic channel & fading logic inspired by **[TrueMusicRadio](https://steamcommunity.com/sharedfiles/filedetails/?id=3631572046)**.
- Background drama music concept inspired by **[The Last Of Us Peace Music](https://steamcommunity.com/sharedfiles/filedetails/?id=2864373983)**.
- Sample radio tracks provided by **VJazz Relaxing** (Pixabay).

*Released under MIT License (Non-Commercial Variant).*
*Created by **[M4elstr0m](https://github.com/M4elstr0m)**.*

[![Discord](https://raw.githubusercontent.com/Chuckleberry-Finn/chuckImages/main/PZmodCommBanner3.png)](https://discord.gg/SReMnbV4V7)
