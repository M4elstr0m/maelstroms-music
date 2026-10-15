require "Namespace"
require "Log"
require "Sound"
require "Playback/Cache"
require "Playback/Track"
require "Playback/Warmup"

MaelstromMusic.Playback.Device = {}

local FADE_IN_MS = 2000
local MAX_SEEDED_STATIONS = 12
local LOOKAHEAD = 2
local ORPHAN_ADOPT_RADIUS = 20

local nextByStation = {}

local function ensurePicks(stationId, station)
    local picks = nextByStation[stationId]
    if not picks then
        picks = {}
        nextByStation[stationId] = picks
    end
    local afterIndex = #picks > 0 and picks[#picks].index or nil
    while #picks < LOOKAHEAD do
        local name, index = MaelstromMusic.Playback.Track.chooseNext(station, afterIndex)
        if not name then
            break
        end
        table.insert(picks, { name = name, index = index })
        MaelstromMusic.Playback.Warmup.request(name)
        afterIndex = index
    end
end

local function primeStations()
    local count = 0
    local seeded = 0
    for stationId, station in pairs(MaelstromMusic.Broadcasts or {}) do
        if seeded >= MAX_SEEDED_STATIONS then
            break
        end
        local before = #(nextByStation[stationId] or {})
        ensurePicks(stationId, station)
        local added = #(nextByStation[stationId] or {}) - before
        if added > 0 then
            count = count + added
            seeded = seeded + 1
        end
    end
    if count > 0 then
        MaelstromMusic.Log.write("pre-warming " .. count .. " track(s) across station(s).")
    end
end

local function locate(device, deviceData)
    if deviceData.isVehicleDevice and deviceData:isVehicleDevice() then
        local vehicle = deviceData:getParent() and deviceData:getParent():getVehicle()
        if vehicle then
            return vehicle:getX(), vehicle:getY(), vehicle:getZ()
        end
    end
    if device.isInPlayerInventory and device:isInPlayerInventory() then
        local player = getPlayer()
        return player:getX(), player:getY(), player:getZ()
    end
    if device.getSquare and device:getSquare() then
        return device:getX(), device:getY(), device:getZ()
    end
    return nil, nil, nil
end

MaelstromMusic.Playback.Device.locate = locate

function MaelstromMusic.Playback.Device.isPresent(device, deviceData)
    if deviceData.isVehicleDevice and deviceData:isVehicleDevice() then
        local part = deviceData:getParent()
        return part ~= nil and part:getVehicle() ~= nil
    end
    if instanceof(device, "InventoryItem") then
        return device:getContainer() ~= nil or device:getWorldItem() ~= nil
    end
    return device:getObjectIndex() ~= -1
end

local VOLUME_MODIFIER = { held = 0.6, vehicleInside = 0.8, vehicleOutside = 0.3, world = 0.4 }

function MaelstromMusic.Playback.Device.modeOf(deviceData)
    if deviceData.isInventoryDevice and deviceData:isInventoryDevice() then
        return "held"
    end
    if deviceData.isVehicleDevice and deviceData:isVehicleDevice() then
        local part = deviceData:getParent()
        local vehicle = part and part:getVehicle()
        if vehicle and vehicle == getPlayer():getVehicle() then
            return "vehicleInside"
        end
        return "vehicleOutside"
    end
    return "world"
end

function MaelstromMusic.Playback.Device.isPositional(mode)
    return mode == "world" or mode == "vehicleOutside"
end

function MaelstromMusic.Playback.Device.applyMode(sound, mode)
    local modifier = VOLUME_MODIFIER[mode]
    if sound.volumeModifier ~= modifier then
        sound:setVolumeModifier(modifier)
    end
    local positional = MaelstromMusic.Playback.Device.isPositional(mode)
    if sound.sound3D ~= positional then
        sound:set3D(positional)
    end
end

