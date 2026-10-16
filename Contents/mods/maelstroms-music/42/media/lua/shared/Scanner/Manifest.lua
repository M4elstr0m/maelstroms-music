require "Namespace"

MaelstromMusic.Scanner.Manifest = {}

-- Returns the station ids in alphabetical order so every output is deterministic.
function MaelstromMusic.Scanner.Manifest.sortedStationIds(stations)
    local stationIds = {}
    for stationId, _ in pairs(stations) do
        table.insert(stationIds, stationId)
    end
    table.sort(stationIds)
    return stationIds
end

local SCRIPT_SCHEMA_VERSION = 6

local WORLD_DISTANCE_MIN = 2
local WORLD_DISTANCE_MAX = 75
local FLAT_DISTANCE_MAX = 75

-- Only radios and TVs play in the world, a 3D sound ticking without a player crashes the menu.
local function spatialProperties(kind)
    if kind == "radio" or kind == "television" then
        return "true", "\t\t\tdistanceMin = " .. WORLD_DISTANCE_MIN .. ",\n\t\t\tdistanceMax = " .. WORLD_DISTANCE_MAX .. ",\n"
    end
    return "false", "\t\t\tdistanceMax = " .. FLAT_DISTANCE_MAX .. ",\n"
end

-- Builds the diffable manifest text, any change in it triggers a regeneration of the sound script.
function MaelstromMusic.Scanner.Manifest.buildText(stations, stationIds)
    local lines = { "schema|" .. SCRIPT_SCHEMA_VERSION }
    for _, stationId in ipairs(stationIds) do
        local station = stations[stationId]
        table.insert(lines, stationId .. "|" .. station.title .. "|" .. tostring(station.shuffle) .. "|" .. table.concat(station.trackFiles, ","))
    end
    return table.concat(lines, "\n")
end

-- Builds one sound script definition per track of a station.
local function buildTrackSounds(stationId, station)
    local is3D, distances = spatialProperties(station.kind)
    local definitions = {}
    for index, trackFile in ipairs(station.trackFiles) do
        local soundName = "BroadcastTrack_" .. stationId .. "_" .. index
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
function MaelstromMusic.Scanner.Manifest.buildGeneratedScript(stations, stationIds)
    local parts = { "module MaelstromMusic\n{\n" }
    for _, stationId in ipairs(stationIds) do
        for _, definition in ipairs(buildTrackSounds(stationId, stations[stationId])) do
            table.insert(parts, definition)
        end
    end
    table.insert(parts, "}\n")
    return table.concat(parts)
end

-- forcedNext[beforeIndex] = afterIndex drives the forced hand-off itself. gated[index] marks
-- a track as an "after" target - those never come up on their own, only via their forced
-- predecessor(s), even in a chain (a track can be both a "before" and an "after" at once).
local function buildSequenceInfo(station)
    if not station.sequences then
        return nil, nil
    end
    local indexByFile = {}
    for index, trackFile in ipairs(station.trackFiles) do
        if not indexByFile[trackFile] then
            indexByFile[trackFile] = index
        end
    end
    local forcedNext = nil
    local gated = nil
    for _, seq in ipairs(station.sequences) do
        local beforeIndex = indexByFile[seq.before]
        local afterIndex = indexByFile[seq.after]
        if beforeIndex and afterIndex then
            forcedNext = forcedNext or {}
            if forcedNext[beforeIndex] and forcedNext[beforeIndex] ~= afterIndex then
                MaelstromMusic.Log.write("'" .. station.title .. "' has more than one \"sequences\" entry for '" .. seq.before .. "' - keeping the last one.")
            end
            forcedNext[beforeIndex] = afterIndex
            gated = gated or {}
            gated[afterIndex] = true
        else
            MaelstromMusic.Log.write("'" .. station.title .. "' has a \"sequences\" entry referencing a track that isn't in this station ('" .. seq.before .. "' -> '" .. seq.after .. "'), skipping it.")
        end
    end
    if gated then
        local gatedCount = 0
        for _ in pairs(gated) do
            gatedCount = gatedCount + 1
        end
        if gatedCount >= #station.trackFiles then
            MaelstromMusic.Log.write("'" .. station.title .. "' has every track gated by \"sequences\" - nothing can ever play, since at least one track must be reachable on its own.")
        end
    end
    if forcedNext then
        local reported = {}
        for start, _ in pairs(forcedNext) do
            if not reported[start] then
                local visited = {}
                local current = start
                while current and forcedNext[current] and not visited[current] do
                    visited[current] = true
                    current = forcedNext[current]
                end
                if current and visited[current] then
                    for node in pairs(visited) do
                        reported[node] = true
                    end
                    MaelstromMusic.Log.write("'" .. station.title .. "' has a \"sequences\" cycle (some chain of \"before\"/\"after\" entries loops back on itself) - once entered it plays forever and every other track becomes unreachable. Check your chain for a loop.")
                end
            end
        end
    end
    return forcedNext, gated
end

-- Builds the runtime radio and TV station tables, skipping stations that got no frequency.
function MaelstromMusic.Scanner.Manifest.buildStations(stations, stationIds, frequencyByStationId)
    local result = {}
    for _, stationId in ipairs(stationIds) do
        local frequency = frequencyByStationId[stationId]
        if frequency then
            local station = stations[stationId]
            local trackNames = {}
            for index, _ in ipairs(station.trackFiles) do
                table.insert(trackNames, "BroadcastTrack_" .. stationId .. "_" .. index)
            end
            local forcedNext, gated = buildSequenceInfo(station)
            result[stationId] = {
                title = station.title,
                shuffle = station.shuffle,
                fade = station.fade,
                kind = station.kind,
                tracks = trackNames,
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
function MaelstromMusic.Scanner.Manifest.buildPooledStation(stationId, station)
    local trackNames = {}
    for index, _ in ipairs(station.trackFiles) do
        table.insert(trackNames, "BroadcastTrack_" .. stationId .. "_" .. index)
    end
    return {
        title = station.title,
        shuffle = station.shuffle,
        tracks = trackNames,
        trackFiles = station.trackFiles,
    }
end

-- Builds the runtime tables of the adaptive background moods.
function MaelstromMusic.Scanner.Manifest.buildBackgrounds(stations, stationIds)
    local result = {}
    for _, stationId in ipairs(stationIds) do
        local station = stations[stationId]
        if station.kind == "background" then
            local trackNames = {}
            for index, _ in ipairs(station.trackFiles) do
                table.insert(trackNames, "BroadcastTrack_" .. stationId .. "_" .. index)
            end
            result[stationId] = {
                title = station.title,
                shuffle = station.shuffle,
                drama = station.drama,
                tracks = trackNames,
                trackFiles = station.trackFiles,
            }
        end
    end
    return result
end
