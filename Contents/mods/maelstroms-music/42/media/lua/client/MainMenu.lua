require "Namespace"
require "Log"
require "Safe"
require "Sound"
require "VanillaMusic"
require "Track"

MaelstromMusic.MainMenu = {}

local CLAIM_KEY = "mainmenu"
local FADE_IN_MS = 3000
local FADE_OUT_MS = 2500
local FADE_OUT_TIMEOUT_MS = FADE_OUT_MS + 1500
local RESTART_GRACE_MS = 1500
local TRACK_GAP_MS = 10000

local sound = nil
local active = false
local loadedTrack = nil
local currentIndex = nil
local fadingOut = false
local fadeDeadlineAt = 0
local startedAt = 0
local nextTrackAt = 0

local function menuEmitter()
    return getSoundManager():getUIEmitter()
end

local function hasMainMenuTracks()
    local station = MaelstromMusic.MainMenuStation
    return station ~= nil and #station.tracks > 0
end

local function pickNextTrack()
    local station = MaelstromMusic.MainMenuStation
    if not station then
        return nil, nil
    end
    return MaelstromMusic.Playback.Track.chooseNext(station, currentIndex)
end

local function updateClaim()
    MaelstromMusic.VanillaMusic.claim(CLAIM_KEY, active and hasMainMenuTracks())
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
    updateClaim()
end

local function startTrack(trackName, index)
    if not trackName then
        return
    end
    if not sound then
        sound = MaelstromMusic.Sound:new()
        sound:setEmitter(menuEmitter())
        sound:set3D(false)
    end
    local station = MaelstromMusic.MainMenuStation
    local trackFile = station and index and station.trackFiles[index]
    MaelstromMusic.Log.write("main menu theme now playing: " .. tostring(trackFile))
    MaelstromMusic.Safe.call("could not recentre the main menu emitter", function()
        menuEmitter():setPos(0, 0, 0)
    end)
    sound:setVolume(MaelstromMusic.VanillaMusic.optionVolume())
    sound:setFadeLevel(0)
    sound:play(trackName)
    sound:fadeTo(1, FADE_IN_MS)
    loadedTrack = trackName
    currentIndex = index
    startedAt = getTimestampMs()
    updateClaim()
end

local function beginSwap()
    local isPlaying = false
    MaelstromMusic.Safe.call("could not read the main menu theme playback state", function()
        isPlaying = sound and sound:isPlaying()
    end)

    if not isPlaying then
        discardSound()
        return
    end

    fadingOut = true
    fadeDeadlineAt = getTimestampMs() + FADE_OUT_TIMEOUT_MS
    local started = MaelstromMusic.Safe.call("could not start fading out the main menu theme", function()
        sound:fadeOutAndStop(FADE_OUT_MS)
    end)
    if not started then
        discardSound()
    end
end

local function onMainMenuEnter()
    active = true
end

local function onGameStart()
    active = false
    beginSwap()
end

local function onPreMapLoad()
    if active and (loadedTrack or hasMainMenuTracks()) then
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
            discardSound()
        end

        if active and (loadedTrack or hasMainMenuTracks()) then
            holdMusicState()
        end
        return
    end

    if not active or not MaelstromMusic.ScanComplete then
        return
    end

    if not (loadedTrack or hasMainMenuTracks()) then
        return
    end
    holdMusicState()

    if not loadedTrack then
        if getTimestampMs() >= nextTrackAt then
            startTrack(pickNextTrack())
        end
        return
    end

    sound:updateFade()
    sound:setVolume(MaelstromMusic.VanillaMusic.optionVolume())

    if getTimestampMs() - startedAt > RESTART_GRACE_MS and not sound:isPlaying() then
        discardSound()
        nextTrackAt = getTimestampMs() + TRACK_GAP_MS
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
