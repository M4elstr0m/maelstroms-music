# Engine notes

Verified facts about Project Zomboid Build 42 (tested on 42.20 and 42.21) that shaped this mod. Each item was confirmed by reading the game bytecode or the native libraries, not assumed. Re-verify after a major game update.

## Sound engine

- Every FMOD sound is created paused at volume 0 (`FMOD_System_PlaySound(sound, true)` followed by `FMOD_Channel_SetVolume(channel, 0.0)`). It only becomes audible when `emitter:tick()` runs. `client/Sound.lua` calls `tick()` on purpose, do not remove those calls.
- `GameSound` defaults `is3d` to `true` when a sound script does not set it. In 3D mode `FileSound.tick()` reads `IsoPlayer.getInstance()`, which is null at the main menu, so it throws a `NullPointerException` every frame. Main menu, background and game over sounds therefore set `is3D = false`.
- Radio and TV sounds are the exception, they only play in the world. Without `is3D = true` the engine skips its 3D handling for them (`FileSound.tick` runs it only when `GameSound.is3d` is set and the emitter has a position): no distance based 3D level (it centres a sound within about two thirds of a tile of the listener and pans fully beyond), no `Set3DMinMaxDistance`, no occlusion, no reverb. The result was hard left or right panning and near silence next to a radio. They declare `distanceMin = 30` and `distanceMax = 225`, in units of a third of a tile, so panning softens within ten tiles and the engine adds no attenuation inside that range (the mod's own distance falloff in `Tick.lua` still applies).
- `SCRIPT_SCHEMA_VERSION` in `Manifest.lua` forces existing installs to regenerate the script when the generator output changes.
- `Events.OnRenderTick` is the only Lua tick that fires in every state (menu, loading screen, in game). `Events.OnTick` does not fire at the main menu.
- Fades are manual volume ramps driven by `getTimestampMs()`. The emitter has no fade, position or length API.
- `getCore():getOptionMusicVolume()` returns an integer from 0 to 10. FMOD expects 0 to 1.
- File based sounds cannot seek. `setTimelinePosition` is a no-op for `FileSound`, and there is no position getter or pause call. "Resume" of an interrupted background track therefore replays it from the start.
- `FMODManager.loadSound()` always passes mode `16` (`FMOD_3D`). `FMOD_NONBLOCKING` exists but is unreachable, so decoding a track cannot be made asynchronous. Only the moment it happens can be chosen, which is what `Warmup.lua` does (pre-decode during the loading screen and one track ahead).
- Decoded sounds are cached in `fileToSoundMap` and never evicted except by `reloadSoundFiles()`.
- `GameSounds.getSound(name)` never returns nil, it registers an empty placeholder for an unknown name. Test `GameSounds.isKnownSound(name)` first, and never call `getSound` on a name that may not exist, or the placeholder makes later checks pass.
- A track filename containing a comma breaks the sound script parser (`ArrayIndexOutOfBoundsException` in `GameSoundScript.LoadClip`) and the sound is dropped silently. The scanner skips such files and logs a warning.
- The dial steps in 0.2 MHz, so frequencies are multiples of `FREQ_STEP` (200 in internal units).
- The native FMOD library contains these codecs only: mpeg, oggvorbis, wav, flac, plus module formats. AAC, M4A and Opus cannot be supported. AIFF would be a plausible addition (PCM path).

## Lua environment (Kahlua)

- Public Java fields cannot be assigned from Lua (`obj.field = value` raises "attempted index of non-table"). A direct write to `SoundManager.allowMusic` flooded users' logs and was reverted.
- `next()` is not usable. Java lists are zero based.
- `getModInfo(id)` treats its argument as a directory name. Use `getModInfoByID(id)`.
- `OnModsModified` is a file watcher event, not a "mods toggled" event.
- Toggling a mod or choosing "Quit to Menu" runs `Core.ResetLua()`: all Lua is wiped (`wipeRecurse` destroys nested global tables as well as locals) and reloaded first, then `OnGameBoot`, `OnMainMenuEnter` and `OnResetLua` fire on the fresh environment. Cleanup hooked on `OnMainMenuEnter` therefore runs too late. `Director.lua` and `Tick.lua` poll `getPlayer() == nil` on `OnRenderTick` to release sounds immediately.
- `getModFileWriter` always writes into the mod's `common/` folder, never the versioned folder. Generated files (`GeneratedRadios.txt`, the manifest) live there and are git-ignored.
- `ScriptManager.Load` resolves each mod directory with `getCanonicalFile()`, lowercases it and relativizes script paths against it. A mod directory reached through a symlink therefore cannot load its script files: the log shows `ScriptManager.Load> Exception thrown` with a `FileNotFoundException` on a lowercased path, Lua still runs, and every generated sound is missing.
- A `%%` in a `PZAPI.ModOptions` label makes `Translator.getText` throw (`UnknownFormatConversionException` inside `reportMissingArgumentsFromPastAbuse`), which aborts building the whole Mods options page. Labels and tooltips of this mod must not contain `%`.
- `getActivatedMods`, `getModFileReader` and `listFilesInModDirectory` take an explicit mod ID, so the mod can read files of any active addon without its cooperation.

## Music state and vanilla suppression

- Vanilla music runs through FMOD Studio states `MainMenu`, `Loading` and `InGame`, selected with `setMusicState`. `VanillaMusic.lua` mutes by claim (`setMusicVolume(0)`), while `MainMenu.lua` and `Director.lua` re-assert the state with `setMusicState` and `StopMusic()` every frame.
- Calling `setMusicState("Loading")` during the loading screen regressed the mute (the persistent `MusicCombined` event reacts to the parameter differently than expected). `MainMenu.lua` always uses `"MainMenu"`.
- The character creation voice preview (`CharacterCreationMain:onOptionMouseDown`, button `PLAYDEMOVOICE`) calls `setMusicState("InGame")` and `resumeSoundAndMusic()` itself, with a vanilla `FIXME: main menu music stops when this is set`. The per-frame re-assertion in `MainMenu.lua` fights that call.
- `SoundManager.playMusic(name)` calls `DoMusic(name, loop)`. It returns early when `allowMusic` is false or the music volume option is 0, otherwise picks a random clip of the sound script `name`. A clip with `event` starts an FMOD Studio event, a clip with `file` plays the file through FMOD directly.
- On player death `IsoPlayer.OnDeath` calls `playMusic("PlayerDied")` when all players are dead, then fires `Events.OnPlayerDeath`. Vanilla defines `Base.PlayerDied` with the FMOD event `Game/GameOver`.
- A `file` clip played through `DoMusic` goes straight to a raw FMOD channel with the clip's own volume, so it ignores the music volume option. Overriding `PlayerDied` with file clips therefore plays at full volume. The mod plays game over tracks itself (`client/DeathMusic.lua`, scaled by the option) on `OnPlayerDeath` and calls `StopMusic()`, which stops both the event instance and a file channel of the vanilla stinger.

## Radios and devices

- Cached playback entries (`Playback/Cache.lua`) hold direct references to the device and its `deviceData`. Nothing validates that the device still exists in the world, so a device removed from the world (picked up, destroyed) must be detected explicitly.
- `RWMChannel.readPresets` and `RWMChannelTV.readPresets` are wrapped to inject presets. `ISRadioAction.performSetChannel` is wrapped to start and switch stations.
- Multiplayer: `GeneratedRadios.txt` is regenerated locally from the active addons, so a client and server with different addon sets trip the game's own content integrity check. This is expected and not fixable from the mod.

## Third party interaction

- Viewpoint (first person mod, Workshop id 3809306528) is a ZombieBuddy Java mod. It patches `fmod.fmod.FMODSoundEmitter.tick` and `fmod.fmod.SoundListener.tick` (`Patch_SoundEmitter`, `Patch_SoundListener`) and re-places 3D channels itself in `SoundLift` through `FMOD_Channel_Set3DAttributes`. Any sound whose positioning depends on the isometric player position instead of the active listener will misbehave with it.
- ZombieBuddy mods declare `require=\ZombieBuddy`, `javaJarFile` and `javaPkgName` in `mod.info`. Only one jar per mod. The user is prompted to approve a new or changed jar (policy `prompt`, `deny-new` or `allow-all`), signing is optional. A jar under `media/java/client/` is skipped on dedicated servers. Adding a jar to this mod therefore adds a hard dependency on ZombieBuddy for every player.
- Java classpath is fixed at launch (`ProjectZomboid64.json`), the game itself offers no way for a mod to load jars.

## Steam Workshop

- A published item is loaded from `<steam-library>/steamapps/workshop/content/108600/<id>/mods/<mod id>/`, not from `~/Zomboid/Workshop`. Editing the wrong copy was the cause of several "the fix does not work" reports.
- `workshop.txt` fields are written unconditionally on upload: leaving title, description or tags blank overwrites the live listing. Only the title can be queried back (`querySteamWorkshopItemDetails`), not the description.

## Approaches that failed (do not retry)

- Removing the `emitter:tick()` calls to fix the main menu crash. It silenced every radio, TV and background track. The real fix is `is3D = false`.
- An `ownsEmitter` flag on `Sound.lua`, built on an unverified theory about emitter recycling in `IsoWorld`.
- Writing `SoundManager.allowMusic` directly (see Kahlua above).
- `setMusicState("Loading")` during loading (see music state above).
- Symlinking the repository into `~/Zomboid/Workshop` for local testing. Scripts of a symlinked mod do not load (see Lua environment above), deploy real copies instead.
- Polling `getActivatedMods()` to detect mod toggles. The full Lua reload already re-runs `OnGameBoot`.
- Keeping state on `MaelstromMusic.*` tables to survive a reload. They are wiped too.
- A custom Boombox and vinyl UI tab (original design). It only worked for one item type and cut audio off at range. The `DynamicRadioChannel` per station design replaced it.
- Real mid-track resume, asynchronous loading, unloading played tracks, loading custom jars from the mod, fetching Workshop descriptions. All confirmed impossible from Lua (see above).
- Diagnostic logging for an intermittent lag after several "Quit to Menu" cycles. It could not be reproduced and was reverted. The `checkLeak` log in `VanillaMusic.lua` is intentionally kept as low volume instrumentation.
