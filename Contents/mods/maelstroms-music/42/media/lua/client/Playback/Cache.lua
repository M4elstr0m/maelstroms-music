require "Namespace"

MaelstromMusic.Playback.Cache = {}
MaelstromMusic.Playback.Cache.entries = {}

local frequencyToStation = {}
local frequencyToStationBuiltFor = nil

function MaelstromMusic.Playback.Cache.ensureFrequencyMap()
    if frequencyToStationBuiltFor == MaelstromMusic.Broadcasts then
        return
    end
    frequencyToStation = {}
    if MaelstromMusic.Broadcasts then
        for stationId, station in pairs(MaelstromMusic.Broadcasts) do
            frequencyToStation[station.frequency] = stationId
        end
    end
    frequencyToStationBuiltFor = MaelstromMusic.Broadcasts
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

function MaelstromMusic.Playback.Cache.takeOrphan(stationId, x, y, maxDistance)
    for _, entry in ipairs(MaelstromMusic.Playback.Cache.entries) do
        if entry.orphanedAt and entry.stationId == stationId and entry.sound:isPlaying() then
            if not x or math.sqrt((entry.x - x) ^ 2 + (entry.y - y) ^ 2) <= maxDistance then
                return entry
            end
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
