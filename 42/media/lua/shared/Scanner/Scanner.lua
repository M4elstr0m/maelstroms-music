require "Namespace"
require "Log"
require "Safe"
require "Fs"
require "Station"
require "Manifest"
require "Frequency"

local MANIFEST_FILE = MaelstromMusic.RADIOS_DIR .. "/_radios_manifest.txt"
local GENERATED_SCRIPT_FILE = "media/scripts/GeneratedRadios.txt"

if not MaelstromMusic.Broadcasts then MaelstromMusic.Broadcasts = {} end

local function discoverInDir(baseDir, kind, stations)
    for _, fileName in ipairs(MaelstromMusic.Fs.listFiles(baseDir)) do
        local stationId, station = MaelstromMusic.Scanner.Station.tryLoad(baseDir, kind, fileName)
        if stationId then
            stations[stationId] = station
        end
    end
end

local function discoverStations()
    local stations = {}
    discoverInDir(MaelstromMusic.RADIOS_DIR, "radio", stations)
    discoverInDir(MaelstromMusic.TVS_DIR, "television", stations)
    return stations
end

function MaelstromMusic.Scanner.run()
    MaelstromMusic.Safe.call("scan failed", function()
        local stations = discoverStations()
        local stationIds = MaelstromMusic.Scanner.Manifest.sortedStationIds(stations)
        local frequencyByStationId = MaelstromMusic.Frequency.assign(stationIds)

        for _, stationId in ipairs(stationIds) do
            if not frequencyByStationId[stationId] then
                MaelstromMusic.Log.write("could not assign a free frequency to '" .. stationId .. "', too many stations - skipping it.")
            end
        end

        MaelstromMusic.Broadcasts = MaelstromMusic.Scanner.Manifest.buildStations(stations, stationIds, frequencyByStationId)

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
        MaelstromMusic.Log.write(count .. " station(s) loaded.")

        MaelstromMusic.ScanComplete = true
    end)
end

Events.OnGameBoot.Add(MaelstromMusic.Scanner.run)
