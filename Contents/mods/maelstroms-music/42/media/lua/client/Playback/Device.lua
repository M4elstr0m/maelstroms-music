require "Namespace"
require "Log"
require "Sound"
require "Cache"
require "Track"
require "Warmup"

MaelstromMusic.Playback.Device = {}

local FADE_IN_MS = 2000
local MAX_SEEDED_STATIONS = 12
local LOOKAHEAD = 2

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

function MaelstromMusic.Playback.Device.playStation(stationId, device)
    local deviceData = device:getDeviceData()
    if not deviceData then
        return
    end

    local existing = MaelstromMusic.Playback.Cache.get(deviceData)
    local sound = existing and existing.sound or MaelstromMusic.Sound:new()

    if deviceData.isInventoryDevice and deviceData:isInventoryDevice() then
        sound:set3D(false)
        sound:setVolumeModifier(0.6)
    elseif deviceData.isVehicleDevice and deviceData:isVehicleDevice() then
        local vehiclePart = deviceData:getParent()
        local vehicle = vehiclePart and vehiclePart:getVehicle()
        if vehicle then
            sound:setEmitter(vehicle:getEmitter())
            if vehicle == getPlayer():getVehicle() then
                sound:set3D(false)
                sound:setVolumeModifier(0.8)
            else
                sound:set3D(true)
                sound:setVolumeModifier(0.3)
            end
        end
    else
        sound:setPosAtObject(device)
        sound:setVolumeModifier(0.4)
    end

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
    if entry and entry.sound and entry.sound:isPlaying() then
        return
    end

    MaelstromMusic.Playback.Device.playStation(stationId, device)
end

Events.OnPreMapLoad.Add(primeStations)
