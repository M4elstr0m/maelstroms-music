-- Run from the repository root: lua5.1 tools/lua-tests/playback_test.lua
local root = "Contents/mods/maelstroms-music/42/media/lua/"
package.path = root .. "shared/?.lua;" .. root .. "client/?.lua;" .. package.path

local clock = 0
local calls = { clips = 0, positions = {}, stopped = {} }
local volumes = {}

getTimestampMs = function() return clock end
ZombRand = function(low) return low end
instanceof = function(object, class) return class == "InventoryItem" and object.isItem == true end
Events = setmetatable({}, { __index = function() return { Add = function() end } end })
GameSounds = {
    isKnownSound = function() return true end,
    getSound = function() return { getRandomClip = function() return "clip" end } end,
}

local function newEmitter(name)
    local emitter = { name = name }
    function emitter:playClip() calls.clips = calls.clips + 1 return calls.clips end
    function emitter:setVolume(id, value) volumes[id] = value end
    function emitter:set3D(_, flag) calls.threeD = flag end
    function emitter:tick() end
    function emitter:setPos(x, y, z) calls.positions[#calls.positions + 1] = { x, y, z } end
    function emitter:isPlaying() return true end
    function emitter:stopSound(id) calls.stopped[#calls.stopped + 1] = id end
    return emitter
end

local freeEmitter, vehicleEmitter = newEmitter("free"), newEmitter("vehicle")
IsoWorld = { instance = { getFreeEmitter = function() return freeEmitter end } }

local vehicle = {
    getEmitter = function() return vehicleEmitter end,
    getX = function() return 106 end,
    getY = function() return 100 end,
    getZ = function() return 0 end,
}
local player = { inVehicle = false }
function player:getX() return 100 end
function player:getY() return 100 end
function player:getZ() return 0 end
function player:getVehicle() return self.inVehicle and vehicle or nil end
getPlayer = function() return player end

local function newDeviceData(kind)
    local data = {}
    data.getIsTurnedOn = function() return true end
    data.getChannel = function() return 95000 end
    data.getDeviceVolume = function() return 1.0 end
    data.isInventoryDevice = function() return kind == "held" end
    data.isVehicleDevice = function() return kind == "vehicle" end
    data.getParent = function() return kind == "vehicle" and { getVehicle = function() return vehicle end } or nil end
    return data
end

local function newDevice(kind, x, y, data)
    local device = { isItem = kind == "held", present = true, data = data or newDeviceData(kind) }
    device.getDeviceData = function() return device.data end
    device.getObjectIndex = function() return device.present and 0 or -1 end
    device.getContainer = function() return device.present and {} or nil end
    device.getWorldItem = function() return nil end
    device.isInPlayerInventory = function() return kind == "held" end
    device.getX = function() return x end
    device.getY = function() return y end
    device.getZ = function() return 0 end
    device.getSquare = function() return device.present and {} or nil end
    return device
end

require "Namespace"
MaelstromMusic.Broadcasts = {
    radio_x = { title = "X", frequency = 95000, shuffle = true, tracks = { "t1", "t2" }, trackFiles = { "a.mp3", "b.mp3" } },
}
require "Playback/Cache"
require "Playback/Device"
require "Playback/Tick"

local Device, Cache, Tick = MaelstromMusic.Playback.Device, MaelstromMusic.Playback.Cache, MaelstromMusic.Playback.Tick
local failures = 0

local function check(description, condition)
    print((condition and "pass  " or "FAIL  ") .. description)
    if not condition then failures = failures + 1 end
end

local function update() for _ = 1, 5 do Tick.onTick() end end
local function reset() Cache.entries = {}; calls = { clips = 0, positions = {}, stopped = {} }; volumes = {}; clock = 0; player.inVehicle = false end

reset()
local radio = newDevice("world", 106, 94)
Device.ensurePlaying(radio); update()
local entry = Cache.entries[1]
check("a world radio is a 3D sound", entry.sound.sound3D == true)
check("a world radio keeps its true position", calls.positions[#calls.positions][1] == 106 and calls.positions[#calls.positions][2] == 94)
check("a world radio uses the world volume modifier", entry.sound.volumeModifier == 0.4)

reset()
Device.ensurePlaying(newDevice("held", 100, 100)); update()
check("a held radio is flat stereo", Cache.entries[1].sound.sound3D == false)
check("a held radio uses the held volume modifier", Cache.entries[1].sound.volumeModifier == 0.6)

reset()
player.inVehicle = true
Device.ensurePlaying(newDevice("vehicle", 106, 100)); update()
local car = Cache.entries[1]
check("a car radio plays on the vehicle's emitter", car.sound.emitter == vehicleEmitter)
check("inside the car it is flat with the inside modifier", car.sound.sound3D == false and car.sound.volumeModifier == 0.8)
player.inVehicle = false; update()
check("getting out switches it to 3D with the outside modifier", car.sound.sound3D == true and car.sound.volumeModifier == 0.3)

reset()
local placed = newDevice("world", 100, 100)
Device.ensurePlaying(placed); update()
placed.present = false; update()
check("a picked up radio is muted at once", Cache.entries[1].orphanedAt ~= nil and volumes[1] == 0)
local held = newDevice("held", 100, 100, placed.data)
Device.ensurePlaying(held)
check("the held radio takes over the same sound", calls.clips == 1 and Cache.entries[1].deviceData == held.data and Cache.entries[1].orphanedAt == nil)

reset()
local tv = newDevice("world", 130, 130)
Device.ensurePlaying(tv); update()
tv.present = false; update()
check("a TV that stays removed is muted", volumes[1] == 0)
clock = 6000; update()
check("and is released after the grace period", #Cache.entries == 0 and calls.stopped[1] == 1)

reset()
local origin = newDevice("world", 100, 100)
Device.ensurePlaying(origin); update()
origin.present = false; update()
local before = calls.clips
Device.ensurePlaying(newDevice("world", 300, 300))
check("a radio far from a muted entry starts its own track", calls.clips == before + 1)

print(failures == 0 and "all checks passed" or (failures .. " check(s) failed"))
os.exit(failures == 0 and 0 or 1)
