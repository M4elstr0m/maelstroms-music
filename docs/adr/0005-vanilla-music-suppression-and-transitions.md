# 0005 Vanilla music suppression and transitions

Status: Accepted. The loading screen overlap is only mitigated.

## Decision and reasons

- Vanilla music is muted by claim (`VanillaMusic.lua`): while any module holds a claim, `setMusicVolume(0)` is applied (it sets the FMOD VCA `vca:/Settings_Music`) and re-applied every 50 ms. `MainMenu.lua` and `Director.lua` also re-assert the music state and call `StopMusic()` every frame, because vanilla restarts its music instance on its own. The leak detector in `VanillaMusic.lua` only sees the legacy music instance, it is kept as cheap instrumentation.
- `OnRenderTick` is the only Lua tick that fires in every game state, so the menu theme, its fades and the mute are driven from it.
- The character creation voice preview switches the music state to `InGame` itself and calls `resumeSoundAndMusic()`. The menu theme stops asserting its state and ducks to 30% while `VoicePreview.isPlaying()`, detected by wrapping `CharacterCreationMain:onOptionMouseDown`.
- Leaving the menu runs `MainScreenState.exit()`, which resets the music VCA to the player's option, then `GameLoadingState.enter()` sets the state to `Loading` and runs a long synchronous Lua load during which `OnRenderTick` cannot fire. The mute and the menu state are therefore also re-applied from `OnGameBoot`, `OnPreMapLoad` and `OnLoadRadioScripts`, which do run inside the load. The part of the load before the first of them is still unmuted.
- A mod toggle or Quit to Menu reloads the whole Lua VM. State that must be released lives on the engine side, the modules poll `getPlayer() == nil` on `OnRenderTick` to stop their sounds, because `OnMainMenuEnter` runs after the reset.

## Rejected

- Forcing `Core.setOptionMusicVolume(0)` around the transition would close the loading gap, but `Core.saveOptions` can run at any time and could store 0 as the player's setting.
- Writing `SoundManager.allowMusic` (a Java field; Kahlua cannot assign it, it flooded logs).
- `setMusicState("Loading")` during loading: regressed the mute, the menu state is always `MainMenu`.
- Removing `emitter:tick()` calls to fix the menu crash: silenced everything, the real fix is `is3D = false` on flat sounds.
