require "Namespace"
require "Scanner/Script"
require "Scanner/Sequences"

MaelstromMusic.Scanner.Runtime = {}

-- The sound script names of the tracks of a station, in track order.
local function soundNames(stationId, station)
    local names = {}
    for index = 1, #station.trackFiles do
        names[index] = MaelstromMusic.Scanner.Script.soundName(stationId, index)
    end
    return names
end

-- Builds the runtime radio and TV station tables, skipping stations that got no frequency.
function MaelstromMusic.Scanner.Runtime.broadcasts(stations, stationIds, frequencyByStationId)
    local result = {}
    for _, stationId in ipairs(stationIds) do
        local frequency = frequencyByStationId[stationId]
        if frequency then
            local station = stations[stationId]
            local forcedNext, gated = MaelstromMusic.Scanner.Sequences.resolve(station)
            result[stationId] = {
                title = station.title,
                shuffle = station.shuffle,
                fade = station.fade,
                kind = station.kind,
                tracks = soundNames(stationId, station),
                trackFiles = station.trackFiles,
                frequency = frequency,
                autoPreset = station.autoPreset and not station.fixedFrequency,
                forcedNext = forcedNext,
                gated = gated,
            }
        end
    end
    return result
end

-- Builds a runtime station from a pooled track list (main menu theme, game over).
function MaelstromMusic.Scanner.Runtime.pooled(stationId, station)
    return {
        title = station.title,
        shuffle = station.shuffle,
        tracks = soundNames(stationId, station),
        trackFiles = station.trackFiles,
    }
end

-- Builds the runtime tables of the adaptive background moods.
function MaelstromMusic.Scanner.Runtime.backgrounds(stations, stationIds)
    local result = {}
    for _, stationId in ipairs(stationIds) do
        local station = stations[stationId]
        if station.kind == "background" then
            result[stationId] = {
                title = station.title,
                shuffle = station.shuffle,
                drama = station.drama,
                tracks = soundNames(stationId, station),
                trackFiles = station.trackFiles,
            }
        end
    end
    return result
end
