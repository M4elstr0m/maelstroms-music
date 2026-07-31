require "Namespace"

MaelstromMusic.Scanner.Manifest = {}

function MaelstromMusic.Scanner.Manifest.sortedStationIds(stations)
    local stationIds = {}
    for stationId, _ in pairs(stations) do
        table.insert(stationIds, stationId)
    end
    table.sort(stationIds)
    return stationIds
end

function MaelstromMusic.Scanner.Manifest.buildText(stations, stationIds)
    local lines = {}
    for _, stationId in ipairs(stationIds) do
        local station = stations[stationId]
        table.insert(lines, stationId .. "|" .. station.title .. "|" .. tostring(station.shuffle) .. "|" .. table.concat(station.trackFiles, ","))
    end
    return table.concat(lines, "\n")
end

function MaelstromMusic.Scanner.Manifest.buildGeneratedScript(stations, stationIds)
    local parts = { "module MaelstromMusic\n{\n" }
    for _, stationId in ipairs(stationIds) do
        local station = stations[stationId]
        for index, trackFile in ipairs(station.trackFiles) do
            local soundName = "BroadcastTrack_" .. stationId .. "_" .. index
            local filePath = station.rawName ~= "" and (station.rawDir .. "/" .. station.rawName .. "/" .. trackFile) or (station.rawDir .. "/" .. trackFile)
            table.insert(parts, "\tsound " .. soundName .. "\n" ..
                "\t{\n" ..
                "\t\tcategory = Maelstrom Music,\n" ..
                "\t\tmaster = Ambient,\n" ..
                "\t\tclip\n" ..
                "\t\t{\n" ..
                "\t\t\tfile = " .. filePath .. ",\n" ..
                "\t\t\tdistanceMax = 75,\n" ..
                "\t\t}\n" ..
                "\t}\n\n")
        end
    end
    table.insert(parts, "}\n")
    return table.concat(parts)
end

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
            result[stationId] = {
                title = station.title,
                shuffle = station.shuffle,
                fade = station.fade,
                kind = station.kind,
                tracks = trackNames,
                frequency = frequency,
                autoPreset = not station.fixedFrequency,
            }
        end
    end
    return result
end

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
            }
        end
    end
    return result
end
