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
local RADIUS_OFFSETS = { 0, 1, -1, 2, -2, 3, -3, 4, -4, 6, -6, 8, -8 }
local ANGLE_OFFSETS_DEGREES = { 0, 8, -8, 16, -16, 24, -24, 32, -32 }
local SWITCH_MARGIN = 0.05
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

-- Direction the listener faces: the look angle of the player or the fixed screen direction.
function MaelstromMusic.Playback.Stage.forward(frame, player)
    if frame == "look" then
        local angle = player:getLookAngleRadians()
        return math.cos(angle), math.sin(angle)
    end
    return SCREEN_FORWARD_X, SCREEN_FORWARD_Y
end

-- Lateral bearing of an offset relative to the facing direction, from -1 (left) to 1 (right).
function MaelstromMusic.Playback.Stage.pan(offsetX, offsetY, forwardX, forwardY)
    local distance = math.sqrt(offsetX ^ 2 + offsetY ^ 2)
    if distance < PAN_DEAD_ZONE then
        return 0
    end
    return (offsetY * forwardX - offsetX * forwardY) / distance
end

-- Equal power left and right gains for a pan value.
function MaelstromMusic.Playback.Stage.gains(pan)
    local angle = (pan + 1) * math.pi / 4
    return math.cos(angle), math.sin(angle)
end

-- Inverse distance roll-off of the engine, flat below the minimum distance.
local function rolloffGain(distance)
    return MIN_ROLLOFF_DISTANCE / math.max(distance, MIN_ROLLOFF_DISTANCE)
end

-- World position of a stage emitter for a side, angle offset and radius around the origin.
function MaelstromMusic.Playback.Stage.position(origin, forwardX, forwardY, side, angleOffset, radius)
    local azimuth = STAGE_ANGLE + angleOffset
    local along, across = math.cos(azimuth), math.sin(azimuth) * side
    local x = origin.x + radius * (forwardX * along - forwardY * across)
    local y = origin.y + radius * (forwardY * along + forwardX * across)
    return x, y
end

-- Places one candidate and measures how far its occlusion is from the target occlusion.
local function evaluate(observer, origin, forwardX, forwardY, side, target, candidate)
    local radius = math.max(MIN_STAGE_RADIUS, target.distance + candidate.radiusOffset)
    local x, y = MaelstromMusic.Playback.Stage.position(origin, forwardX, forwardY, side, candidate.angleOffset, radius)
    local occlusion = MaelstromMusic.Playback.Occlusion.direct(observer, x, y, target.z)
    return { x = x, y = y, radius = radius, candidate = candidate, deficit = target.occlusion - occlusion }
end

-- Whether a placement reproduces the target occlusion within the tolerance.
local function matches(placement)
    return math.abs(placement.deficit) <= MATCH_TOLERANCE
end

-- Finds the placement whose occlusion best matches the target, closest candidates first.
-- Keeps the previous candidate unless a new one is clearly better, to avoid hopping.
function MaelstromMusic.Playback.Stage.place(observer, origin, forwardX, forwardY, side, target, previous, searchAgain)
    local kept = nil
    if previous then
        kept = evaluate(observer, origin, forwardX, forwardY, side, target, previous)
        if matches(kept) or searchAgain == false then
            return kept
        end
    end

    local best = nil
    for _, candidate in ipairs(candidates) do
        local placement = evaluate(observer, origin, forwardX, forwardY, side, target, candidate)
        if not best or math.abs(placement.deficit) < math.abs(best.deficit) then
            best = placement
        end
        if matches(placement) then
            break
        end
    end

    if kept and math.abs(best.deficit) > math.abs(kept.deficit) - SWITCH_MARGIN then
        return kept
    end
    return best
end

-- Public form of matches.
function MaelstromMusic.Playback.Stage.isMatch(placement)
    return matches(placement)
end

-- Volume factor when no placement reached the target occlusion, up to 60 percent quieter.
function MaelstromMusic.Playback.Stage.mutedGain(deficit)
    if deficit <= MATCH_TOLERANCE then
        return 1
    end
    return 1 - UNDER_MUFFLED_VOLUME_LOSS * math.min(deficit, 1)
end

-- Corrects the roll-off difference between the stage radius and the real distance of the device.
function MaelstromMusic.Playback.Stage.gainCompensation(realDistance, virtualRadius, heightOffset)
    local floorGap = heightOffset * FLOOR_HEIGHT
    local real = math.sqrt(realDistance ^ 2 + floorGap ^ 2)
    local virtual = math.sqrt(virtualRadius ^ 2 + floorGap ^ 2)
    local ratio = rolloffGain(real) / rolloffGain(virtual)
    return math.min(MAX_GAIN_COMPENSATION, math.max(MIN_GAIN_COMPENSATION, ratio))
end
