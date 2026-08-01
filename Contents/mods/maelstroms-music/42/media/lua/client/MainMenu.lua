require "Namespace"
require "Log"
require "Safe"
require "Sound"
require "VanillaMusic"

MaelstromMusic.MainMenu = {}

local CLAIM_KEY = "mainmenu"
local FADE_IN_MS = 3000
local FADE_OUT_MS = 2500
local FADE_OUT_TIMEOUT_MS = FADE_OUT_MS + 1500
local RESTART_GRACE_MS = 1500

local sound = nil
local active = false
local loadedTrack = nil
local fadingOut = false
local pendingTrack = nil
local fadeDeadlineAt = 0
local startedAt = 0

local function menuEmitter()
    return getSoundManager():getUIEmitter()
end

local function updateClaim()
    MaelstromMusic.VanillaMusic.claim(CLAIM_KEY, loadedTrack ~= nil)
    MaelstromMusic.VanillaMusic.refresh()
end

local function holdMusicState()
    MaelstromMusic.Safe.call("could not hold the main menu music state", function()
        getSoundManager():setMusicState("MainMenu")
        getSoundManager():StopMusic()
    end)
end

local function discardSound()
    if sound then
        MaelstromMusic.Safe.call("could not stop the main menu theme", function()
            sound:stop()
        end)
    end
    sound = nil
    loadedTrack = nil
    fadingOut = false
    pendingTrack = nil
    updateClaim()
end

local function startTrack(trackName)
    if not sound then
        sound = MaelstromMusic.Sound:new()
        sound:setEmitter(menuEmitter())
        sound:set3D(false)
    end
    MaelstromMusic.Safe.call("could not recentre the main menu emitter", function()
        menuEmitter():setPos(0, 0, 0)
    end)
    sound:setVolume(MaelstromMusic.VanillaMusic.optionVolume())
    sound:setFadeLevel(0)
    sound:play(trackName)
    sound:fadeTo(1, FADE_IN_MS)
    loadedTrack = trackName
    startedAt = getTimestampMs()
    updateClaim()
end

local function beginSwap(nextTrack)
    local isPlaying = false
    MaelstromMusic.Safe.call("could not read the main menu theme playback state", function()
        isPlaying = sound and sound:isPlaying()
    end)

    if not isPlaying then
        discardSound()
        if nextTrack then
            startTrack(nextTrack)
        end
        return
    end

    fadingOut = true
    pendingTrack = nextTrack
    fadeDeadlineAt = getTimestampMs() + FADE_OUT_TIMEOUT_MS
    local started = MaelstromMusic.Safe.call("could not start fading out the main menu theme", function()
        sound:fadeOutAndStop(FADE_OUT_MS)
    end)
    if not started then
        discardSound()
        if nextTrack then
            startTrack(nextTrack)
        end
    end
end

local function onMainMenuEnter()
    active = true
end

local function onGameStart()
    active = false
    beginSwap(nil)
end

local function onPreMapLoad()
    if active and (loadedTrack or MaelstromMusic.MainMenuTrack) then
        holdMusicState()
    end
end

local function onRenderTick()
    MaelstromMusic.VanillaMusic.refresh()

    if fadingOut then
        local done = false
        local ok = MaelstromMusic.Safe.call("could not update the main menu theme fade", function()
            done = not sound:updateFade()
        end)

        if (ok and done) or getTimestampMs() > fadeDeadlineAt then
            local nextTrack = pendingTrack
            discardSound()
            if nextTrack and active then
                startTrack(nextTrack)
            end
        end

        if active and (loadedTrack or MaelstromMusic.MainMenuTrack) then
            holdMusicState()
        end
        return
    end

    if not active or not MaelstromMusic.ScanComplete then
        return
    end

    local desired = MaelstromMusic.MainMenuTrack
    if not (loadedTrack or desired) then
        return
    end
    holdMusicState()

    if desired ~= loadedTrack then
        if loadedTrack then
            beginSwap(desired)
        else
            startTrack(desired)
        end
        return
    end

    sound:updateFade()
    sound:setVolume(MaelstromMusic.VanillaMusic.optionVolume())

    if getTimestampMs() - startedAt > RESTART_GRACE_MS and not sound:isPlaying() then
        startTrack(loadedTrack)
    end
end

MaelstromMusic.Safe.call("could not clear a leftover main menu theme", function()
    menuEmitter():stopAll()
end)
MaelstromMusic.VanillaMusic.restore()

Events.OnMainMenuEnter.Add(onMainMenuEnter)
Events.OnGameStart.Add(onGameStart)
Events.OnPreMapLoad.Add(onPreMapLoad)
Events.OnRenderTick.Add(onRenderTick)
