require "Namespace"
require "Log"
require "Fs"
require "Scanner/Station"
require "Scanner/Merge"
require "Scanner/Pools"

MaelstromMusic.Scanner.Stations = {}

-- Loads the stations of a directory across the given sources, in source order.
local function collectEntries(sources, baseDir, kind)
    local entries = {}
    for _, source in ipairs(sources) do
        for _, fileName in ipairs(MaelstromMusic.Fs.listFilesFrom(source.modId, baseDir)) do
            local stationId, station = MaelstromMusic.Scanner.Station.tryLoad(source.modId, baseDir, kind, fileName)
            if stationId then
                table.insert(entries, { stationId = stationId, station = station })
            end
        end
    end
    return entries
end

-- Adds the backgrounds of the first source that has any, and reports the others as ignored.
local function addBackgrounds(sources, stations)
    local winner = nil
    for _, source in ipairs(sources) do
        local entries = collectEntries({ source }, MaelstromMusic.BACKGROUNDS_DIR, "background")
        if #entries > 0 then
            if not winner then
                winner = source
                for _, entry in ipairs(entries) do
                    stations[entry.stationId] = entry.station
                end
            else
                MaelstromMusic.Log.write("background soundtrack from '" .. source.name .. "' (" .. source.modId .. ") was ignored because '" .. winner.name .. "' (" .. winner.modId .. ") already provides one - only one background soundtrack can be active at a time.")
            end
        end
    end
end

-- Discovers every station of every source: radios, TVs, one background set (first source wins),
-- plus the main menu and game over pools.
function MaelstromMusic.Scanner.Stations.discover(sources)
    local stations = {}
    MaelstromMusic.Scanner.Merge.shared(collectEntries(sources, MaelstromMusic.RADIOS_DIR, "radio"), stations)
    MaelstromMusic.Scanner.Merge.shared(collectEntries(sources, MaelstromMusic.TVS_DIR, "television"), stations)
    addBackgrounds(sources, stations)
    stations["mainmenu"] = MaelstromMusic.Scanner.Pools.mainMenu(sources)
    stations["death"] = MaelstromMusic.Scanner.Pools.death(sources)
    return stations
end
