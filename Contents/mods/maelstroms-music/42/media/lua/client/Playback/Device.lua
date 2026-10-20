require "Namespace"
require "Log"
require "Sound"
require "Options"
require "Playback/Cache"
require "Playback/PickQueue"
require "Playback/Track"
require "Playback/Device/Location"
require "Playback/Device/Orphans"
require "Playback/Device/Voices"

local PRIMED_STATIONS = 12

local Device = MaelstromMusic.Playback.Device
local upcoming = MaelstromMusic.Playback.PickQueue.new()

-- Whether devices play through the stereo safe left and right emitters.
function Device.isStaged()
    return MaelstromMusic.Options.stereoSafePositioning()
end

-- Queues and pre-decodes the first tracks of up to 12 stations.
local function primeStations()
    local queued = upcoming:prime(MaelstromMusic.Broadcasts or {}, PRIMED_STATIONS)
    if queued > 0 then
        MaelstromMusic.Log.write("pre-warming " .. queued .. " track(s) across station(s).")
    end
end

-- Takes the next queued track of a station, or chooses one when the queue is empty.
local function nextTrack(stationId, station, previousIndex)
    upcoming:fill(stationId, station)
    local pick = upcoming:take(stationId)
    if pick then
        return pick.name, pick.index
    end
    return MaelstromMusic.Playback.Track.chooseNext(station, previousIndex)
end

-- Starts the next track of a station on a device, and on its companion when staged, together.
function Device.playStation(stationId, device)
    local deviceData = device:getDeviceData()
    if not deviceData then
        return
    end
    local Voices = Device.Voices

    local staged = Device.isStaged()
    local existing = MaelstromMusic.Playback.Cache.get(deviceData)
    local entry = existing or {}
    local sound = entry.sound or MaelstromMusic.Sound:new()
    if staged then
        Voices.releaseSharedEmitter(sound)
    end
    Voices.configure(sound, device, deviceData, staged)

    local station = MaelstromMusic.Broadcasts[stationId]
    local trackName, trackIndex = nextTrack(stationId, station, existing and existing.trackIndex)
    if not trackName then
        return
    end
    upcoming:fill(stationId, station)

    MaelstromMusic.Log.write("'" .. station.title .. "' now playing: " .. tostring(station.trackFiles[trackIndex]))

    entry.sound = sound
    Voices.prepareCompanion(entry, device, deviceData, staged)

    Voices.start(sound, trackName, station, deviceData:getDeviceVolume())
    if entry.companion then
        Voices.start(entry.companion, trackName, station, 0)
    end

    local x, y, z = Device.Location.of(device, deviceData)

    entry.orphanedAt = nil
    entry.device = device
    entry.deviceData = deviceData
    entry.stationId = stationId
    entry.trackIndex = trackIndex
    entry.x = x or entry.x or 0
    entry.y = y or entry.y or 0
    entry.z = z or entry.z or 0

    if not existing then
        MaelstromMusic.Playback.Cache.add(entry)
    end
end

-- Starts or adopts playback when a powered device is tuned to one of the stations.
function Device.ensurePlaying(device)
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

    if (not entry or entry.orphanedAt) and Device.Orphans.adopt(stationId, device, deviceData) then
        return
    end

    Device.playStation(stationId, device)
end

Events.OnPreMapLoad.Add(primeStations)
