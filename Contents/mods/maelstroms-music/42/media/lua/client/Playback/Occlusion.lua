require "Namespace"

MaelstromMusic.Playback.Occlusion = {}

local SOUND_INDOORS_LISTENER_OUTDOORS = 0.33
local OTHER_ROOM = 0.24
local OTHER_BUILDING = 1.0
local OTHER_FLOOR_INDOORS = 0.6
local SOUND_OUTDOORS_LISTENER_INDOORS = 0.79
local NO_LINE_OF_SIGHT = 0.4
local UNLOADED_SQUARE_ROOM = 1.0
local UNLOADED_SQUARE_LISTENER_INDOORS = 0.94
local UNLOADED_SQUARE_LISTENER_OUTDOORS = 0.6
local OTHER_FLOOR_FACTOR = 1.3
local MAX_OCCLUSION = 0.9

function MaelstromMusic.Playback.Occlusion.observer(player)
    local square = player:getCurrentSquare()
    return {
        square = square,
        room = square and square:getRoom() or nil,
        floor = math.floor(player:getZ()),
        index = player:getPlayerNum(),
    }
end

local function indoorSound(observer, room)
    local listenerRoom = observer.room
    if not listenerRoom then
        return SOUND_INDOORS_LISTENER_OUTDOORS
    end
    local occlusion = 0
    if listenerRoom ~= room then
        occlusion = OTHER_ROOM
    end
    if room:getBuilding() ~= listenerRoom:getBuilding() then
        occlusion = OTHER_BUILDING
    end
    if room:getRoomDef().level ~= observer.floor then
        occlusion = OTHER_FLOOR_INDOORS
    end
    return occlusion
end

local function outdoorSound(observer)
    if observer.room then
        return SOUND_OUTDOORS_LISTENER_INDOORS
    end
    return 0
end

local function unloadedSquare(observer, x, y, z)
    local occlusion = 0
    if getWorld():getMetaGrid():getRoomAt(math.floor(x), math.floor(y), math.floor(z)) then
        occlusion = UNLOADED_SQUARE_ROOM
    end
    if observer.room then
        return math.min(occlusion + UNLOADED_SQUARE_LISTENER_INDOORS, MAX_OCCLUSION)
    end
    return math.min(occlusion + UNLOADED_SQUARE_LISTENER_OUTDOORS, MAX_OCCLUSION)
end

function MaelstromMusic.Playback.Occlusion.direct(observer, x, y, z)
    local square = getCell():getGridSquare(x, y, z)
    if not square then
        return unloadedSquare(observer, x, y, z)
    end

    local room = square:getRoom()
    local occlusion = room and indoorSound(observer, room) or outdoorSound(observer)
    if square ~= observer.square and not square:isCouldSee(observer.index) then
        occlusion = occlusion + NO_LINE_OF_SIGHT
    end
    if square:getZ() ~= observer.floor then
        occlusion = occlusion * OTHER_FLOOR_FACTOR
    end
    return math.min(occlusion, MAX_OCCLUSION)
end
