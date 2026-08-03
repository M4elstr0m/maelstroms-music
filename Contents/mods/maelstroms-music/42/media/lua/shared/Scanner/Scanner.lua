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

local function getExtension(fileName)
    local ext = string.match(fileName, "%.([%a%d]+)$")
    return ext and string.lower(ext) or nil
end

local function findMainMenuFile(modId)
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
    if #files == 0 then
        return nil
    end
    table.sort(files)
    if #files > 1 then
        MaelstromMusic.Log.write("found " .. #files .. " files in " .. MaelstromMusic.MAINMENU_DIR .. " for mod '" .. modId .. "', using '" .. files[1] .. "' and ignoring the rest.")
    end
    return files[1]
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

    for _, source in ipairs(sources) do
        discoverInDir(source.modId, MaelstromMusic.RADIOS_DIR, "radio", stations)
        discoverInDir(source.modId, MaelstromMusic.TVS_DIR, "television", stations)
    end

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

    local mainMenuWinner = nil
    for _, source in ipairs(sources) do
        local fileName = findMainMenuFile(source.modId)
        if fileName then
            if not mainMenuWinner then
                mainMenuWinner = source
                stations["mainmenu"] = {
                    ownerModId = source.modId,
                    rawDir = MaelstromMusic.MAINMENU_DIR,
                    rawName = "",
                    kind = "mainmenu",
                    title = "Main Menu Theme",
                    shuffle = false,
                    trackFiles = { fileName },
                }
            else
                MaelstromMusic.Log.write("main menu theme from '" .. source.name .. "' (" .. source.modId .. ") was ignored because '" .. mainMenuWinner.name .. "' (" .. mainMenuWinner.modId .. ") already provides one - only one main menu theme can be active at a time.")
            end
        end
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
        MaelstromMusic.MainMenuTrack = stations["mainmenu"] and "BroadcastTrack_mainmenu_1" or nil
        MaelstromMusic.MainMenuTrackFile = stations["mainmenu"] and stations["mainmenu"].trackFiles[1] or nil

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
        if MaelstromMusic.MainMenuTrack then count = count + 1 end
        MaelstromMusic.Log.write(count .. " station(s) loaded.")

        MaelstromMusic.ScanComplete = true
    end)
end

Events.OnGameBoot.Add(MaelstromMusic.Scanner.run)
Events.OnModsModified.Add(MaelstromMusic.Scanner.run)
