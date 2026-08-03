require "Namespace"
require "Log"

MaelstromMusic.Playback.Warmup = {}

local PHASE_MENU = 1
local PHASE_LOADING = 2
local PHASE_INGAME = 3

local warmed = {}
local queue = {}
local queuedNames = {}
local phase = PHASE_MENU

local function warmTrack(soundName)
    local gameSound = GameSounds.getSound(soundName)
    if not gameSound then
        return
    end
    local emitter = IsoWorld.instance:getFreeEmitter()
    local id = emitter:playClip(gameSound:getRandomClip(), nil)
    if id then
        emitter:setVolume(id, 0)
        emitter:stopSound(id)
    end
end

function MaelstromMusic.Playback.Warmup.isWarmed(soundName)
    return soundName ~= nil and warmed[soundName] == true
end

function MaelstromMusic.Playback.Warmup.request(soundName)
    if not soundName or warmed[soundName] or queuedNames[soundName] then
        return
    end
    queuedNames[soundName] = true
    table.insert(queue, soundName)
end

local function onRenderTick()
    if #queue == 0 or phase == PHASE_MENU then
        return
    end

    local soundName = table.remove(queue, 1)
    queuedNames[soundName] = nil
    if pcall(warmTrack, soundName) then
        warmed[soundName] = true
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
