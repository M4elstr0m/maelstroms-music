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

local vehicleEmitter = newEmitter("vehicle")
IsoWorld = { instance = { getFreeEmitter = function() return newEmitter("free") end } }

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
function player:getCurrentSquare() return nil end
function player:getPlayerNum() return 0 end
function player:getLookAngleRadians() return 0 end
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
local Occlusion = MaelstromMusic.Playback.Occlusion
local staged = false
MaelstromMusic.Options.stereoSafePositioning = function() return staged end
local failures = 0

local function check(description, condition)
    print((condition and "pass  " or "FAIL  ") .. description)
    if not condition then failures = failures + 1 end
end

local function update() for _ = 1, 5 do Tick.onTick() end end
local function settle() for _ = 1, 60 do clock = clock + 16; Tick.onRender() end end
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

staged = true
Occlusion.direct = function() return 0 end

reset()
local stageRadio = newDevice("world", 106, 100)
Device.ensurePlaying(stageRadio); update(); settle()
local pair = Cache.entries[1]
local Stage = MaelstromMusic.Playback.Stage
local screenX, screenY = Stage.forward("screen", player)
check("a staged radio plays two copies of the track", calls.clips == 2 and pair.companion ~= nil)
check("both copies are positional", pair.sound.sound3D == true and pair.companion.sound3D == true)
check("the copies are placed away from the real position", pair.sound.x ~= 106 and pair.companion.x ~= 106)
check("the first copy is on the listener's left and the second on the right",
    Stage.pan(pair.sound.x - 100, pair.sound.y - 100, screenX, screenY) < -0.5 and Stage.pan(pair.companion.x - 100, pair.companion.y - 100, screenX, screenY) > 0.5)
local expectedLeft, expectedRight = Stage.gains(Stage.pan(6, 0, screenX, screenY))
check("the volumes follow the pan law", math.abs(volumes[1] / volumes[2] - expectedLeft / expectedRight) < 1e-6 and volumes[1] > 0)

local Staging = MaelstromMusic.Playback.Staging
local before = { pair.sound.x, pair.sound.y }
local turned = { x = 100, y = 100, z = 0, forwardX = 0, forwardY = 1 }
Staging.step(pair, turned, clock + 16)
check("between searches the copies follow the look direction", pair.sound.x ~= before[1] or pair.sound.y ~= before[2])
check("and stay on their own side of the new direction",
    Stage.pan(pair.sound.x - 100, pair.sound.y - 100, 0, 1) < -0.5 and Stage.pan(pair.companion.x - 100, pair.companion.y - 100, 0, 1) > 0.5)

local state = pair.stage.sides[-1]
local settledRadius = state.shownRadius
state.radius = state.radius + 6
Staging.step(pair, turned, clock + 48)
check("a new square is reached by gliding, not jumping", state.shownRadius > settledRadius and state.shownRadius < state.radius)

local sideVolume = pair.companion.volume
Staging.step(pair, { x = 100, y = 100, z = 0, forwardX = 1, forwardY = 0 }, clock + 32)
check("a change of pan is ramped, not stepped", math.abs(pair.companion.volume - sideVolume) < sideVolume * 0.6)

reset()
Device.ensurePlaying(newDevice("held", 100, 100)); update()
local heldPair = Cache.entries[1]
check("a held staged radio plays flat on the first copy", heldPair.sound.sound3D == false and volumes[1] > 0)
check("and keeps the second copy silent", volumes[2] == 0 and heldPair.companion.sound3D == false)

reset()
local placedPair = newDevice("world", 100, 100)
Device.ensurePlaying(placedPair); update()
placedPair.present = false; update()
check("a picked up staged radio mutes both copies", volumes[1] == 0 and volumes[2] == 0)

reset()
local toggled = newDevice("world", 110, 100)
Device.ensurePlaying(toggled); update()
staged = false; update()
check("switching the option off drops the second copy", Cache.entries[1].companion == nil)
staged = true; update()
check("switching it on again restores the pair", Cache.entries[1].companion ~= nil)

reset()
player.inVehicle = false
Device.ensurePlaying(newDevice("vehicle", 106, 100)); update()
local stagedCar = Cache.entries[1]
check("a staged car radio does not borrow the vehicle emitter", stagedCar.sound.emitter ~= vehicleEmitter and stagedCar.companion.emitter ~= vehicleEmitter)

print(failures == 0 and "all checks passed" or (failures .. " check(s) failed"))
os.exit(failures == 0 and 0 or 1)
