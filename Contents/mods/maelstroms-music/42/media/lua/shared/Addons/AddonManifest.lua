require "Namespace"
require "Log"
require "Fs"
require "Json"

MaelstromMusic.Addons.Manifest = {}

local MARKER_FILE = "maelstroms-music-addon.json"
local MARKER_TYPE = "maelstroms-music-addon"
local SUPPORTED_API_VERSIONS = { [1] = true }

function MaelstromMusic.Addons.Manifest.read(modId)
    local text = MaelstromMusic.Fs.readFileFrom(modId, MARKER_FILE)
    if not text then
        return nil
    end

    local data = MaelstromMusic.Json.decode(text)
    if not (data and type(data) == "table") then
        MaelstromMusic.Log.write("addon marker in mod '" .. modId .. "' is not valid JSON, ignoring it.")
        return nil
    end

    if data.addon ~= MARKER_TYPE then
        MaelstromMusic.Log.write("addon marker in mod '" .. modId .. "' has an unexpected \"addon\" value, ignoring it.")
        return nil
    end

    if type(data.apiVersion) ~= "number" or not SUPPORTED_API_VERSIONS[data.apiVersion] then
        MaelstromMusic.Log.write("addon '" .. modId .. "' declares apiVersion " .. tostring(data.apiVersion) .. ", which this version of Maelstrom's Music does not support - ignoring it.")
        return nil
    end

    return { apiVersion = data.apiVersion }
end