local function configureSound(sound, device, deviceData)
    local mode = MaelstromMusic.Playback.Device.modeOf(deviceData)
    if deviceData.isVehicleDevice and deviceData:isVehicleDevice() then
        local part = deviceData:getParent()
        local vehicle = part and part:getVehicle()
        if vehicle then
            sound:setEmitter(vehicle:getEmitter())
        end
    end
    MaelstromMusic.Playback.Device.applyMode(sound, mode)
    if mode == "world" then
        sound:setPosAtObject(device)
    end
end

local function findOrphan(stationId, deviceData, x, y)
    local own = MaelstromMusic.Playback.Cache.get(deviceData)
    if own and own.orphanedAt then
        if own.sound:isPlaying() then
            return own
        end
        MaelstromMusic.Playback.Cache.remove(own)
    end
    return MaelstromMusic.Playback.Cache.takeOrphan(stationId, x, y, ORPHAN_ADOPT_RADIUS)
end

local function adoptOrphan(stationId, device, deviceData)
    local x, y, z = locate(device, deviceData)
    local entry = findOrphan(stationId, deviceData, x, y)
    if not entry then
        return false
    end
    entry.device = device
    entry.deviceData = deviceData
    entry.orphanedAt = nil
    entry.x, entry.y, entry.z = x or entry.x, y or entry.y, z or entry.z
    configureSound(entry.sound, device, deviceData)
    entry.sound:setVolume(deviceData:getDeviceVolume())
    MaelstromMusic.Log.write("'" .. MaelstromMusic.Broadcasts[stationId].title .. "' keeps playing on the moved device.")
    return true
end

function MaelstromMusic.Playback.Device.playStation(stationId, device)
    local deviceData = device:getDeviceData()
    if not deviceData then
        return
    end

    local existing = MaelstromMusic.Playback.Cache.get(deviceData)
    local sound = existing and existing.sound or MaelstromMusic.Sound:new()
    configureSound(sound, device, deviceData)

    local station = MaelstromMusic.Broadcasts[stationId]
    ensurePicks(stationId, station)
    local picks = nextByStation[stationId]
    local trackName, trackIndex
    if #picks > 0 then
        local pick = table.remove(picks, 1)
        trackName, trackIndex = pick.name, pick.index
    else
        trackName, trackIndex = MaelstromMusic.Playback.Track.chooseNext(station, existing and existing.trackIndex)
    end
    if not trackName then
        return
    end

    ensurePicks(stationId, station)

    MaelstromMusic.Log.write("'" .. station.title .. "' now playing: " .. tostring(station.trackFiles[trackIndex]))

    sound:setVolume(deviceData:getDeviceVolume())
    sound:setFadeLevel(station.fade and 0 or 1)
    sound:play(trackName)
    if station.fade then
        sound:fadeTo(1, FADE_IN_MS)
    end

    local x, y, z = locate(device, deviceData)

    local entry = existing or {}
    entry.orphanedAt = nil
    entry.device = device
    entry.deviceData = deviceData
    entry.stationId = stationId
    entry.trackIndex = trackIndex
    entry.sound = sound
    entry.x = x or entry.x or 0
    entry.y = y or entry.y or 0
    entry.z = z or entry.z or 0

    if not MaelstromMusic.Playback.Cache.get(deviceData) then
        MaelstromMusic.Playback.Cache.add(entry)
    end
end

function MaelstromMusic.Playback.Device.ensurePlaying(device)
    if not device or not device.getDeviceData then
        return
    end
    local deviceData = device:getDeviceData()
    if not deviceData or not deviceData:getIsTurnedOn() then
        return
    end

    MaelstromMusic.Playback.Cache.ensureFrequencyMap()
    local stationId = MaelstromMusic.Playback.Cache.stationForFrequency(deviceData:getChannel())
    if not stationId then
        return
    end

    local entry = MaelstromMusic.Playback.Cache.get(deviceData)
    if entry and not entry.orphanedAt and entry.sound and entry.sound:isPlaying() then
        return
    end

    if (not entry or entry.orphanedAt) and adoptOrphan(stationId, device, deviceData) then
        return
    end

    MaelstromMusic.Playback.Device.playStation(stationId, device)
end

Events.OnPreMapLoad.Add(primeStations)
