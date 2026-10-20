require "Namespace"
require "Log"
require "Safe"
require "Sound"
require "VanillaMusic"
require "MainMenu/Mix"
require "Playback/Track"

MaelstromMusic.MainMenu.Theme = {}

local Theme = MaelstromMusic.MainMenu.Theme

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

-- The UI emitter, the one that plays at the main menu.
local function menuEmitter()
    return getSoundManager():getUIEmitter()
end

-- Whether a main menu theme is available.
function Theme.hasTracks()
    local station = MaelstromMusic.MainMenuStation
    return station ~= nil and #station.tracks > 0
end

-- Whether the theme is on, so the vanilla music state must be held.
function Theme.wantsMusic()
    return active and (loadedTrack ~= nil or Theme.hasTracks())
end

-- Whether a track is loaded.
function Theme.isLoaded()
    return loadedTrack ~= nil
end

-- Whether the theme is fading out because a game is starting.
function Theme.isFadingOut()
    return fadingOut
end

-- Whether the gap after the previous track is over.
function Theme.isDue(now)
    return now >= nextTrackAt
end

-- Keeps the claim on the vanilla soundtrack in line with whether the theme should play.
local function updateClaim()
    MaelstromMusic.MainMenu.Mix.silenceVanilla(active and Theme.hasTracks())
end

-- Turns the theme on when the main menu opens and off when a game starts.
function Theme.setActive(value)
    active = value
end

-- Stops and forgets the current theme track.
function Theme.discard()
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

-- Starts the next theme track, never the one just played, with a fade in.
function Theme.start()
    local station = MaelstromMusic.MainMenuStation
    if not station then
        return
    end
    local trackName, index = MaelstromMusic.Playback.Track.chooseNext(station, currentIndex)
    if not trackName then
        return
    end
    if not sound then
        sound = MaelstromMusic.Sound:new()
        sound:setEmitter(menuEmitter())
        sound:set3D(false)
    end
    MaelstromMusic.Log.write("main menu theme now playing: " .. tostring(station.trackFiles[index]))
    MaelstromMusic.Safe.call("could not recentre the main menu emitter", function()
        menuEmitter():setPos(0, 0, 0)
    end)
    sound:setVolume(MaelstromMusic.MainMenu.Mix.volume())
    sound:setFadeLevel(0)
    sound:play(trackName)
    sound:fadeTo(1, FADE_IN_MS)
    loadedTrack = trackName
    currentIndex = index
    startedAt = getTimestampMs()
    updateClaim()
end

-- Fades the theme out when the game starts, or discards it when nothing is playing.
function Theme.beginSwap()
    local isPlaying = false
    MaelstromMusic.Safe.call("could not read the main menu theme playback state", function()
        isPlaying = sound and sound:isPlaying()
    end)

    if not isPlaying then
        Theme.discard()
        return
    end

    fadingOut = true
    fadeDeadlineAt = getTimestampMs() + FADE_OUT_TIMEOUT_MS
    local started = MaelstromMusic.Safe.call("could not start fading out the main menu theme", function()
        sound:fadeOutAndStop(FADE_OUT_MS)
    end)
    if not started then
        Theme.discard()
    end
end

-- Continues the fade out and discards the theme once it ends or takes too long.
function Theme.updateFadeOut()
    local done = false
    local ok = MaelstromMusic.Safe.call("could not update the main menu theme fade", function()
        done = not sound:updateFade()
    end)
    if (ok and done) or getTimestampMs() > fadeDeadlineAt then
        Theme.discard()
    end
end

-- Per frame while a track plays: advances the fade, follows the volume, and starts the gap when the track ends.
function Theme.sustain()
    sound:updateFade()
    sound:setVolume(MaelstromMusic.MainMenu.Mix.volume())
    if getTimestampMs() - startedAt > RESTART_GRACE_MS and not sound:isPlaying() then
        Theme.discard()
        nextTrackAt = getTimestampMs() + TRACK_GAP_MS
    end
end

-- Clears a leftover theme from before a Lua reload and gives the vanilla music back.
function Theme.reset()
    MaelstromMusic.Safe.call("could not clear a leftover main menu theme", function()
        menuEmitter():stopAll()
    end)
    MaelstromMusic.VanillaMusic.restore()
end
