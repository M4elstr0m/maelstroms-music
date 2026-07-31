require "Namespace"
require "Log"

MaelstromMusic.Playback.Warmup = {}

local MAX_WARMUP_TRACKS = 100
local INGAME_INTERVAL_MS = 500

local PHASE_MENU = 1
local PHASE_LOADING = 2
local PHASE_INGAME = 3

local queue = nil
local queueIndex = 1
local warmupLimit = 0
local phase = PHASE_MENU
local lastWarmupAt = 0

local function buildQueue()
    local trackNames = {}
    for _, station in pairs(MaelstromMusic.Broadcasts) do
        for _, trackName in ipairs(station.tracks) do
            table.insert(trackNames, trackName)
        end
    end
    for _, background in pairs(MaelstromMusic.Backgrounds or {}) do
        for _, trackName in ipairs(background.tracks) do
            table.insert(trackNames, trackName)
        end
    end
    return trackNames
end

local function tryWarmNext()
    local ok = pcall(function()
        local gameSound = GameSounds.getSound(queue[queueIndex])
        if not gameSound then
            return
        end
        local emitter = IsoWorld.instance:getFreeEmitter()
        local id = emitter:playClip(gameSound:getRandomClip(), nil)
        if id then
            emitter:setVolume(id, 0)
            emitter:stopSound(id)
        end
    end)
    if ok then
        queueIndex = queueIndex + 1
    end
    return ok
end

local onRenderTick

onRenderTick = function()
    if not MaelstromMusic.ScanComplete or phase == PHASE_MENU then
        return
    end

    if not queue then
        queue = buildQueue()
        warmupLimit = math.min(#queue, MAX_WARMUP_TRACKS)
        if warmupLimit == 0 then
            Events.OnRenderTick.Remove(onRenderTick)
            return
        end
        if #queue > MAX_WARMUP_TRACKS then
            MaelstromMusic.Log.write("warming up the first " .. MAX_WARMUP_TRACKS .. " of " .. #queue .. " track(s) - the rest will load on first play instead, to limit memory use...")
        else
            MaelstromMusic.Log.write("warming up " .. warmupLimit .. " track(s)...")
        end
    end

    if phase == PHASE_INGAME then
        local now = getTimestampMs()
        if now - lastWarmupAt < INGAME_INTERVAL_MS then
            return
        end
        lastWarmupAt = now
    end

    tryWarmNext()

    if queueIndex > warmupLimit then
        MaelstromMusic.Log.write("warmup complete.")
        Events.OnRenderTick.Remove(onRenderTick)
    end
end

Events.OnRenderTick.Add(onRenderTick)

Events.OnMainMenuEnter.Add(function()
    phase = PHASE_MENU
end)

Events.OnPreMapLoad.Add(function()
    phase = PHASE_LOADING
end)

Events.OnGameStart.Add(function()
    phase = PHASE_INGAME
end)
