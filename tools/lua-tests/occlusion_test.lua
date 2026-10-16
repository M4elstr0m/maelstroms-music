-- Run from the repository root: lua5.1 tools/lua-tests/occlusion_test.lua
local root = "Contents/mods/maelstroms-music/42/media/lua/"
package.path = root .. "shared/?.lua;" .. root .. "client/?.lua;" .. package.path

local squares, rooms, buildings = {}, {}, {}

-- Creates a named building.
local function newBuilding(name) buildings[name] = { name = name }; return buildings[name] end
-- Creates a room of a building on a level.
local function newRoom(name, building, level)
    local room = { name = name }
    function room:getBuilding() return building end
    function room:getRoomDef() return { level = level } end
    rooms[name] = room
    return room
end
-- Creates and registers a grid square, with or without line of sight to the observer.
local function newSquare(x, y, z, room, couldSee)
    local square = { x = x, y = y, z = z }
    function square:getRoom() return room end
    function square:getZ() return z end
    function square:isCouldSee() return couldSee end
    squares[x .. "," .. y .. "," .. z] = square
    return square
end

getCell = function() return { getGridSquare = function(_, x, y, z) return squares[math.floor(x) .. "," .. math.floor(y) .. "," .. math.floor(z)] end } end
local metaRooms = {}
getWorld = function() return { getMetaGrid = function() return { getRoomAt = function(_, x, y, z) return metaRooms[x .. "," .. y .. "," .. z] end } end } end

require "Namespace"
require "Playback/Occlusion"
local Occlusion = MaelstromMusic.Playback.Occlusion

local failures = 0
-- Prints the result of one assertion and counts failures.
local function check(description, condition)
    print((condition and "pass  " or "FAIL  ") .. description)
    if not condition then failures = failures + 1 end
end
-- Whether two numbers are equal within rounding.
local function near(a, b) return math.abs(a - b) < 1e-6 end

local houseA, houseB = newBuilding("A"), newBuilding("B")
local kitchen, hall, other = newRoom("kitchen", houseA, 0), newRoom("hall", houseA, 0), newRoom("other", houseB, 0)
local upstairs = newRoom("upstairs", houseA, 1)

-- Creates the observer standing in a room.
local function observerIn(room, x, y, z)
    local square = newSquare(x, y, z, room, true)
    return { square = square, room = room, floor = z, index = 0 }
end

local indoors = observerIn(kitchen, 0, 0, 0)
newSquare(1, 0, 0, kitchen, true)
newSquare(2, 0, 0, hall, true)
newSquare(3, 0, 0, other, true)
newSquare(4, 0, 0, upstairs, true)
newSquare(5, 0, 0, nil, true)
newSquare(6, 0, 0, hall, false)
newSquare(7, 0, 1, nil, true)

check("the same room is not muffled", near(Occlusion.direct(indoors, 1, 0, 0), 0))
check("another room of the building is lightly muffled", near(Occlusion.direct(indoors, 2, 0, 0), 0.24))
check("another building is capped at the maximum", near(Occlusion.direct(indoors, 3, 0, 0), 0.9))
check("another floor of the building", near(Occlusion.direct(indoors, 4, 0, 0), 0.6))
check("an outdoor sound heard from inside", near(Occlusion.direct(indoors, 5, 0, 0), 0.79))
check("no line of sight adds to the muffling", near(Occlusion.direct(indoors, 6, 0, 0), 0.64))
check("another level is scaled", near(Occlusion.direct(indoors, 7, 0, 1), 0.79 * 1.3 > 0.9 and 0.9 or 0.79 * 1.3))

local outdoors = observerIn(nil, 10, 0, 0)
newSquare(11, 0, 0, nil, true)
newSquare(12, 0, 0, kitchen, true)
check("outdoors to outdoors is clear", near(Occlusion.direct(outdoors, 11, 0, 0), 0))
check("a room heard from outside", near(Occlusion.direct(outdoors, 12, 0, 0), 0.33))

check("an unloaded square outside a building", near(Occlusion.direct(outdoors, 50, 50, 0), 0.6))
metaRooms["50,50,0"] = {}
check("an unloaded square inside a building heard from outside", near(Occlusion.direct(outdoors, 50, 50, 0), 0.9))
check("an unloaded square heard from inside", near(Occlusion.direct(indoors, 60, 60, 0), 0.9))

print(failures == 0 and "all checks passed" or (failures .. " check(s) failed"))
os.exit(failures == 0 and 0 or 1)
