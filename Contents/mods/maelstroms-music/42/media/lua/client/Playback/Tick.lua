require "Namespace"
require "Safe"
require "Playback/Cache"
require "Playback/Device"
require "Playback/Discovery"
require "Playback/Staging"
require "Playback/ListenerFrame"

MaelstromMusic.Playback.Tick = {}

local MIN_RANGE = 5
local MAX_RANGE = 75
local DISCOVERY_INTERVAL = 100
local ORPHAN_GRACE_MS = 5000

local discoveryCounter = 0
local tickCounter = 0
local finishedCounters = {}

-- Stops and forgets every cached device sound.
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

-- Stops every device sound as soon as there is no player, which means back at the menu.
local function checkPlayerGone()
    if #MaelstromMusic.Playback.Cache.entries > 0 and not getPlayer() then
        stopAllEntries()
    end
end

-- Stops an entry and removes it from the cache.
local function dropEntry(entry, index)
    MaelstromMusic.Playback.Device.stopSounds(entry)
    MaelstromMusic.Playback.Cache.removeAt(index)
    finishedCounters[entry] = nil
end

-- Whether the device of an entry still exists.
local function isPresent(entry)
    return entry.device ~= nil and MaelstromMusic.Playback.Device.isPresent(entry.device, entry.deviceData)
end

-- Whether the device is still on and tuned to the station of the entry.
local function isStillTuned(entry)
    return entry.deviceData:getIsTurnedOn() and
        MaelstromMusic.Playback.Cache.stationForFrequency(entry.deviceData:getChannel()) == entry.stationId
end

-- Whether the device of an entry is a vehicle radio.
local function isVehicleDevice(entry)
    return entry.deviceData.isVehicleDevice and entry.deviceData:isVehicleDevice()
end

-- Mutes an entry whose device vanished, keeping it for a moved device to adopt.
local function orphanEntry(entry)
    entry.orphanedAt = getTimestampMs()
    MaelstromMusic.Playback.Device.muteSounds(entry)
end

-- Drops an orphaned entry once the adoption grace period ends or its track stops.
local function updateOrphan(entry, index)
    if getTimestampMs() - entry.orphanedAt > ORPHAN_GRACE_MS or not entry.sound:isPlaying() then
        dropEntry(entry, index)
    end
end

-- Advances the fades of an entry and its companion.
local function fadeSounds(entry)
    entry.sound:updateFade()
    if entry.companion then
        entry.companion:updateFade()
    end
end

-- Applies a mode to an entry and its companion.
local function applyMode(entry, mode)
    local Device = MaelstromMusic.Playback.Device
    Device.applyMode(entry.sound, mode)
    if entry.companion then
        Device.applyMode(entry.companion, mode)
    end
end

-- Sets the volume of an entry, through the stage when staged.
local function applyVolume(entry, mode, volume, listener, now)
    if listener and entry.companion then
        MaelstromMusic.Playback.Staging.plan(entry, MaelstromMusic.Playback.Device.isPositional(mode), volume, listener, now)
        return
    end
    entry.sound:setVolume(volume)
end

-- Volume of a world device at a distance, following the vanilla radio dropoff curve.
local function dropoffVolume(entry, distance)
    local dropoffRange = (MAX_RANGE - MIN_RANGE) * 0.2 + entry.deviceData:getDeviceVolume() * entry.sound.volumeModifier * 2.5 * (MAX_RANGE - MIN_RANGE) * 0.8
    local volumeModifier = ((MIN_RANGE + dropoffRange - distance) / dropoffRange)
    if volumeModifier < 0 then volumeModifier = 0 end
    if volumeModifier > 1 then volumeModifier = 1 end
    return entry.deviceData:getDeviceVolume() * volumeModifier
end

-- Per entry update: orphan handling, tuning, mode, range, volume and restart of a finished track.
-- Restarts the entry when the stereo safe option changed.
local function updateEntry(entry, index, player, listener, now)
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

    applyVolume(entry, mode, carried and entry.deviceData:getDeviceVolume() or dropoffVolume(entry, distance), listener, now)

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

-- Every fifth tick: discovers devices every 100 ticks, then updates every cached entry.
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
    local now = getTimestampMs()
    local listener = nil
    if MaelstromMusic.Playback.Device.isStaged() then
        listener = MaelstromMusic.Playback.Staging.listener(player, MaelstromMusic.Playback.ListenerFrame.current())
    end

    MaelstromMusic.Playback.Cache.ensureFrequencyMap()

    local entries = MaelstromMusic.Playback.Cache.entries
    for index = #entries, 1, -1 do
        updateEntry(entries[index], index, position, listener, now)
    end
end

-- Every rendered frame: steps the stage so staged emitters follow the head turns smoothly.
function MaelstromMusic.Playback.Tick.onRender()
    local entries = MaelstromMusic.Playback.Cache.entries
    local player = getPlayer()
    if #entries == 0 or not player or not MaelstromMusic.Playback.Device.isStaged() then
        return
    end

    local pose = MaelstromMusic.Playback.Staging.pose(player, MaelstromMusic.Playback.ListenerFrame.current())
    local now = getTimestampMs()
    for _, entry in ipairs(entries) do
        if entry.companion and not entry.orphanedAt then
            MaelstromMusic.Playback.Staging.step(entry, pose, now)
        end
    end
end

Events.OnTick.Add(MaelstromMusic.Playback.Tick.onTick)
Events.OnRenderTick.Add(MaelstromMusic.Playback.Tick.onRender)
Events.OnRenderTick.Add(checkPlayerGone)
