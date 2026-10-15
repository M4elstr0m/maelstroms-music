require "Namespace"
require "Playback/Occlusion"

MaelstromMusic.Playback.Stage = {}

local STAGE_ANGLE = math.rad(40)
local MIN_STAGE_RADIUS = 2.2
local MIN_ROLLOFF_DISTANCE = 2
local FLOOR_HEIGHT = 3
local MATCH_TOLERANCE = 0.02
local ACCEPTABLE_MISMATCH = 0.25
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
    if frame == "player" then
        local direction = player:getForwardDirection()
        local length = math.sqrt(direction:getX() ^ 2 + direction:getY() ^ 2)
        if length > 0 then
            return direction:getX() / length, direction:getY() / length
        end
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

local function candidatePosition(origin, forwardX, forwardY, side, candidate, radius)
    local azimuth = STAGE_ANGLE + candidate.angleOffset
    local along, across = math.cos(azimuth), math.sin(azimuth) * side
    local x = origin.x + radius * (forwardX * along - forwardY * across)
    local y = origin.y + radius * (forwardY * along + forwardX * across)
    return x, y
end

function MaelstromMusic.Playback.Stage.place(observer, origin, forwardX, forwardY, side, target, previous)
    local best = nil
    local ordered = previous and { previous } or {}
    for _, candidate in ipairs(candidates) do
        table.insert(ordered, candidate)
    end

    for _, candidate in ipairs(ordered) do
        local radius = math.max(MIN_STAGE_RADIUS, target.distance + candidate.radiusOffset)
        local x, y = candidatePosition(origin, forwardX, forwardY, side, candidate, radius)
        local mismatch = math.abs(MaelstromMusic.Playback.Occlusion.direct(observer, x, y, target.z) - target.occlusion)
        if not best or mismatch < best.mismatch then
            best = { x = x, y = y, radius = radius, mismatch = mismatch, candidate = candidate }
        end
        if mismatch <= MATCH_TOLERANCE then
            break
        end
    end

    if best.mismatch > ACCEPTABLE_MISMATCH then
        return nil
    end
    return best
end

function MaelstromMusic.Playback.Stage.gainCompensation(realDistance, virtualRadius, heightOffset)
    local floorGap = heightOffset * FLOOR_HEIGHT
    local real = math.sqrt(realDistance ^ 2 + floorGap ^ 2)
    local virtual = math.sqrt(virtualRadius ^ 2 + floorGap ^ 2)
    local ratio = rolloffGain(real) / rolloffGain(virtual)
    return math.min(MAX_GAIN_COMPENSATION, math.max(MIN_GAIN_COMPENSATION, ratio))
end
