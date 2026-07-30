require "Namespace"
require "Log"
require "Fs"
require "Json"

MaelstromMusic.Scanner.Station = {}

local TRACK_EXTENSIONS = { mp3 = true, ogg = true, wav = true }

local KIND_ID_PREFIX = {
    radio = "radio_",
    television = "tv_",
    background = "bg_",
}

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

local function collectTrackFiles(baseDir, name)
    local trackFiles = {}
    for _, trackFile in ipairs(MaelstromMusic.Fs.listFiles(baseDir .. "/" .. name)) do
        local ext = getExtension(trackFile)
        if ext and TRACK_EXTENSIONS[ext] then
            if string.find(trackFile, ",", 1, true) then
                MaelstromMusic.Log.write("skipping '" .. trackFile .. "' - a comma in the filename breaks Project Zomboid's sound script parser. Rename the file to remove the comma.")
            else
                table.insert(trackFiles, trackFile)
            end
        end
    end
    table.sort(trackFiles)
    return trackFiles
end

function MaelstromMusic.Scanner.Station.tryLoad(baseDir, kind, fileName)
    local name = string.match(fileName, "^(.+)%.json$")
    if not name then
        return nil
    end

    local jsonText = MaelstromMusic.Fs.readFile(baseDir .. "/" .. fileName)
    if not jsonText then
        MaelstromMusic.Log.write("could not read " .. baseDir .. "/" .. fileName .. ", skipping.")
        return nil
    end

    local data = MaelstromMusic.Json.decode(jsonText)
    if not (data and type(data) == "table" and type(data.title) == "string" and data.title ~= "") then
        MaelstromMusic.Log.write(baseDir .. "/" .. fileName .. " is missing a valid \"title\" field, skipping.")
        return nil
    end

    if kind == "background" and type(data.drama) ~= "number" then
        MaelstromMusic.Log.write(baseDir .. "/" .. fileName .. " is missing a valid \"drama\" field (0-10), skipping.")
        return nil
    end

    local trackFiles = collectTrackFiles(baseDir, name)
    if #trackFiles == 0 then
        MaelstromMusic.Log.write("'" .. name .. "' has an info file but no playable tracks (mp3/ogg/wav) in " .. baseDir .. "/" .. name .. ", skipping.")
        return nil
    end

    return KIND_ID_PREFIX[kind] .. sanitizeIdentifier(name), {
        rawDir = baseDir,
        rawName = name,
        kind = kind,
        title = data.title,
        shuffle = data.shuffle == true,
        fade = data.fade == true,
        drama = data.drama,
        trackFiles = trackFiles,
    }
end
