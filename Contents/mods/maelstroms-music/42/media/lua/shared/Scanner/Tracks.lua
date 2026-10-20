require "Namespace"
require "Log"
require "Fs"

MaelstromMusic.Scanner.Tracks = {}

-- Returns the lowercase extension of a file name, or nil.
local function extensionOf(fileName)
    local ext = string.match(fileName, "%.([%a%d]+)$")
    return ext and string.lower(ext) or nil
end

-- Lists the playable audio files of a directory of a mod, sorted, skipping names with a comma.
-- A comma breaks the sound script parser of the game and drops the sound silently.
function MaelstromMusic.Scanner.Tracks.list(modId, directory)
    local files = {}
    for _, fileName in ipairs(MaelstromMusic.Fs.listFilesFrom(modId, directory)) do
        local ext = extensionOf(fileName)
        if ext and MaelstromMusic.AUDIOFILE_EXTENSIONS[ext] then
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
