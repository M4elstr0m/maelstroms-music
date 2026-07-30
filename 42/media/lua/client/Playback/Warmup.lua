require "Namespace"
require "Log"
require "Safe"

MaelstromMusic.Playback.Warmup = {}

local queue = nil
local queueIndex = 1

local function buildQueue()
    local trackNames = {}
    for _, station in pairs(MaelstromMusic.Stations) do
        for _, trackName in ipairs(station.tracks) do
            table.insert(trackNames, trackName)
        end
    end
    return trackNames
end

local function warmUpTrack(trackName)
    local gameSound = GameSounds.getSound(trackName)
    if not gameSound then
        return
    end
    local clip = gameSound:getRandomClip()
    local emitter = IsoWorld.instance:getFreeEmitter()
    local id = emitter:playClip(clip, nil)
    if id then
        emitter:setVolume(id, 0)
        emitter:stopSound(id)
    end
end

local function onTick()
    if not MaelstromMusic.ScanComplete then
        return
    end

    if not queue then
        queue = buildQueue()
        if #queue == 0 then
            Events.OnTick.Remove(onTick)
            return
        end
        MaelstromMusic.Log.write("warming up " .. #queue .. " track(s)...")
    end

    MaelstromMusic.Safe.call("warmup failed", function()
        warmUpTrack(queue[queueIndex])
    end)
    queueIndex = queueIndex + 1

    if queueIndex > #queue then
        MaelstromMusic.Log.write("warmup complete.")
        Events.OnTick.Remove(onTick)
    end
end

Events.OnTick.Add(onTick)
