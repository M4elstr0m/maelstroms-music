require "Namespace"

MaelstromMusic.Fs = {}

function MaelstromMusic.Fs.readFileFrom(modId, relativePath)
    local ok, reader = pcall(getModFileReader, modId, relativePath, false)
    if not ok or not reader then
        return nil
    end
    local lines = {}
    local ok2 = pcall(function()
        local line = reader:readLine()
        while line ~= nil do
            table.insert(lines, line)
            line = reader:readLine()
        end
        reader:close()
    end)
    if not ok2 then
        pcall(function() reader:close() end)
        return nil
    end
    return table.concat(lines, "\n")
end

function MaelstromMusic.Fs.listFilesFrom(modId, relativePath)
    local ok, result = pcall(listFilesInModDirectory, modId, relativePath)
    if not ok or not result then
        return {}
    end
    local files = {}
    for i = 0, result:size() - 1 do
        table.insert(files, result:get(i))
    end
    return files
end

function MaelstromMusic.Fs.readFile(relativePath)
    return MaelstromMusic.Fs.readFileFrom(MaelstromMusic.MOD_ID, relativePath)
end

function MaelstromMusic.Fs.listFiles(relativePath)
    return MaelstromMusic.Fs.listFilesFrom(MaelstromMusic.MOD_ID, relativePath)
end

function MaelstromMusic.Fs.writeFile(relativePath, content)
    local ok, writer = pcall(getModFileWriter, MaelstromMusic.MOD_ID, relativePath, true, false)
    if not ok or not writer then
        return false
    end
    local ok2 = pcall(function()
        writer:write(content)
        writer:close()
    end)
    if not ok2 then
        pcall(function() writer:close() end)
        return false
    end
    return true
end
