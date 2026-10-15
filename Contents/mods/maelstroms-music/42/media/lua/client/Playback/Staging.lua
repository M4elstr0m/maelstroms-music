require "Namespace"
require "Playback/Occlusion"
require "Playback/Stage"

MaelstromMusic.Playback.Staging = {}

local LEFT_SIDE, RIGHT_SIDE = -1, 1
local UNPLACED_GAIN = math.sqrt(0.5)

function MaelstromMusic.Playback.Staging.listener(player, frame)
    local forwardX, forwardY = MaelstromMusic.Playback.Stage.forward(frame, player)
    return {
        x = player:getX(),
        y = player:getY(),
        z = player:getZ(),
        forwardX = forwardX,
        forwardY = forwardY,
        observer = MaelstromMusic.Playback.Occlusion.observer(player),
    }
end

local function placeVoice(entry, side, listener, target)
    local Stage = MaelstromMusic.Playback.Stage
    local placement = Stage.place(listener.observer, listener, listener.forwardX, listener.forwardY, side, target,
        entry.stageCandidates[side])
    if placement then
        entry.stageCandidates[side] = placement.candidate
    end
    return placement
end

local function silenceCompanion(entry, volume)
    entry.sound:setVolume(volume)
    entry.companion:setVolume(0)
end

function MaelstromMusic.Playback.Staging.apply(entry, positional, volume, listener)
    if not positional then
        silenceCompanion(entry, volume)
        return
    end

    local Stage = MaelstromMusic.Playback.Stage
    local offsetX, offsetY = entry.x - listener.x, entry.y - listener.y
    local distance = math.sqrt(offsetX ^ 2 + offsetY ^ 2)
    local heightOffset = entry.z - listener.z
    local leftGain, rightGain = Stage.gains(Stage.pan(offsetX, offsetY, listener.forwardX, listener.forwardY))

    entry.stageCandidates = entry.stageCandidates or {}
    local target = {
        distance = distance,
        z = entry.z,
        occlusion = MaelstromMusic.Playback.Occlusion.direct(listener.observer, entry.x, entry.y, entry.z),
    }
    local left = placeVoice(entry, LEFT_SIDE, listener, target)
    local right = placeVoice(entry, RIGHT_SIDE, listener, target)

    if not (left and right) then
        entry.sound:setPos(entry.x, entry.y, entry.z)
        entry.companion:setPos(entry.x, entry.y, entry.z)
        entry.sound:setVolume(volume * UNPLACED_GAIN)
        entry.companion:setVolume(volume * UNPLACED_GAIN)
        return
    end

    entry.sound:setPos(left.x, left.y, entry.z)
    entry.companion:setPos(right.x, right.y, entry.z)
    entry.sound:setVolume(volume * leftGain * Stage.gainCompensation(distance, left.radius, heightOffset))
    entry.companion:setVolume(volume * rightGain * Stage.gainCompensation(distance, right.radius, heightOffset))
end
