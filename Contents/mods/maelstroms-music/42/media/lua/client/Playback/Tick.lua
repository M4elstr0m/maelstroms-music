require "Namespace"
require "Safe"
require "Playback/Cache"
require "Playback/Device"
require "Playback/Discovery"
require "Playback/Staging"
require "Options"

MaelstromMusic.Playback.Tick = {}

local MIN_RANGE = 5
local MAX_RANGE = 75
local DISCOVERY_INTERVAL = 100
local ORPHAN_GRACE_MS = 5000

local discoveryCounter = 0
local tickCounter = 0
local finishedCounters = {}

local function stopAllEntries()
    local entries = MaelstromMusic.Playback.Cache.entries
    for index = #entries, 1, -1 do
        local entry = entries[index]
        MaelstromMusic.Safe.call("could not stop a cached device sound", function()
            MaelstromMusic.Playback.Device.stopSounds(entry)
        end)
        MaelstromMusic.Playback.Cache.removeAt(index)
    end
end

local function checkPlayerGone()
    if #MaelstromMusic.Playback.Cache.entries > 0 and not getPlayer() then
        stopAllEntries()
    end
end

local function dropEntry(entry, index)
    MaelstromMusic.Playback.Device.stopSounds(entry)
    MaelstromMusic.Playback.Cache.removeAt(index)
    finishedCounters[entry] = nil
end

local function isPresent(entry)
    return entry.device ~= nil and MaelstromMusic.Playback.Device.isPresent(entry.device, entry.deviceData)
end

local function isStillTuned(entry)
    return entry.deviceData:getIsTurnedOn() and
        MaelstromMusic.Playback.Cache.stationForFrequency(entry.deviceData:getChannel()) == entry.stationId
end

local function isVehicleDevice(entry)
    return entry.deviceData.isVehicleDevice and entry.deviceData:isVehicleDevice()
end

local function orphanEntry(entry)
    entry.orphanedAt = getTimestampMs()
    MaelstromMusic.Playback.Device.muteSounds(entry)
end

local function updateOrphan(entry, index)
    if getTimestampMs() - entry.orphanedAt > ORPHAN_GRACE_MS or not entry.sound:isPlaying() then
        dropEntry(entry, index)
    end
end

local function fadeSounds(entry)
    entry.sound:updateFade()
    if entry.companion then
        entry.companion:updateFade()
    end
end

local function applyMode(entry, mode)
    local Device = MaelstromMusic.Playback.Device
    Device.applyMode(entry.sound, mode)
    if entry.companion then
        Device.applyMode(entry.companion, mode)
    end
end

local function applyVolume(entry, mode, volume, listener)
    if listener and entry.companion then
        MaelstromMusic.Playback.Staging.apply(entry, MaelstromMusic.Playback.Device.isPositional(mode), volume, listener)
        return
    end
    entry.sound:setVolume(volume)
end

local function dropoffVolume(entry, distance)
    local dropoffRange = (MAX_RANGE - MIN_RANGE) * 0.2 + entry.deviceData:getDeviceVolume() * entry.sound.volumeModifier * 2.5 * (MAX_RANGE - MIN_RANGE) * 0.8
    local volumeModifier = ((MIN_RANGE + dropoffRange - distance) / dropoffRange)
    if volumeModifier < 0 then volumeModifier = 0 end
    if volumeModifier > 1 then volumeModifier = 1 end
    return entry.deviceData:getDeviceVolume() * volumeModifier
end

local function updateEntry(entry, index, player, listener)
    if entry.orphanedAt then
        updateOrphan(entry, index)
        return
    end

    if not isPresent(entry) then
        if isVehicleDevice(entry) then
            dropEntry(entry, index)
        else
            orphanEntry(entry)
        end
        return
    end

    if not isStillTuned(entry) then
        dropEntry(entry, index)
        return
    end

    if (entry.companion ~= nil) ~= MaelstromMusic.Playback.Device.isStaged() then
        MaelstromMusic.Playback.Device.playStation(entry.stationId, entry.device)
        return
    end

    fadeSounds(entry)

    local x, y, z = MaelstromMusic.Playback.Device.locate(entry.device, entry.deviceData)
    if x then
        entry.x, entry.y, entry.z = x, y, z
    end

    local Device = MaelstromMusic.Playback.Device
    local mode = Device.modeOf(entry.deviceData)
    applyMode(entry, mode)

    local distance = math.sqrt((player.x - entry.x) ^ 2 + (player.y - entry.y) ^ 2 + (player.z - entry.z) ^ 2)
    local carried = mode == "held" or mode == "vehicleInside"

    if not carried and distance > MAX_RANGE then
        dropEntry(entry, index)
        return
    end

    applyVolume(entry, mode, carried and entry.deviceData:getDeviceVolume() or dropoffVolume(entry, distance), listener)

    if not entry.sound:isPlaying() then
        finishedCounters[entry] = (finishedCounters[entry] or 0) + 1
        if finishedCounters[entry] > 25 then
            finishedCounters[entry] = nil
            MaelstromMusic.Playback.Device.playStation(entry.stationId, entry.device)
        end
    else
        finishedCounters[entry] = nil
    end
end

function MaelstromMusic.Playback.Tick.onTick()
    tickCounter = tickCounter + 1
    discoveryCounter = discoveryCounter + 1

    if discoveryCounter >= DISCOVERY_INTERVAL then
        discoveryCounter = 0
        MaelstromMusic.Safe.call("discovery scan failed", MaelstromMusic.Playback.Discovery.scan)
    end

    if tickCounter < 5 then
        return
    end
    tickCounter = 0

    local player = getPlayer()
    if not player then
        return
    end
    local position = { x = player:getX(), y = player:getY(), z = player:getZ() }
    local listener = nil
    if MaelstromMusic.Playback.Device.isStaged() then
        listener = MaelstromMusic.Playback.Staging.listener(player, MaelstromMusic.Options.listenerFrame())
    end

    MaelstromMusic.Playback.Cache.ensureFrequencyMap()

    local entries = MaelstromMusic.Playback.Cache.entries
    for index = #entries, 1, -1 do
        updateEntry(entries[index], index, position, listener)
    end
end

Events.OnTick.Add(MaelstromMusic.Playback.Tick.onTick)
Events.OnRenderTick.Add(checkPlayerGone)
