-- In memory mods and engine functions for the scanner test: a base mod, a merging addon, and three addons that must be ignored.
local World = { written = {}, reloads = 0 }

local MARKER = '{"addon": "maelstroms-music-addon", "apiVersion": 1}'
local files = {
    maelstromsmusic = {
        ["media/radios"] = { "example.json", "night.json", "bad.json", "empty.json", "broken.json", "example" },
        ["media/radios/example"] = { "one.mp3", "two.ogg", "notes.txt", "co,mma.mp3" },
        ["media/radios/night"] = { "a.mp3", "b.mp3", "x.mp3" },
        ["media/televisions"] = { "tvnews.json" },
        ["media/televisions/tvnews"] = { "n1.mp3" },
        ["media/backgrounds"] = { "calm.json", "tense.json", "nodrama.json" },
        ["media/backgrounds/calm"] = { "c1.mp3", "c2.mp3" },
        ["media/backgrounds/tense"] = { "t1.mp3" },
        ["media/backgrounds/nodrama"] = { "n.mp3" },
        ["media/mainmenu"] = { "theme1.mp3", "theme2.flac", "readme.txt" },
        ["media/deaths"] = { "dead.json" },
        ["media/deaths/dead"] = { "d1.mp3", "d2.ogg" },
    },
    fallout = {
        ["maelstroms-music-addon.json"] = MARKER,
        ["media/radios"] = { "nightfo.json", "galaxy.json" },
        ["media/radios/nightfo"] = { "z.mp3" },
        ["media/radios/galaxy"] = { "g1.mp3" },
        ["media/backgrounds"] = { "ignored.json" },
        ["media/backgrounds/ignored"] = { "i.mp3" },
        ["media/mainmenu"] = { "fallout.mp3" },
    },
    noreq = { ["maelstroms-music-addon.json"] = MARKER, ["media/radios"] = { "x.json" }, ["media/radios/x"] = { "x.mp3" } },
    future = { ["maelstroms-music-addon.json"] = '{"addon": "maelstroms-music-addon", "apiVersion": 2}' },
    garbled = { ["maelstroms-music-addon.json"] = "not json" },
}

local contents = {
    ["maelstromsmusic/media/radios/example.json"] = '{"title": "Example Radio", "shuffle": true, "fade": true}',
    ["maelstromsmusic/media/radios/night.json"] = [[{"title": "Night FM", "frequency": 95.4, "mergeTracks": true, "sequences": [
        {"before": "a.mp3", "after": "b.mp3"}, {"before": "x.mp3", "after": "a.mp3"}, {"before": "a.mp3", "after": "a.mp3"}, {"before": "ghost.mp3", "after": "a.mp3"}, 5]}]],
    ["maelstromsmusic/media/radios/bad.json"] = '{"shuffle": true}',
    ["maelstromsmusic/media/radios/empty.json"] = '{"title": "Nothing Here"}',
    ["maelstromsmusic/media/radios/broken.json"] = '{"title": ',
    ["maelstromsmusic/media/televisions/tvnews.json"] = '{"title": "News TV", "autoPreset": false}',
    ["maelstromsmusic/media/backgrounds/calm.json"] = '{"title": "Calm", "drama": 1, "shuffle": true}',
    ["maelstromsmusic/media/backgrounds/tense.json"] = '{"title": "Tense", "drama": 6}',
    ["maelstromsmusic/media/backgrounds/nodrama.json"] = '{"title": "No Drama"}',
    ["maelstromsmusic/media/deaths/dead.json"] = '{"title": "Dead"}',
    ["fallout/media/radios/nightfo.json"] = '{"title": "night fm", "mergeTracks": true, "sequences": [{"before": "z.mp3", "after": "a.mp3"}]}',
    ["fallout/media/radios/galaxy.json"] = '{"title": "Galaxy News", "frequency": 95.4}',
    ["fallout/media/backgrounds/ignored.json"] = '{"title": "Ignored", "drama": 3}',
}

local requirements = { maelstromsmusic = {}, fallout = { "maelstromsmusic" }, noreq = {}, future = { "maelstromsmusic" }, garbled = { "maelstromsmusic" } }
local names = { fallout = "Fallout Radio" }
local activated = { "maelstromsmusic", "fallout", "noreq", "future", "garbled" }

local function javaList(items)
    return { size = function() return #items end, get = function(_, index) return items[index + 1] end }
end

local function virtualPath(modId, path) return modId .. "/" .. path end

getModFileReader = function(modId, path)
    local text = World.written[virtualPath(modId, path)] or contents[virtualPath(modId, path)] or (files[modId] and files[modId][path])
    if type(text) ~= "string" then return nil end
    local lines, cursor = {}, 0
    for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    return { readLine = function() cursor = cursor + 1 return lines[cursor] end, close = function() end }
end

listFilesInModDirectory = function(modId, path)
    local listing = files[modId] and files[modId][path]
    if type(listing) ~= "table" then return nil end
    return javaList(listing)
end

getModFileWriter = function(modId, path)
    local buffer = {}
    return { write = function(_, text) buffer[#buffer + 1] = text end,
             close = function() World.written[virtualPath(modId, path)] = table.concat(buffer) end }
end

getActivatedMods = function() return javaList(activated) end
getModInfoByID = function(modId)
    if not requirements[modId] then return nil end
    return { getRequire = function() return javaList(requirements[modId]) end, getName = function() return names[modId] or modId end }
end
reloadSoundFiles = function() World.reloads = World.reloads + 1 end

return World
