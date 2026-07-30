require "Namespace"
require "Safe"
require "Cache"
require "Device"
require "Discovery"

MaelstromMusic.Playback.Tick = {}

local MIN_RANGE = 5
local MAX_RANGE = 75
local DISCOVERY_INTERVAL = 100

local discoveryCounter = 0
local tickCounter = 0
local finishedCounters = {}

local function updateEntry(entry, index, playerX, playerY, playerZ, player)
    local stillTuned = entry.device and entry.deviceData:getIsTurnedOn() and
        MaelstromMusic.Playback.Cache.stationForFrequency(entry.deviceData:getChannel()) == entry.stationId

    if not stillTuned then
        entry.sound:stop()
        MaelstromMusic.Playback.Cache.removeAt(index)
        finishedCounters[entry] = nil
        return
    end

    local x, y, z = MaelstromMusic.Playback.Device.locate(entry.device, entry.deviceData)
    if x then
        entry.x, entry.y, entry.z = x, y, z
    end

    local isHeld = entry.deviceData.isInventoryDevice and entry.deviceData:isInventoryDevice()
    local inMyVehicle = entry.deviceData.isVehicleDevice and entry.deviceData:isVehicleDevice() and
        player:getVehicle() and entry.deviceData:getParent() and entry.deviceData:getParent():getVehicle() == player:getVehicle()

    local distance = math.sqrt((playerX - entry.x) ^ 2 + (playerY - entry.y) ^ 2 + (playerZ - entry.z) ^ 2)

    if not isHeld and not inMyVehicle and distance > MAX_RANGE then
        entry.sound:stop()
        MaelstromMusic.Playback.Cache.removeAt(index)
        finishedCounters[entry] = nil
        return
    end

    if isHeld or inMyVehicle then
        entry.sound:set3D(false)
        entry.sound:setVolume(entry.deviceData:getDeviceVolume())
    else
        entry.sound:set3D(true)
        local dropoffRange = (MAX_RANGE - MIN_RANGE) * 0.2 + entry.deviceData:getDeviceVolume() * entry.sound.volumeModifier * 2.5 * (MAX_RANGE - MIN_RANGE) * 0.8
        local volumeModifier = ((MIN_RANGE + dropoffRange - distance) / dropoffRange)
        if volumeModifier < 0 then volumeModifier = 0 end
        if volumeModifier > 1 then volumeModifier = 1 end
        entry.sound:setVolume(entry.deviceData:getDeviceVolume() * volumeModifier)
    end

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
    local playerX, playerY, playerZ = player:getX(), player:getY(), player:getZ()

    MaelstromMusic.Playback.Cache.ensureFrequencyMap()

    local entries = MaelstromMusic.Playback.Cache.entries
    for index = #entries, 1, -1 do
        updateEntry(entries[index], index, playerX, playerY, playerZ, player)
    end
end

Events.OnTick.Add(MaelstromMusic.Playback.Tick.onTick)
