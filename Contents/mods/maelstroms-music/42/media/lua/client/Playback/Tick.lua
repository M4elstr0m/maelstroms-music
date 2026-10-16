require "Namespace"
require "Playback/Cache"
require "Playback/Device"
require "Playback/Discovery"
require "Playback/Staging"
require "Playback/ListenerFrame"
require "Playback/Tick/Lifecycle"
require "Playback/Tick/Volume"

local DISCOVERY_INTERVAL = 100
local UPDATE_EVERY_TICKS = 5

local Tick = MaelstromMusic.Playback.Tick
local Device = MaelstromMusic.Playback.Device
local Lifecycle = Tick.Lifecycle
local Volume = Tick.Volume
local Staging = MaelstromMusic.Playback.Staging

local discoveryCounter = 0
local tickCounter = 0
local renderPose = {}

-- Stops every device sound as soon as there is no player, which means back at the menu.
local function checkPlayerGone()
    if #MaelstromMusic.Playback.Cache.entries > 0 and not getPlayer() then
        Lifecycle.stopAll()
    end
end

-- Refreshes the position of an entry from its device.
local function refreshPosition(entry)
    local x, y, z = Device.Location.of(entry.device, entry.deviceData)
    if x then
        entry.x, entry.y, entry.z = x, y, z
    end
end

-- Per entry update: orphan handling, tuning, mode, range, volume and restart of a finished track.
-- Restarts the entry when the stereo safe option changed.
local function updateEntry(entry, index, player, listener, now)
    if entry.orphanedAt then
        Lifecycle.updateOrphan(entry, index)
        return
    end

    if not Lifecycle.isPresent(entry) then
        if Lifecycle.isVehicleDevice(entry) then
            Lifecycle.drop(entry, index)
        else
            Lifecycle.orphan(entry)
        end
        return
    end

    if not Lifecycle.isStillTuned(entry) then
        Lifecycle.drop(entry, index)
        return
    end

    if (entry.companion ~= nil) ~= (listener ~= nil) then
        Device.playStation(entry.stationId, entry.device)
        return
    end

    Device.Voices.updateFades(entry)
    refreshPosition(entry)

    local mode = Device.Mode.of(entry.deviceData)
    Volume.applyMode(entry, mode)

    local distance = math.sqrt((player.x - entry.x) ^ 2 + (player.y - entry.y) ^ 2 + (player.z - entry.z) ^ 2)
    local carried = Device.Mode.isCarried(mode)

    if not carried and distance > Volume.MAX_RANGE then
        Lifecycle.drop(entry, index)
        return
    end

    Volume.apply(entry, mode, carried and entry.deviceData:getDeviceVolume() or Volume.dropoff(entry, distance), listener, now)
    Lifecycle.restartWhenFinished(entry)
end

-- Every fifth tick: discovers devices every 100 ticks, then updates every cached entry.
function Tick.onTick()
    tickCounter = tickCounter + 1
    discoveryCounter = discoveryCounter + 1

    if discoveryCounter >= DISCOVERY_INTERVAL then
        discoveryCounter = 0
        MaelstromMusic.Safe.call("discovery scan failed", MaelstromMusic.Playback.Discovery.scan)
    end

    if tickCounter < UPDATE_EVERY_TICKS then
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
    if Device.isStaged() then
        listener = Staging.listener(player, MaelstromMusic.Playback.ListenerFrame.current())
    end

    MaelstromMusic.Playback.Cache.ensureFrequencyMap()

    local entries = MaelstromMusic.Playback.Cache.entries
    for index = #entries, 1, -1 do
        updateEntry(entries[index], index, position, listener, now)
    end
end

-- Every rendered frame: steps the stage so staged emitters follow the head turns smoothly.
function Tick.onRender()
    local entries = MaelstromMusic.Playback.Cache.entries
    local player = getPlayer()
    if #entries == 0 or not player or not Device.isStaged() then
        return
    end

    local pose = Staging.pose(player, MaelstromMusic.Playback.ListenerFrame.current(), renderPose)
    local now = getTimestampMs()
    for _, entry in ipairs(entries) do
        if entry.companion and not entry.orphanedAt then
            Staging.step(entry, pose, now)
        end
    end
end

Events.OnTick.Add(Tick.onTick)
Events.OnRenderTick.Add(Tick.onRender)
Events.OnRenderTick.Add(checkPlayerGone)
