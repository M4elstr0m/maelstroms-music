require "Namespace"

MaelstromMusic.Scanner.Script = {}

MaelstromMusic.Scanner.Script.SCHEMA_VERSION = 6

local WORLD_DISTANCE_MIN = 2
local WORLD_DISTANCE_MAX = 75
local FLAT_DISTANCE_MAX = 75

-- Name of the sound script entry that plays one track of a station.
function MaelstromMusic.Scanner.Script.soundName(stationId, index)
    return "BroadcastTrack_" .. stationId .. "_" .. index
end

-- Only radios and TVs play in the world, a 3D sound ticking without a player crashes the menu.
local function spatialProperties(kind)
    if kind == "radio" or kind == "television" then
        return "true", "\t\t\tdistanceMin = " .. WORLD_DISTANCE_MIN .. ",\n\t\t\tdistanceMax = " .. WORLD_DISTANCE_MAX .. ",\n"
    end
    return "false", "\t\t\tdistanceMax = " .. FLAT_DISTANCE_MAX .. ",\n"
end

-- Builds one sound script definition per track of a station.
local function buildTrackSounds(stationId, station)
    local is3D, distances = spatialProperties(station.kind)
    local definitions = {}
    for index, trackFile in ipairs(station.trackFiles) do
        local soundName = MaelstromMusic.Scanner.Script.soundName(stationId, index)
        local rawName = station.trackDirs and station.trackDirs[index] or station.rawName
        local filePath = rawName ~= "" and (station.rawDir .. "/" .. rawName .. "/" .. trackFile) or (station.rawDir .. "/" .. trackFile)
        table.insert(definitions, "\tsound " .. soundName .. "\n" ..
            "\t{\n" ..
            "\t\tcategory = Maelstrom Music,\n" ..
            "\t\tmaster = Ambient,\n" ..
            "\t\tis3D = " .. is3D .. ",\n" ..
            "\t\tclip\n" ..
            "\t\t{\n" ..
            "\t\t\tfile = " .. filePath .. ",\n" ..
            distances ..
            "\t\t}\n" ..
            "\t}\n\n")
    end
    return definitions
end

-- Builds the generated sound script holding every track of every station.
function MaelstromMusic.Scanner.Script.generate(stations, stationIds)
    local parts = { "module MaelstromMusic\n{\n" }
    for _, stationId in ipairs(stationIds) do
        for _, definition in ipairs(buildTrackSounds(stationId, stations[stationId])) do
            table.insert(parts, definition)
        end
    end
    table.insert(parts, "}\n")
    return table.concat(parts)
end

-- Builds the diffable manifest text, any change in it triggers a regeneration of the sound script.
function MaelstromMusic.Scanner.Script.manifest(stations, stationIds)
    local lines = { "schema|" .. MaelstromMusic.Scanner.Script.SCHEMA_VERSION }
    for _, stationId in ipairs(stationIds) do
        local station = stations[stationId]
        table.insert(lines, stationId .. "|" .. station.title .. "|" .. tostring(station.shuffle) .. "|" .. table.concat(station.trackFiles, ","))
    end
    return table.concat(lines, "\n")
end
