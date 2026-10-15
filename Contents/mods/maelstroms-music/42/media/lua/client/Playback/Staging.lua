require "Namespace"
require "Playback/Occlusion"
require "Playback/Stage"

MaelstromMusic.Playback.Staging = {}

local LEFT_SIDE, RIGHT_SIDE = -1, 1
local SEARCH_INTERVAL_MS = 400
local SMOOTHING_MS = 60
local VOLUME_EPSILON = 0.002
local FIRST_STEP_ALPHA = 1 - math.exp(-1)

function MaelstromMusic.Playback.Staging.pose(player, frame)
    local forwardX, forwardY = MaelstromMusic.Playback.Stage.forward(frame, player)
    return { x = player:getX(), y = player:getY(), z = player:getZ(), forwardX = forwardX, forwardY = forwardY }
end

function MaelstromMusic.Playback.Staging.listener(player, frame)
    local listener = MaelstromMusic.Playback.Staging.pose(player, frame)
    listener.observer = MaelstromMusic.Playback.Occlusion.observer(player)
    return listener
end

local function placeSide(state, listener, side, target, now)
    local Stage = MaelstromMusic.Playback.Stage
    local searchAgain = not state.unmatched or now - (state.searchedAt or 0) >= SEARCH_INTERVAL_MS
    local placement = Stage.place(listener.observer, listener, listener.forwardX, listener.forwardY, side, target,
        state.candidate, searchAgain)
    if searchAgain and not Stage.isMatch(placement) then
        state.searchedAt = now
    end
    state.candidate = placement.candidate
    state.radius = placement.radius
    state.unmatched = not Stage.isMatch(placement)
    state.gain = Stage.mutedGain(placement.deficit)
end

function MaelstromMusic.Playback.Staging.plan(entry, positional, volume, listener, now)
    local stage = entry.stage or { sides = { [LEFT_SIDE] = {}, [RIGHT_SIDE] = {} } }
    entry.stage = stage
    stage.positional = positional
    stage.volume = volume

    if not positional then
        stage.gains = nil
        entry.sound:setVolume(volume)
        entry.companion:setVolume(0)
        return
    end

    local distance = math.sqrt((entry.x - listener.x) ^ 2 + (entry.y - listener.y) ^ 2)
    local target = {
        distance = distance,
        z = entry.z,
        occlusion = MaelstromMusic.Playback.Occlusion.direct(listener.observer, entry.x, entry.y, entry.z),
    }
    stage.distance = distance
    stage.heightOffset = entry.z - listener.z
    placeSide(stage.sides[LEFT_SIDE], listener, LEFT_SIDE, target, now)
    placeSide(stage.sides[RIGHT_SIDE], listener, RIGHT_SIDE, target, now)
    MaelstromMusic.Playback.Staging.step(entry, listener, now)
end

local function follow(sound, current, target, alpha)
    local gain = current + (target - current) * alpha
    local settled = math.abs(target - gain) <= VOLUME_EPSILON
    if settled then
        gain = target
    end
    if gain ~= sound.volume and (settled or math.abs(gain - sound.volume) > VOLUME_EPSILON) then
        sound:setVolume(gain)
    end
    return gain
end

local function moveVoice(sound, pose, side, state, z)
    local x, y = MaelstromMusic.Playback.Stage.position(pose, pose.forwardX, pose.forwardY, side, state.candidate, state.radius)
    sound:moveTo(x, y, z)
end

function MaelstromMusic.Playback.Staging.step(entry, pose, now)
    local stage = entry.stage
    if not stage or not stage.positional or not entry.companion then
        return
    end

    local Stage = MaelstromMusic.Playback.Stage
    local left, right = stage.sides[LEFT_SIDE], stage.sides[RIGHT_SIDE]
    if not (left.candidate and right.candidate) then
        return
    end

    local leftGain, rightGain = Stage.gains(Stage.pan(entry.x - pose.x, entry.y - pose.y, pose.forwardX, pose.forwardY))
    local leftTarget = stage.volume * leftGain * left.gain * Stage.gainCompensation(stage.distance, left.radius, stage.heightOffset)
    local rightTarget = stage.volume * rightGain * right.gain * Stage.gainCompensation(stage.distance, right.radius, stage.heightOffset)

    moveVoice(entry.sound, pose, LEFT_SIDE, left, entry.z)
    moveVoice(entry.companion, pose, RIGHT_SIDE, right, entry.z)

    local elapsed = now - (stage.steppedAt or now)
    stage.steppedAt = now
    local gains = stage.gains or { left = entry.sound.volume, right = entry.companion.volume }
    local alpha = FIRST_STEP_ALPHA
    if stage.gains then
        alpha = elapsed > 0 and 1 - math.exp(-elapsed / SMOOTHING_MS) or 0
    end
    stage.gains = {
        left = follow(entry.sound, gains.left, leftTarget, alpha),
        right = follow(entry.companion, gains.right, rightTarget, alpha),
    }
end
