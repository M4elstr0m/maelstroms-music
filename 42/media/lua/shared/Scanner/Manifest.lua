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
            local soundName = "RadioTrack_" .. stationId .. "_" .. index
            table.insert(parts, "\tsound " .. soundName .. "\n" ..
                "\t{\n" ..
                "\t\tcategory = Maelstrom Music,\n" ..
                "\t\tmaster = Ambient,\n" ..
                "\t\tclip\n" ..
                "\t\t{\n" ..
                "\t\t\tfile = " .. MaelstromMusic.RADIOS_DIR .. "/" .. station.rawName .. "/" .. trackFile .. ",\n" ..
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
                table.insert(trackNames, "RadioTrack_" .. stationId .. "_" .. index)
            end
            result[stationId] = {
                title = station.title,
                shuffle = station.shuffle,
                tracks = trackNames,
                frequency = frequency,
            }
        end
    end
    return result
end
