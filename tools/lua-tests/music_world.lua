-- Fake engine for the music tests: a clock, a sound manager, recording emitters and a player with a zombie count.
local World = { clock = 0, log = {}, zombies = 0, player = nil, musicVolumeOption = 5 }

function World.record(line) World.log[#World.log + 1] = line end
function World.take() local lines = table.concat(World.log, "\n") World.log = {} return lines end
function World.advance(ms) World.clock = World.clock + ms end

local function newEmitter(name)
    local emitter = { name = name, playing = true, nextId = 0 }
    function emitter:playClip(clip) self.nextId = self.nextId + 1 World.record(name .. " play " .. tostring(clip) .. " #" .. self.nextId) return self.nextId end
    function emitter:setVolume(id, value) World.record(string.format("%s volume #%d %.3f", name, id, value)) end
    function emitter:set3D(id, flag) World.record(name .. " 3d #" .. id .. " " .. tostring(flag)) end
    function emitter:setPos(x, y, z) World.record(string.format("%s pos %s %s %s", name, x, y, z)) end
    function emitter:tick() end
    function emitter:isPlaying() return self.playing end
    function emitter:stopSound(id) World.record(name .. " stop #" .. id) end
    function emitter:stopAll() World.record(name .. " stopAll") end
    return emitter
end

World.worldEmitter = newEmitter("world")
World.uiEmitter = newEmitter("ui")

local currentSound = nil
GameSounds = {
    isKnownSound = function() return true end,
    getSound = function(name) currentSound = name return { getRandomClip = function() return name end } end,
}
IsoWorld = { instance = { getFreeEmitter = function() return World.worldEmitter end } }

getTimestampMs = function() return World.clock end
ZombRand = function(low) return low end

local manager = {}
function manager:setMusicVolume(value) World.record(string.format("vanilla volume %.2f", value)) end
function manager:setMusicState(state) World.record("vanilla state " .. state) end
function manager:StopMusic() World.record("vanilla stop") end
function manager:isPlayingMusic() return false end
function manager:getCurrentMusicName() return nil end
function manager:getUIEmitter() return World.uiEmitter end
getSoundManager = function() return manager end
getCore = function() return { getOptionMusicVolume = function() return World.musicVolumeOption end } end

local player = {}
function player:getStats()
    return { getNumVisibleZombies = function() return World.zombies end, getNumChasingZombies = function() return 0 end }
end
World.player = player
getPlayer = function() return World.player end

return World
