require "Namespace"
require "Playback/Device"
require "Playback/Staging"

MaelstromMusic.Playback.Tick.Volume = {}

local MIN_RANGE = 5
local MAX_RANGE = 75

MaelstromMusic.Playback.Tick.Volume.MAX_RANGE = MAX_RANGE

-- Volume of a world device at a distance, following the vanilla radio dropoff curve.
function MaelstromMusic.Playback.Tick.Volume.dropoff(entry, distance)
    local deviceVolume = entry.deviceData:getDeviceVolume()
    local dropoffRange = (MAX_RANGE - MIN_RANGE) * 0.2 + deviceVolume * entry.sound.volumeModifier * 2.5 * (MAX_RANGE - MIN_RANGE) * 0.8
    local volumeModifier = ((MIN_RANGE + dropoffRange - distance) / dropoffRange)
    if volumeModifier < 0 then volumeModifier = 0 end
    if volumeModifier > 1 then volumeModifier = 1 end
    return deviceVolume * volumeModifier
end

-- Applies a mode to an entry and its companion.
function MaelstromMusic.Playback.Tick.Volume.applyMode(entry, mode)
    local Mode = MaelstromMusic.Playback.Device.Mode
    Mode.apply(entry.sound, mode)
    if entry.companion then
        Mode.apply(entry.companion, mode)
    end
end

-- Sets the volume of an entry, through the stage when staged.
function MaelstromMusic.Playback.Tick.Volume.apply(entry, mode, volume, listener, now)
    if listener and entry.companion then
        MaelstromMusic.Playback.Staging.plan(entry, MaelstromMusic.Playback.Device.Mode.isPositional(mode), volume, listener, now)
        return
    end
    entry.sound:setVolume(volume)
end
