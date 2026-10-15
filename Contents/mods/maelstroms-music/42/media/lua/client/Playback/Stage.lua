require "Namespace"
require "Playback/Occlusion"

MaelstromMusic.Playback.Stage = {}

local STAGE_ANGLE = math.rad(40)
local MIN_STAGE_RADIUS = 2.2
local MIN_ROLLOFF_DISTANCE = 2
local FLOOR_HEIGHT = 3
local MATCH_TOLERANCE = 0.02
local UNDER_MUFFLED_VOLUME_LOSS = 0.6
local MIN_GAIN_COMPENSATION = 0.5
local MAX_GAIN_COMPENSATION = 1.2
local PAN_DEAD_ZONE = 0.5
local RADIUS_OFFSETS = { 0, 1, -1, 2, -2, 3, -3, 4, -4, 6, -6 }
local ANGLE_OFFSETS_DEGREES = { 0, 8, -8, 16, -16, 24, -24 }
local ANGLE_COST_PER_DEGREE = 1 / 8

local SCREEN_FORWARD_X = -math.sqrt(0.5)
local SCREEN_FORWARD_Y = -math.sqrt(0.5)

local candidates = {}

for _, radiusOffset in ipairs(RADIUS_OFFSETS) do
    for _, angleOffset in ipairs(ANGLE_OFFSETS_DEGREES) do
        table.insert(candidates, {
            radiusOffset = radiusOffset,
            angleOffset = math.rad(angleOffset),
            cost = math.abs(radiusOffset) + math.abs(angleOffset) * ANGLE_COST_PER_DEGREE,
        })
    end
end
table.sort(candidates, function(a, b) return a.cost < b.cost end)

function MaelstromMusic.Playback.Stage.forward(frame, player)
    if frame == "look" then
        local angle = player:getLookAngleRadians()
        return math.cos(angle), math.sin(angle)
    end
    return SCREEN_FORWARD_X, SCREEN_FORWARD_Y
end

function MaelstromMusic.Playback.Stage.pan(offsetX, offsetY, forwardX, forwardY)
    local distance = math.sqrt(offsetX ^ 2 + offsetY ^ 2)
    if distance < PAN_DEAD_ZONE then
        return 0
    end
    return (offsetY * forwardX - offsetX * forwardY) / distance
end

function MaelstromMusic.Playback.Stage.gains(pan)
    local angle = (pan + 1) * math.pi / 4
    return math.cos(angle), math.sin(angle)
end

local function rolloffGain(distance)
    return MIN_ROLLOFF_DISTANCE / math.max(distance, MIN_ROLLOFF_DISTANCE)
end

function MaelstromMusic.Playback.Stage.position(origin, forwardX, forwardY, side, candidate, radius)
    local azimuth = STAGE_ANGLE + candidate.angleOffset
    local along, across = math.cos(azimuth), math.sin(azimuth) * side
    local x = origin.x + radius * (forwardX * along - forwardY * across)
    local y = origin.y + radius * (forwardY * along + forwardX * across)
    return x, y
end

local function evaluate(observer, origin, forwardX, forwardY, side, target, candidate)
    local radius = math.max(MIN_STAGE_RADIUS, target.distance + candidate.radiusOffset)
    local x, y = MaelstromMusic.Playback.Stage.position(origin, forwardX, forwardY, side, candidate, radius)
    local occlusion = MaelstromMusic.Playback.Occlusion.direct(observer, x, y, target.z)
    return { x = x, y = y, radius = radius, candidate = candidate, deficit = target.occlusion - occlusion }
end

local function matches(placement)
    return math.abs(placement.deficit) <= MATCH_TOLERANCE
end

function MaelstromMusic.Playback.Stage.place(observer, origin, forwardX, forwardY, side, target, previous, searchAgain)
    local best = nil
    if previous then
        best = evaluate(observer, origin, forwardX, forwardY, side, target, previous)
        if matches(best) or searchAgain == false then
            return best
        end
    end

    for _, candidate in ipairs(candidates) do
        local placement = evaluate(observer, origin, forwardX, forwardY, side, target, candidate)
        if not best or math.abs(placement.deficit) < math.abs(best.deficit) then
            best = placement
        end
        if matches(placement) then
            break
        end
    end
    return best
end

function MaelstromMusic.Playback.Stage.isMatch(placement)
    return matches(placement)
end

function MaelstromMusic.Playback.Stage.mutedGain(deficit)
    if deficit <= MATCH_TOLERANCE then
        return 1
    end
    return 1 - UNDER_MUFFLED_VOLUME_LOSS * math.min(deficit, 1)
end

function MaelstromMusic.Playback.Stage.gainCompensation(realDistance, virtualRadius, heightOffset)
    local floorGap = heightOffset * FLOOR_HEIGHT
    local real = math.sqrt(realDistance ^ 2 + floorGap ^ 2)
    local virtual = math.sqrt(virtualRadius ^ 2 + floorGap ^ 2)
    local ratio = rolloffGain(real) / rolloffGain(virtual)
    return math.min(MAX_GAIN_COMPENSATION, math.max(MIN_GAIN_COMPENSATION, ratio))
end
