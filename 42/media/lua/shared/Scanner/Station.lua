require "Namespace"
require "Log"
require "Fs"
require "Json"

MaelstromMusic.Scanner.Station = {}

local TRACK_EXTENSIONS = { mp3 = true, ogg = true, wav = true }

local function sanitizeIdentifier(str)
    local out = string.gsub(str, "[^%w]", "")
    if out == "" then
        out = "x"
    end
    return out
end

local function getExtension(fileName)
    local ext = string.match(fileName, "%.([%a%d]+)$")
    return ext and string.lower(ext) or nil
end

local function collectTrackFiles(stationName)
    local trackFiles = {}
    for _, trackFile in ipairs(MaelstromMusic.Fs.listFiles(MaelstromMusic.RADIOS_DIR .. "/" .. stationName)) do
        local ext = getExtension(trackFile)
        if ext and TRACK_EXTENSIONS[ext] then
            table.insert(trackFiles, trackFile)
        end
    end
    table.sort(trackFiles)
    return trackFiles
end

function MaelstromMusic.Scanner.Station.tryLoad(fileName)
    local stationName = string.match(fileName, "^(.+)%.json$")
    if not stationName then
        return nil
    end

    local jsonText = MaelstromMusic.Fs.readFile(MaelstromMusic.RADIOS_DIR .. "/" .. fileName)
    if not jsonText then
        MaelstromMusic.Log.write("could not read " .. MaelstromMusic.RADIOS_DIR .. "/" .. fileName .. ", skipping.")
        return nil
    end

    local data = MaelstromMusic.Json.decode(jsonText)
    if not (data and type(data) == "table" and type(data.title) == "string" and data.title ~= "") then
        MaelstromMusic.Log.write(MaelstromMusic.RADIOS_DIR .. "/" .. fileName .. " is missing a valid \"title\" field, skipping.")
        return nil
    end

    local trackFiles = collectTrackFiles(stationName)
    if #trackFiles == 0 then
        MaelstromMusic.Log.write("station '" .. stationName .. "' has an info file but no playable tracks (mp3/ogg/wav) in " .. MaelstromMusic.RADIOS_DIR .. "/" .. stationName .. ", skipping.")
        return nil
    end

    return sanitizeIdentifier(stationName), {
        rawName = stationName,
        title = data.title,
        shuffle = data.shuffle == true,
        trackFiles = trackFiles,
    }
end
