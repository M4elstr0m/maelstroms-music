# 0006 Game over music played by the mod

Status: Accepted

## Context

Tracks in `common/media/deaths/` replace the vanilla game over music. The first design overrode the sound script `Base.PlayerDied` with file clips so the engine would keep its timing. `SoundManager.DoMusic` plays a `file` clip on a raw FMOD channel with the clip's own volume, so the music volume option had no effect and the track was far too loud.

## Decision

- Death tracks are pooled across the base mod and addons and generated as ordinary sounds (`BroadcastTrack_death_<n>`), exposed to the client as `MaelstromMusic.DeathStation`.
- `client/DeathMusic.lua` reacts to `Events.OnPlayerDeath`: `StopMusic()` stops the vanilla stinger (it releases both an event instance and a file channel), a random track is played on the UI emitter at `VanillaMusic.optionVolume()`, and a new character (`OnCreatePlayer`) stops it.
- The background director stops its track on death, hands the vanilla music volume back and stays idle until a new character exists, otherwise its per tick mute would silence a vanilla stinger when no custom track exists.
- No on/off setting: removing the files restores the vanilla music.
