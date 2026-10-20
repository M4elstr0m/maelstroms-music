require "Namespace"
require "Sound"
require "Playback/Device/Mode"

MaelstromMusic.Playback.Device.Voices = {}

local FADE_IN_MS = 2000

-- Sets the emitter, mode and position of a sound for a device, vehicle devices share the vehicle emitter unless staged.
function MaelstromMusic.Playback.Device.Voices.configure(sound, device, deviceData, staged)
    local mode = MaelstromMusic.Playback.Device.Mode.of(deviceData)
    if not staged and deviceData.isVehicleDevice and deviceData:isVehicleDevice() then
        local part = deviceData:getParent()
        local vehicle = part and part:getVehicle()
        if vehicle then
            sound:setEmitter(vehicle:getEmitter())
            sound.sharedEmitter = true
        end
    end
    MaelstromMusic.Playback.Device.Mode.apply(sound, mode)
    if mode == "world" then
        sound:setPosAtObject(device)
    end
end

-- Stops the sound of an entry and its companion.
function MaelstromMusic.Playback.Device.Voices.stop(entry)
    entry.sound:stop()
    if entry.companion then
        entry.companion:stop()
    end
end

-- Advances the fades of an entry and its companion.
function MaelstromMusic.Playback.Device.Voices.updateFades(entry)
    entry.sound:updateFade()
    if entry.companion then
        entry.companion:updateFade()
    end
end

-- Mutes the sound of an entry and its companion.
function MaelstromMusic.Playback.Device.Voices.mute(entry)
    entry.sound:setVolume(0)
    if entry.companion then
        entry.companion:setVolume(0)
    end
end

-- Starts a track on a sound at a volume, with the fade in of the station.
function MaelstromMusic.Playback.Device.Voices.start(sound, trackName, station, volume)
    sound:setVolume(volume)
    sound:setFadeLevel(station.fade and 0 or 1)
    sound:play(trackName)
    if station.fade then
        sound:fadeTo(1, FADE_IN_MS)
    end
end

-- Gives a sound back its own emitter after it used the one of a vehicle.
function MaelstromMusic.Playback.Device.Voices.releaseSharedEmitter(sound)
    if sound.sharedEmitter then
        sound:stop()
        sound:setEmitter(nil)
        sound.sharedEmitter = false
    end
end

-- Creates or removes the companion sound that the stereo safe mode needs.
function MaelstromMusic.Playback.Device.Voices.prepareCompanion(entry, device, deviceData, staged)
    local Voices = MaelstromMusic.Playback.Device.Voices
    if not staged then
        if entry.companion then
            entry.companion:stop()
            entry.companion = nil
        end
        return
    end
    entry.companion = entry.companion or MaelstromMusic.Sound:new()
    Voices.releaseSharedEmitter(entry.companion)
    Voices.configure(entry.companion, device, deviceData, true)
end
