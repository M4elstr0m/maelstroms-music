# Maelstrom's Music

Because the apocalypse deserves a soundtrack.

Build a themed radio station out of your own mp3/ogg/wav files just by dropping them in a folder next to a small JSON file.

## How to add a station

1. In `media/radios/`, create a file called `<StationName>.json`, e.g.:

   ```txt
   media/radios/queen.json
   ```

   with contents:

   ```json
   {
       "title": "My Radio",
       "shuffle": true
   }
   ```

   - `title` is required — this is the name shown in-game.
   - `shuffle` is optional (default `false` = tracks play in order, looping back to the start; set to `true` to play tracks in random order instead).

2. Create a folder with the **exact same name** (no `.json`) next to it:

   ```txt
   media/radios/queen/
   ```

3. Drop your track files directly into that folder:

   ```txt
   media/radios/queen/Bohemian Rhapsody.mp3
   media/radios/queen/Don't Stop Me Now.mp3
   media/radios/queen/We Will Rock You.mp3
   ```

   `.mp3`, `.ogg` and `.wav` all work.

> **Note:** the JSON file has to sit next to the folder, not inside it — this is a limitation of what Project Zomboid's mod scripting API can see, not a stylistic choice.

## Where to play it

Start the game (or, if it's already running, just leave the main menu and come back once — the mod checks for new stations at boot).

Each station becomes a real, tunable radio channel — turn on and scan the Channel dial on any portable radio, HAM radio, or car radio, and your station will show up under its title once you land on its frequency.

Don't like the current track? Press "Tune In" again on the same frequency to skip to a new one.

If a station you just added doesn't show up yet, restart the game once — new sounds are normally picked up without a restart, but this is a safety net in case that doesn't happen on your setup.

## Limitations

- No cross-player sync: in multiplayer, two players tuned to the same station may hear different tracks from it at the same moment (each player's game picks independently — still only ever tracks from that station's own folder).

## Credits

The dynamic-channel and distance-based fade approach this mod is built on was learned from **TrueMusicRadio**, a Project Zomboid mod that pioneered tunable custom radio stations. A few techniques and code patterns here started as adaptations of ideas from that mod. Big thanks to its author for figuring that out first.

Example Radio music by VJazz Relaxing from Pixabay.
