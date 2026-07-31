require "Namespace"
require "Log"
require "Safe"
require "Sound"
require "VanillaMusic"

MaelstromMusic.MainMenu = {}

local CLAIM_KEY = "mainmenu"
local FADE_IN_MS = 3000
local FADE_OUT_MS = 2500
local RESTART_GRACE_MS = 1500

local sound = nil
local active = false
local stopping = false
local startedAt = 0

local function play()
    if not sound then
        sound = MaelstromMusic.Sound:new()
        sound:set3D(false)
    end
    sound:setVolume(MaelstromMusic.VanillaMusic.optionVolume())
    sound:setFadeLevel(0)
    sound:play(MaelstromMusic.MainMenuTrack)
    sound:fadeTo(1, FADE_IN_MS)
    startedAt = getTimestampMs()
end

local function holdMusicState()
    MaelstromMusic.Safe.call("could not hold the main menu music state", function()
        getSoundManager():setMusicState("MainMenu")
        getSoundManager():StopMusic()
    end)
end

local function finish()
    if sound then
        MaelstromMusic.Safe.call("could not stop the main menu theme", function()
            sound:stop()
        end)
        sound = nil
    end
    active = false
    stopping = false
    MaelstromMusic.VanillaMusic.claim(CLAIM_KEY, false)
    MaelstromMusic.VanillaMusic.refresh()
end

local function onMainMenuEnter()
    if not MaelstromMusic.ScanComplete or not MaelstromMusic.MainMenuTrack then
        return
    end
    active = true
    stopping = false
    MaelstromMusic.VanillaMusic.claim(CLAIM_KEY, true)
    MaelstromMusic.VanillaMusic.refresh()
    play()
end

local function onGameStart()
    if not active then
        return
    end
    if not sound then
        finish()
        return
    end
    stopping = true
    sound:fadeOutAndStop(FADE_OUT_MS)
end

local function onPreMapLoad()
    if active then
        holdMusicState()
    end
end

local function onRenderTick()
    MaelstromMusic.VanillaMusic.refresh()

    if not active then
        return
    end
    holdMusicState()

    if not sound then
        return
    end

    if stopping then
        if not sound:updateFade() then
            finish()
        end
        return
    end

    sound:updateFade()
    sound:setVolume(MaelstromMusic.VanillaMusic.optionVolume())

    if getTimestampMs() - startedAt > RESTART_GRACE_MS and not sound:isPlaying() then
        play()
    end
end

Events.OnMainMenuEnter.Add(onMainMenuEnter)
Events.OnGameStart.Add(onGameStart)
Events.OnPreMapLoad.Add(onPreMapLoad)
Events.OnRenderTick.Add(onRenderTick)
