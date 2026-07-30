require "Namespace"
require "Log"
require "Safe"
require "Fs"
require "Station"
require "Manifest"
require "Frequency"

local MANIFEST_FILE = MaelstromMusic.RADIOS_DIR .. "/_radios_manifest.txt"
local GENERATED_SCRIPT_FILE = "media/scripts/GeneratedRadios.txt"
local MAINMENU_EXTENSIONS = { mp3 = true, ogg = true, wav = true }

if not MaelstromMusic.Broadcasts then MaelstromMusic.Broadcasts = {} end
if not MaelstromMusic.Backgrounds then MaelstromMusic.Backgrounds = {} end

local function discoverInDir(baseDir, kind, stations)
    for _, fileName in ipairs(MaelstromMusic.Fs.listFiles(baseDir)) do
        local stationId, station = MaelstromMusic.Scanner.Station.tryLoad(baseDir, kind, fileName)
        if stationId then
            stations[stationId] = station
        end
    end
end

local function getExtension(fileName)
    local ext = string.match(fileName, "%.([%a%d]+)$")
    return ext and string.lower(ext) or nil
end

local function discoverMainMenu(stations)
    local files = {}
    for _, fileName in ipairs(MaelstromMusic.Fs.listFiles(MaelstromMusic.MAINMENU_DIR)) do
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
        return
    end
    table.sort(files)
    if #files > 1 then
        MaelstromMusic.Log.write("found " .. #files .. " files in " .. MaelstromMusic.MAINMENU_DIR .. ", using '" .. files[1] .. "' and ignoring the rest.")
    end

    stations["mainmenu"] = {
        rawDir = MaelstromMusic.MAINMENU_DIR,
        rawName = "",
        kind = "mainmenu",
        title = "Main Menu Theme",
        shuffle = false,
        trackFiles = { files[1] },
    }
end

local function discoverStations()
    local stations = {}
    discoverInDir(MaelstromMusic.RADIOS_DIR, "radio", stations)
    discoverInDir(MaelstromMusic.TVS_DIR, "television", stations)
    discoverInDir(MaelstromMusic.BACKGROUNDS_DIR, "background", stations)
    discoverMainMenu(stations)
    return stations
end

function MaelstromMusic.Scanner.run()
    MaelstromMusic.Safe.call("scan failed", function()
        local stations = discoverStations()
        local stationIds = MaelstromMusic.Scanner.Manifest.sortedStationIds(stations)

        local tunableIds = {}
        for _, stationId in ipairs(stationIds) do
            local kind = stations[stationId].kind
            if kind ~= "background" and kind ~= "mainmenu" then
                table.insert(tunableIds, stationId)
            end
        end

        local frequencyByStationId = MaelstromMusic.Frequency.assign(tunableIds)
        for _, stationId in ipairs(tunableIds) do
            if not frequencyByStationId[stationId] then
                MaelstromMusic.Log.write("could not assign a free frequency to '" .. stationId .. "', too many stations - skipping it.")
            end
        end

        MaelstromMusic.Broadcasts = MaelstromMusic.Scanner.Manifest.buildStations(stations, tunableIds, frequencyByStationId)
        MaelstromMusic.Backgrounds = MaelstromMusic.Scanner.Manifest.buildBackgrounds(stations, stationIds)
        MaelstromMusic.MainMenuTrack = stations["mainmenu"] and "BroadcastTrack_mainmenu_1" or nil

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
