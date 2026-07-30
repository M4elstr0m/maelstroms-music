require "Namespace"

MaelstromMusic.Playback.Cache = {}
MaelstromMusic.Playback.Cache.entries = {}

local frequencyToStation = {}
local frequencyToStationBuiltFor = nil

function MaelstromMusic.Playback.Cache.ensureFrequencyMap()
    if frequencyToStationBuiltFor == MaelstromMusic.Stations then
        return
    end
    frequencyToStation = {}
    if MaelstromMusic.Stations then
        for stationId, station in pairs(MaelstromMusic.Stations) do
            frequencyToStation[station.frequency] = stationId
        end
    end
    frequencyToStationBuiltFor = MaelstromMusic.Stations
end

function MaelstromMusic.Playback.Cache.stationForFrequency(frequency)
    return frequencyToStation[frequency]
end

function MaelstromMusic.Playback.Cache.get(deviceData)
    for _, entry in ipairs(MaelstromMusic.Playback.Cache.entries) do
        if entry.deviceData == deviceData then
            return entry
        end
    end
    return nil
end

function MaelstromMusic.Playback.Cache.add(entry)
    table.insert(MaelstromMusic.Playback.Cache.entries, entry)
end

function MaelstromMusic.Playback.Cache.remove(entry)
    for index, existing in ipairs(MaelstromMusic.Playback.Cache.entries) do
        if existing == entry then
            table.remove(MaelstromMusic.Playback.Cache.entries, index)
            return
        end
    end
end

function MaelstromMusic.Playback.Cache.removeAt(index)
    table.remove(MaelstromMusic.Playback.Cache.entries, index)
end
