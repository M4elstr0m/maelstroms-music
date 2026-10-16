require "Namespace"
require "Log"
require "Fs"
require "Json"

MaelstromMusic.Scanner.Station = {}

local KIND_ID_PREFIX = {
    radio = "radio_",
    television = "tv_",
    background = "bg_",
    death = "death_",
}

-- Strips a name down to alphanumerics so it can be part of a station id.
local function sanitizeIdentifier(str)
    local out = string.gsub(str, "[^%w]", "")
    if out == "" then
        out = "x"
    end
    return out
end

-- Returns the lowercase extension of a file name, or nil.
local function getExtension(fileName)
    local ext = string.match(fileName, "%.([%a%d]+)$")
    return ext and string.lower(ext) or nil
end

-- Converts a frequency in MHz to internal units on the dial step, or nil when invalid.
local function normalizeFrequency(value)
    if type(value) ~= "number" or value <= 0 then
        return nil
    end
    local step = MaelstromMusic.FREQ_STEP
    return math.floor((value * 1000) / step + 0.5) * step
end

-- Lists the playable audio files of a station folder, sorted, skipping names with a comma.
local function collectTrackFiles(modId, baseDir, name)
    local trackFiles = {}
    for _, trackFile in ipairs(MaelstromMusic.Fs.listFilesFrom(modId, baseDir .. "/" .. name)) do
        local ext = getExtension(trackFile)
        if ext and MaelstromMusic.AUDIOFILE_EXTENSIONS[ext] then
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

-- Validates one station JSON file, returns its station id and table, or nil after logging the reason.
function MaelstromMusic.Scanner.Station.tryLoad(modId, baseDir, kind, fileName)
    local name = string.match(fileName, "^(.+)%.json$")
    if not name then
        return nil
    end

    local jsonText = MaelstromMusic.Fs.readFileFrom(modId, baseDir .. "/" .. fileName)
    if not jsonText then
        MaelstromMusic.Log.write("could not read " .. baseDir .. "/" .. fileName .. " from mod '" .. modId .. "', skipping.")
        return nil
    end

    local data = MaelstromMusic.Json.decode(jsonText)
    if not (data and type(data) == "table" and type(data.title) == "string" and data.title ~= "") then
        MaelstromMusic.Log.write(baseDir .. "/" .. fileName .. " in mod '" .. modId .. "' is missing a valid \"title\" field, skipping.")
        return nil
    end

    if kind == "background" and type(data.drama) ~= "number" then
        MaelstromMusic.Log.write(baseDir .. "/" .. fileName .. " in mod '" .. modId .. "' is missing a valid \"drama\" field (0-10), skipping.")
        return nil
    end

    local trackFiles = collectTrackFiles(modId, baseDir, name)
    if #trackFiles == 0 then
        MaelstromMusic.Log.write("'" .. name .. "' in mod '" .. modId .. "' has an info file but no playable tracks (mp3/ogg/wav/flac) in " .. baseDir .. "/" .. name .. ", skipping.")
        return nil
    end

    local trackDirs = {}
    for _ in ipairs(trackFiles) do
        table.insert(trackDirs, name)
    end

    local stationId = KIND_ID_PREFIX[kind] .. sanitizeIdentifier(name)
    if modId ~= MaelstromMusic.MOD_ID then
        stationId = KIND_ID_PREFIX[kind] .. sanitizeIdentifier(modId) .. "_" .. sanitizeIdentifier(name)
    end

    local fixedFrequency = nil
    if (kind == "radio" or kind == "television") and data.frequency ~= nil then
        fixedFrequency = normalizeFrequency(data.frequency)
        if not fixedFrequency then
            MaelstromMusic.Log.write(baseDir .. "/" .. fileName .. " in mod '" .. modId .. "' has an invalid \"frequency\" field (must be a positive number), assigning one automatically instead.")
        end
    end

    local sequences = nil
    if kind == "radio" or kind == "television" then
        if type(data.sequences) == "table" then
            sequences = {}
            for _, entry in ipairs(data.sequences) do
                if type(entry) == "table" and type(entry.before) == "string" and type(entry.after) == "string" and entry.before ~= entry.after then
                    table.insert(sequences, { before = entry.before, after = entry.after })
                else
                    MaelstromMusic.Log.write(baseDir .. "/" .. fileName .. " in mod '" .. modId .. "' has an invalid \"sequences\" entry (needs distinct string \"before\" and \"after\" filenames), skipping that entry.")
                end
            end
        end
    end

    return stationId, {
        ownerModId = modId,
        rawDir = baseDir,
        rawName = name,
        kind = kind,
        title = data.title,
        shuffle = data.shuffle == true,
        fade = data.fade == true,
        drama = data.drama,
        fixedFrequency = fixedFrequency,
        autoPreset = data.autoPreset ~= false,
        mergeTracks = (kind == "radio" or kind == "television") and data.mergeTracks == true,
        trackFiles = trackFiles,
        trackDirs = trackDirs,
        sequences = sequences,
    }
end
