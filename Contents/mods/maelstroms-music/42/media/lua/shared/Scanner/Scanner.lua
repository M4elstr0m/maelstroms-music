require "Namespace"
require "Log"
require "Safe"
require "Frequency"
require "Addons/AddonDiscovery"
require "Scanner/Discovery"
require "Scanner/Runtime"
require "Scanner/Sync"

if not MaelstromMusic.Broadcasts then MaelstromMusic.Broadcasts = {} end
if not MaelstromMusic.Backgrounds then MaelstromMusic.Backgrounds = {} end

-- Returns the base mod followed by the active addons.
local function buildSources()
    local sources = { { modId = MaelstromMusic.MOD_ID, name = "Maelstrom's Music" } }
    for _, addon in ipairs(MaelstromMusic.Addons.Discovery.scan()) do
        table.insert(sources, addon)
    end
    return sources
end

-- Logs the addons found next to the base mod.
local function logAddons(sources)
    if #sources <= 1 then
        return
    end
    local names = {}
    for i = 2, #sources do
        table.insert(names, sources[i].name .. " (" .. sources[i].modId .. ")")
    end
    MaelstromMusic.Log.write("found " .. #names .. " addon(s): " .. table.concat(names, ", "))
end

-- Returns the station ids in alphabetical order so every output is deterministic.
local function sortedStationIds(stations)
    local stationIds = {}
    for stationId, _ in pairs(stations) do
        table.insert(stationIds, stationId)
    end
    table.sort(stationIds)
    return stationIds
end

-- Splits the ids that sit on a dial from the others, and collects the fixed frequencies they ask for.
local function tunableStations(stations, stationIds)
    local tunableIds = {}
    local fixedFrequencyByStationId = {}
    for _, stationId in ipairs(stationIds) do
        local station = stations[stationId]
        if station.kind == "radio" or station.kind == "television" then
            table.insert(tunableIds, stationId)
            if station.fixedFrequency then
                fixedFrequencyByStationId[stationId] = station.fixedFrequency
            end
        end
    end
    return tunableIds, fixedFrequencyByStationId
end

-- Assigns frequencies to the tunable stations, logging those left without one.
local function assignFrequencies(tunableIds, fixedFrequencyByStationId)
    local frequencyByStationId = MaelstromMusic.Frequency.assign(tunableIds, fixedFrequencyByStationId)
    for _, stationId in ipairs(tunableIds) do
        if not frequencyByStationId[stationId] then
            MaelstromMusic.Log.write("could not assign a free frequency to '" .. stationId .. "', too many stations - skipping it.")
        end
    end
    return frequencyByStationId
end

-- Publishes the runtime tables the playback and the director read.
local function publish(stations, stationIds, tunableIds, frequencyByStationId)
    local Runtime = MaelstromMusic.Scanner.Runtime
    MaelstromMusic.Broadcasts = Runtime.broadcasts(stations, tunableIds, frequencyByStationId)
    MaelstromMusic.Backgrounds = Runtime.backgrounds(stations, stationIds)
    MaelstromMusic.MainMenuStation = stations["mainmenu"] and Runtime.pooled("mainmenu", stations["mainmenu"]) or nil
    MaelstromMusic.DeathStation = stations["death"] and Runtime.pooled("death", stations["death"]) or nil
end

-- Logs how many stations were loaded.
local function logCount()
    local count = 0
    for _ in pairs(MaelstromMusic.Broadcasts) do count = count + 1 end
    for _ in pairs(MaelstromMusic.Backgrounds) do count = count + 1 end
    if MaelstromMusic.MainMenuStation then count = count + 1 end
    MaelstromMusic.Log.write(count .. " station(s) loaded.")
end

-- Scans all sources, assigns frequencies, publishes the runtime tables and regenerates
-- the sound script when the manifest changed.
function MaelstromMusic.Scanner.run()
    MaelstromMusic.Safe.call("scan failed", function()
        local sources = buildSources()
        logAddons(sources)

        local stations = MaelstromMusic.Scanner.Discovery.stations(sources)
        local stationIds = sortedStationIds(stations)
        local tunableIds, fixedFrequencyByStationId = tunableStations(stations, stationIds)
        local frequencyByStationId = assignFrequencies(tunableIds, fixedFrequencyByStationId)

        publish(stations, stationIds, tunableIds, frequencyByStationId)
        MaelstromMusic.Scanner.Sync.run(stations, stationIds)
        logCount()

        MaelstromMusic.ScanComplete = true
    end)
end

Events.OnGameBoot.Add(MaelstromMusic.Scanner.run)
Events.OnModsModified.Add(MaelstromMusic.Scanner.run)
