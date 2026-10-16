require "Namespace"
require "Log"
require "Fs"
require "Scanner/Station"
require "Scanner/Tracks"

MaelstromMusic.Scanner.Pools = {}

-- Gathers the main menu tracks of every source into one list.
local function collectMainMenuFiles(sources)
    local trackFiles = {}
    local contributingSources = 0
    for _, source in ipairs(sources) do
        local files = MaelstromMusic.Scanner.Tracks.list(source.modId, MaelstromMusic.MAINMENU_DIR)
        if #files > 0 then
            contributingSources = contributingSources + 1
            for _, fileName in ipairs(files) do
                table.insert(trackFiles, fileName)
            end
        end
    end
    if contributingSources > 1 then
        MaelstromMusic.Log.write("main menu theme: combining " .. #trackFiles .. " track(s) from " .. contributingSources .. " source(s), played in random order.")
    end
    return trackFiles
end

-- Gathers the game over tracks, and the folder of each, of every source.
local function collectDeathTracks(sources)
    local trackFiles, trackDirs = {}, {}
    for _, source in ipairs(sources) do
        for _, fileName in ipairs(MaelstromMusic.Fs.listFilesFrom(source.modId, MaelstromMusic.DEATHS_DIR)) do
            local _, station = MaelstromMusic.Scanner.Station.tryLoad(source.modId, MaelstromMusic.DEATHS_DIR, "death", fileName)
            if station then
                for index, trackFile in ipairs(station.trackFiles) do
                    table.insert(trackFiles, trackFile)
                    table.insert(trackDirs, station.trackDirs[index])
                end
            end
        end
    end
    return trackFiles, trackDirs
end

-- Builds the shuffled main menu theme from every source, or nil when there is no track.
function MaelstromMusic.Scanner.Pools.mainMenu(sources)
    local trackFiles = collectMainMenuFiles(sources)
    if #trackFiles == 0 then
        return nil
    end
    return {
        ownerModId = MaelstromMusic.MOD_ID,
        rawDir = MaelstromMusic.MAINMENU_DIR,
        rawName = "",
        kind = "mainmenu",
        title = "Main Menu Theme",
        shuffle = true,
        trackFiles = trackFiles,
    }
end

-- Builds the shuffled game over pool from every source, or nil when there is no track.
function MaelstromMusic.Scanner.Pools.death(sources)
    local trackFiles, trackDirs = collectDeathTracks(sources)
    if #trackFiles == 0 then
        return nil
    end
    return {
        ownerModId = MaelstromMusic.MOD_ID,
        rawDir = MaelstromMusic.DEATHS_DIR,
        rawName = "",
        kind = "death",
        title = "Game Over",
        shuffle = true,
        trackFiles = trackFiles,
        trackDirs = trackDirs,
    }
end
