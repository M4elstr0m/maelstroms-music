require "Namespace"
require "Log"
require "Fs"
require "Scanner/Script"

MaelstromMusic.Scanner.Sync = {}

local MANIFEST_FILE = MaelstromMusic.RADIOS_DIR .. "/_radios_manifest.txt"
local GENERATED_SCRIPT_FILE = "media/scripts/GeneratedRadios.txt"

-- Regenerates the sound script and reloads the game sounds when the stations differ from the saved manifest.
function MaelstromMusic.Scanner.Sync.run(stations, stationIds)
    local newManifest = MaelstromMusic.Scanner.Script.manifest(stations, stationIds)
    if newManifest == MaelstromMusic.Fs.readFile(MANIFEST_FILE) then
        return
    end

    MaelstromMusic.Log.write("detected new/changed stations, regenerating sounds...")
    local scriptText = MaelstromMusic.Scanner.Script.generate(stations, stationIds)
    local wroteScript = MaelstromMusic.Fs.writeFile(GENERATED_SCRIPT_FILE, scriptText)
    MaelstromMusic.Fs.writeFile(MANIFEST_FILE, newManifest)

    if not wroteScript then
        MaelstromMusic.Log.write("could not write generated sound script - a restart may be needed for new stations to play.")
        return
    end
    if not pcall(reloadSoundFiles) then
        MaelstromMusic.Log.write("reloadSoundFiles() failed - a restart may be needed for new stations to play.")
    end
end
