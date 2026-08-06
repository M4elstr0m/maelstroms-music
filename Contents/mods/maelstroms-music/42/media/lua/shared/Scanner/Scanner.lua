require "Namespace"
require "Log"
require "Safe"
require "Fs"
require "Station"
require "Manifest"
require "Frequency"
require "AddonDiscovery"

local MANIFEST_FILE = MaelstromMusic.RADIOS_DIR .. "/_radios_manifest.txt"
local GENERATED_SCRIPT_FILE = "media/scripts/GeneratedRadios.txt"
local MAINMENU_EXTENSIONS = { mp3 = true, ogg = true, wav = true }

if not MaelstromMusic.Broadcasts then MaelstromMusic.Broadcasts = {} end
if not MaelstromMusic.Backgrounds then MaelstromMusic.Backgrounds = {} end

local function discoverInDir(modId, baseDir, kind, stations)
    for _, fileName in ipairs(MaelstromMusic.Fs.listFilesFrom(modId, baseDir)) do
        local stationId, station = MaelstromMusic.Scanner.Station.tryLoad(modId, baseDir, kind, fileName)
        if stationId then
            stations[stationId] = station
        end
    end
end

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

-- Stations opted into "mergeTracks" and sharing the same title (case-insensitive) are
-- folded into a single station, tracks from every contributor. First source encountered
-- (base mod, then addons in modId order) keeps its stationId and wins on shuffle/fade/
-- frequency for the rest. Stations without mergeTracks never merge with anything, even
-- if another station happens to share their title.
local function mergeSharedStations(entries, stations)
    local primaryIdByTitle = {}
    for _, entry in ipairs(entries) do
        local stationId, station = entry.stationId, entry.station
        if station.mergeTracks then
            local key = string.lower(station.title)
            local primaryId = primaryIdByTitle[key]
            if not primaryId then
                primaryIdByTitle[key] = stationId
                stations[stationId] = station
            else
                local primary = stations[primaryId]
                for i, trackFile in ipairs(station.trackFiles) do
                    table.insert(primary.trackFiles, trackFile)
                    table.insert(primary.trackDirs, station.trackDirs[i])
                end
                MaelstromMusic.Log.write("merged " .. #station.trackFiles .. " track(s) from '" .. station.ownerModId .. "' into shared " .. station.kind .. " '" .. primary.title .. "' (owned by '" .. primary.ownerModId .. "') via mergeTracks.")
            end
        else
            stations[stationId] = station
        end
    end
end

local function getExtension(fileName)
    local ext = string.match(fileName, "%.([%a%d]+)$")
    return ext and string.lower(ext) or nil
end

local function findMainMenuFiles(modId)
    local files = {}
    for _, fileName in ipairs(MaelstromMusic.Fs.listFilesFrom(modId, MaelstromMusic.MAINMENU_DIR)) do
        local ext = getExtension(fileName)
        if ext and MAINMENU_EXTENSIONS[ext] then
            if string.find(fileName, ",", 1, true) then
                MaelstromMusic.Log.write("skipping '" .. fileName .. "' - a comma in the filename breaks Project Zomboid's sound script parser. Rename the file to remove the comma.")
            else
                table.insert(files, fileName)
            end
        end
    end
    table.sort(files)
    return files
end

local function collectMainMenuFiles(sources)
    local trackFiles = {}
    local contributingSources = 0
    for _, source in ipairs(sources) do
        local files = findMainMenuFiles(source.modId)
        if #files > 0 then
            contributingSources = contributingSources + 1
            for _, fileName in ipairs(files) do
                table.insert(trackFiles, fileName)
            end
        end
    end
    if contributingSources > 1 then
        MaelstromMusic.Log.write("main menu theme: combining " .. #trackFiles .. " track(s) from " .. contributingSources .. " source(s), played in random order.")
    end
    return trackFiles
end

local function buildSources()
    local sources = { { modId = MaelstromMusic.MOD_ID, name = "Maelstrom's Music" } }
    for _, addon in ipairs(MaelstromMusic.Addons.Discovery.scan()) do
        table.insert(sources, addon)
    end
    return sources
end

local function isEmpty(t)
    for _ in pairs(t) do
        return false
    end
    return true
end

local function discoverStations(sources)
    local stations = {}

    mergeSharedStations(collectEntries(sources, MaelstromMusic.RADIOS_DIR, "radio"), stations)
    mergeSharedStations(collectEntries(sources, MaelstromMusic.TVS_DIR, "television"), stations)

    local backgroundWinner = nil
    for _, source in ipairs(sources) do
        local candidate = {}
        discoverInDir(source.modId, MaelstromMusic.BACKGROUNDS_DIR, "background", candidate)
        if not isEmpty(candidate) then
            if not backgroundWinner then
                backgroundWinner = source
                for stationId, station in pairs(candidate) do
                    stations[stationId] = station
                end
            else
                MaelstromMusic.Log.write("background soundtrack from '" .. source.name .. "' (" .. source.modId .. ") was ignored because '" .. backgroundWinner.name .. "' (" .. backgroundWinner.modId .. ") already provides one - only one background soundtrack can be active at a time.")
            end
        end
    end

    local mainMenuFiles = collectMainMenuFiles(sources)
    if #mainMenuFiles > 0 then
        stations["mainmenu"] = {
            ownerModId = MaelstromMusic.MOD_ID,
            rawDir = MaelstromMusic.MAINMENU_DIR,
            rawName = "",
            kind = "mainmenu",
            title = "Main Menu Theme",
            shuffle = true,
            trackFiles = mainMenuFiles,
        }
    end

    return stations
end

function MaelstromMusic.Scanner.run()
    MaelstromMusic.Safe.call("scan failed", function()
        local sources = buildSources()
        if #sources > 1 then
            local names = {}
            for i = 2, #sources do
                table.insert(names, sources[i].name .. " (" .. sources[i].modId .. ")")
            end
            MaelstromMusic.Log.write("found " .. #names .. " addon(s): " .. table.concat(names, ", "))
        end

        local stations = discoverStations(sources)
        local stationIds = MaelstromMusic.Scanner.Manifest.sortedStationIds(stations)

        local tunableIds = {}
        local fixedFrequencyByStationId = {}
        for _, stationId in ipairs(stationIds) do
            local station = stations[stationId]
            if station.kind ~= "background" and station.kind ~= "mainmenu" then
                table.insert(tunableIds, stationId)
                if station.fixedFrequency then
                    fixedFrequencyByStationId[stationId] = station.fixedFrequency
                end
            end
        end

        local frequencyByStationId = MaelstromMusic.Frequency.assign(tunableIds, fixedFrequencyByStationId)
        for _, stationId in ipairs(tunableIds) do
            if not frequencyByStationId[stationId] then
                MaelstromMusic.Log.write("could not assign a free frequency to '" .. stationId .. "', too many stations - skipping it.")
            end
        end

        MaelstromMusic.Broadcasts = MaelstromMusic.Scanner.Manifest.buildStations(stations, tunableIds, frequencyByStationId)
        MaelstromMusic.Backgrounds = MaelstromMusic.Scanner.Manifest.buildBackgrounds(stations, stationIds)
        MaelstromMusic.MainMenuStation = stations["mainmenu"] and MaelstromMusic.Scanner.Manifest.buildMainMenu(stations["mainmenu"]) or nil

        local newManifest = MaelstromMusic.Scanner.Manifest.buildText(stations, stationIds)
        local oldManifest = MaelstromMusic.Fs.readFile(MANIFEST_FILE)

        if newManifest ~= oldManifest then
            MaelstromMusic.Log.write("detected new/changed stations, regenerating sounds...")
            local scriptText = MaelstromMusic.Scanner.Manifest.buildGeneratedScript(stations, stationIds)
            local wroteScript = MaelstromMusic.Fs.writeFile(GENERATED_SCRIPT_FILE, scriptText)
            MaelstromMusic.Fs.writeFile(MANIFEST_FILE, newManifest)

            if wroteScript then
                local reloaded = pcall(reloadSoundFiles)
                if not reloaded then
                    MaelstromMusic.Log.write("reloadSoundFiles() failed - a restart may be needed for new stations to play.")
                end
            else
                MaelstromMusic.Log.write("could not write generated sound script - a restart may be needed for new stations to play.")
            end
        end

        local count = 0
        for _ in pairs(MaelstromMusic.Broadcasts) do count = count + 1 end
        for _ in pairs(MaelstromMusic.Backgrounds) do count = count + 1 end
        if MaelstromMusic.MainMenuStation then count = count + 1 end
        MaelstromMusic.Log.write(count .. " station(s) loaded.")

        MaelstromMusic.ScanComplete = true
    end)
end

Events.OnGameBoot.Add(MaelstromMusic.Scanner.run)
Events.OnModsModified.Add(MaelstromMusic.Scanner.run)
