require "Namespace"

MaelstromMusic.Playback.Spatial = {}

-- The vanilla audio listener always faces screen up, so the bearing is taken relative to that fixed vector.
local FORWARD_X, FORWARD_Y = -0.70710678, -0.70710678
local RIGHT_X, RIGHT_Y = 0.70710678, -0.70710678
local MAX_LATERAL = 0.45
local FULL_PAN_DISTANCE = 6
local LISTENER_REPLACING_MODS = { Viewpoint = true }

local directional = nil

local function listenerIsVanilla()
    local ok, activated = pcall(getActivatedMods)
    if not ok or not activated then
        return true
    end
    for index = 0, activated:size() - 1 do
        if LISTENER_REPLACING_MODS[activated:get(index)] then
            return false
        end
    end
    return true
end

function MaelstromMusic.Playback.Spatial.isDirectional()
    if directional == nil then
        directional = listenerIsVanilla()
    end
    return directional
end

function MaelstromMusic.Playback.Spatial.centeredGain(distance)
    return 1 / math.max(1, distance)
end

function MaelstromMusic.Playback.Spatial.virtualPosition(listenerX, listenerY, sourceX, sourceY)
    local dx, dy = sourceX - listenerX, sourceY - listenerY
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 0.001 then
        return sourceX, sourceY
    end
    local lateral = (dx * RIGHT_X + dy * RIGHT_Y) / distance
    local softened = lateral * MAX_LATERAL * math.min(1, distance / FULL_PAN_DISTANCE)
    local ahead = math.sqrt(1 - softened * softened)
    return listenerX + distance * (ahead * FORWARD_X + softened * RIGHT_X),
        listenerY + distance * (ahead * FORWARD_Y + softened * RIGHT_Y)
end
