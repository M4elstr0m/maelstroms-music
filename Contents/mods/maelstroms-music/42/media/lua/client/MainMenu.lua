require "Namespace"
require "Safe"
require "VanillaMusic"
require "VoicePreview"
require "MainMenu/Theme"

local Theme = MaelstromMusic.MainMenu.Theme

-- Keeps the FMOD music state on MainMenu and stops vanilla music, except during the voice preview.
local function holdMusicState()
    if MaelstromMusic.VoicePreview.isPlaying() then
        return
    end
    MaelstromMusic.Safe.call("could not hold the main menu music state", function()
        getSoundManager():setMusicState("MainMenu")
        getSoundManager():StopMusic()
    end)
end

-- Activates the theme when the main menu opens.
local function onMainMenuEnter()
    Theme.setActive(true)
end

-- Deactivates the theme and fades it out as the game starts.
local function onGameStart()
    Theme.setActive(false)
    Theme.beginSwap()
end

-- Re-applies the vanilla mute at the early loading events, the only ones that run during the synchronous load.
local function silenceVanillaMusic()
    MaelstromMusic.VanillaMusic.refresh()
    if Theme.wantsMusic() then
        holdMusicState()
    end
end

-- Per frame: completes the fade out, starts the next track after its gap, detects the end of a track.
local function onRenderTick()
    MaelstromMusic.VanillaMusic.refresh()

    if Theme.isFadingOut() then
        Theme.updateFadeOut()
        if Theme.wantsMusic() then
            holdMusicState()
        end
        return
    end

    if not Theme.wantsMusic() or not MaelstromMusic.ScanComplete then
        return
    end
    holdMusicState()

    if not Theme.isLoaded() then
        if Theme.isDue(getTimestampMs()) then
            Theme.start()
        end
        return
    end

    Theme.sustain()
end

Theme.reset()

Events.OnMainMenuEnter.Add(onMainMenuEnter)
Events.OnGameStart.Add(onGameStart)
Events.OnGameBoot.Add(silenceVanillaMusic)
Events.OnPreMapLoad.Add(silenceVanillaMusic)
Events.OnLoadRadioScripts.Add(silenceVanillaMusic)
Events.OnRenderTick.Add(onRenderTick)
