require "Namespace"
require "Log"
require "Safe"
require "Sound"
require "VanillaMusic"
require "Playback/Track"

MaelstromMusic.DeathMusic = {}

local sound = nil

local function stop()
    if not sound then
        return
    end
    MaelstromMusic.Safe.call("could not stop the game over music", function()
        sound:stop()
    end)
    sound = nil
end

local function onPlayerDeath()
    local station = MaelstromMusic.DeathStation
    if not station then
        return
    end
    MaelstromMusic.Safe.call("could not play the game over music", function()
        getSoundManager():StopMusic()
        local trackName, index = MaelstromMusic.Playback.Track.chooseNext(station, nil)
        MaelstromMusic.Log.write("game over music now playing: " .. tostring(station.trackFiles[index]))
        sound = MaelstromMusic.Sound:new()
        sound:setEmitter(getSoundManager():getUIEmitter())
        sound:set3D(false)
        sound:setVolume(MaelstromMusic.VanillaMusic.optionVolume())
        sound:play(trackName)
    end)
end

Events.OnPlayerDeath.Add(onPlayerDeath)
Events.OnCreatePlayer.Add(stop)
