require "Namespace"
require "Safe"
require "Playback/Cache"
require "Playback/Device"

MaelstromMusic.Playback.Tick.Lifecycle = {}

local ORPHAN_GRACE_MS = 5000
local RESTART_AFTER_TICKS = 25

local finishedCounters = {}

-- Stops and forgets every cached device sound.
function MaelstromMusic.Playback.Tick.Lifecycle.stopAll()
    local entries = MaelstromMusic.Playback.Cache.entries
    for index = #entries, 1, -1 do
        local entry = entries[index]
        MaelstromMusic.Safe.call("could not stop a cached device sound", function()
            MaelstromMusic.Playback.Device.Voices.stop(entry)
        end)
        MaelstromMusic.Playback.Cache.removeAt(index)
    end
end

-- Stops an entry and removes it from the cache.
function MaelstromMusic.Playback.Tick.Lifecycle.drop(entry, index)
    MaelstromMusic.Playback.Device.Voices.stop(entry)
    MaelstromMusic.Playback.Cache.removeAt(index)
    finishedCounters[entry] = nil
end

-- Whether the device of an entry still exists.
function MaelstromMusic.Playback.Tick.Lifecycle.isPresent(entry)
    return entry.device ~= nil and MaelstromMusic.Playback.Device.Location.isPresent(entry.device, entry.deviceData)
end

-- Whether the device is still on and tuned to the station of the entry.
function MaelstromMusic.Playback.Tick.Lifecycle.isStillTuned(entry)
    return entry.deviceData:getIsTurnedOn() and
        MaelstromMusic.Playback.Cache.stationForFrequency(entry.deviceData:getChannel()) == entry.stationId
end

-- Whether the device of an entry is a vehicle radio.
function MaelstromMusic.Playback.Tick.Lifecycle.isVehicleDevice(entry)
    return entry.deviceData.isVehicleDevice and entry.deviceData:isVehicleDevice()
end

-- Mutes an entry whose device vanished, keeping it for a moved device to adopt.
function MaelstromMusic.Playback.Tick.Lifecycle.orphan(entry)
    entry.orphanedAt = getTimestampMs()
    MaelstromMusic.Playback.Device.Voices.mute(entry)
end

-- Drops an orphaned entry once the adoption grace period ends or its track stops.
function MaelstromMusic.Playback.Tick.Lifecycle.updateOrphan(entry, index)
    if getTimestampMs() - entry.orphanedAt > ORPHAN_GRACE_MS or not entry.sound:isPlaying() then
        MaelstromMusic.Playback.Tick.Lifecycle.drop(entry, index)
    end
end

-- Starts the next track once the current one has been over for a few updates.
function MaelstromMusic.Playback.Tick.Lifecycle.restartWhenFinished(entry)
    if entry.sound:isPlaying() then
        finishedCounters[entry] = nil
        return
    end
    finishedCounters[entry] = (finishedCounters[entry] or 0) + 1
    if finishedCounters[entry] > RESTART_AFTER_TICKS then
        finishedCounters[entry] = nil
        MaelstromMusic.Playback.Device.playStation(entry.stationId, entry.device)
    end
end
