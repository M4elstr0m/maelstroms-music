require "Namespace"
require "Log"
require "Fs"
require "Json"
require "Scanner/Tracks"

MaelstromMusic.Scanner.Station = {}

local KIND_ID_PREFIX = {
    radio = "radio_",
    television = "tv_",
    background = "bg_",
    death = "death_",
}

-- Whether stations of this kind sit on the dial of a radio or television.
local function isTunable(kind)
    return kind == "radio" or kind == "television"
end

-- Strips a name down to alphanumerics so it can be part of a station id.
local function sanitizeIdentifier(str)
    local out = string.gsub(str, "[^%w]", "")
    if out == "" then
        out = "x"
    end
    return out
end

-- Converts a frequency in MHz to internal units on the dial step, or nil when invalid.
local function normalizeFrequency(value)
    if type(value) ~= "number" or value <= 0 then
        return nil
    end
    local step = MaelstromMusic.FREQ_STEP
    return math.floor((value * 1000) / step + 0.5) * step
end

-- Builds the id of a station: a kind prefix, then the name, prefixed by the mod for addon stations.
local function stationIdOf(kind, modId, name)
    if modId ~= MaelstromMusic.MOD_ID then
        return KIND_ID_PREFIX[kind] .. sanitizeIdentifier(modId) .. "_" .. sanitizeIdentifier(name)
    end
    return KIND_ID_PREFIX[kind] .. sanitizeIdentifier(name)
end

-- Reads the optional fixed "frequency" of a radio or television, logging and ignoring an invalid one.
local function readFixedFrequency(kind, data, origin)
    if not isTunable(kind) or data.frequency == nil then
        return nil
    end
    local fixedFrequency = normalizeFrequency(data.frequency)
    if not fixedFrequency then
        MaelstromMusic.Log.write(origin .. " has an invalid \"frequency\" field (must be a positive number), assigning one automatically instead.")
    end
    return fixedFrequency
end

-- Reads the "sequences" of a radio or television, dropping entries that are not two distinct filenames.
local function readSequences(kind, data, origin)
    if not isTunable(kind) or type(data.sequences) ~= "table" then
        return nil
    end
    local sequences = {}
    for _, entry in ipairs(data.sequences) do
        if type(entry) == "table" and type(entry.before) == "string" and type(entry.after) == "string" and entry.before ~= entry.after then
            table.insert(sequences, { before = entry.before, after = entry.after })
        else
            MaelstromMusic.Log.write(origin .. " has an invalid \"sequences\" entry (needs distinct string \"before\" and \"after\" filenames), skipping that entry.")
        end
    end
    return sequences
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

    local origin = baseDir .. "/" .. fileName .. " in mod '" .. modId .. "'"
    local data = MaelstromMusic.Json.decode(jsonText)
    if not (data and type(data) == "table" and type(data.title) == "string" and data.title ~= "") then
        MaelstromMusic.Log.write(origin .. " is missing a valid \"title\" field, skipping.")
        return nil
    end

    if kind == "background" and type(data.drama) ~= "number" then
        MaelstromMusic.Log.write(origin .. " is missing a valid \"drama\" field (0-10), skipping.")
        return nil
    end

    local trackFiles = MaelstromMusic.Scanner.Tracks.list(modId, baseDir .. "/" .. name)
    if #trackFiles == 0 then
        MaelstromMusic.Log.write("'" .. name .. "' in mod '" .. modId .. "' has an info file but no playable tracks (mp3/ogg/wav/flac) in " .. baseDir .. "/" .. name .. ", skipping.")
        return nil
    end

    local trackDirs = {}
    for _ in ipairs(trackFiles) do
        table.insert(trackDirs, name)
    end

    return stationIdOf(kind, modId, name), {
        ownerModId = modId,
        rawDir = baseDir,
        rawName = name,
        kind = kind,
        title = data.title,
        shuffle = data.shuffle == true,
        fade = data.fade == true,
        drama = data.drama,
        fixedFrequency = readFixedFrequency(kind, data, origin),
        autoPreset = data.autoPreset ~= false,
        mergeTracks = isTunable(kind) and data.mergeTracks == true,
        trackFiles = trackFiles,
        trackDirs = trackDirs,
        sequences = readSequences(kind, data, origin),
    }
end
