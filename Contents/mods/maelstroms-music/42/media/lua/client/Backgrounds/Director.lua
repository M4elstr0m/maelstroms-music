require "Namespace"
require "Log"
require "Safe"
require "Sound"
require "Track"
require "Mood"
require "Warmup"
require "VanillaMusic"

MaelstromMusic.Ambience.Director = {}

local CLAIM_KEY = "backgrounds"
local MOOD_CHECK_INTERVAL = 30
local MIN_GAP_TICKS = 1800
local MAX_GAP_TICKS = 4800
local FADE_IN_MS = 4000
local FADE_OUT_MS = 3000
local LOOKAHEAD = 2

local sound = nil
local currentId = nil
local currentTrackIndex = nil
local pendingId = nil
local fadingOut = false
local moodCounter = 0
local takenOver = false
local gapTicksRemaining = 0
local radioSuppressed = false
local nextPicks = {}

local function hasBackgrounds()
    if not MaelstromMusic.Backgrounds then
        return false
    end
    for _ in pairs(MaelstromMusic.Backgrounds) do
        return true
    end
    return false
end

function MaelstromMusic.Ambience.Director.isActive()
    return hasBackgrounds()
end

local function hasAudibleRadio()
    if not MaelstromMusic.Playback or not MaelstromMusic.Playback.Cache then
        return false
    end
    for _, entry in ipairs(MaelstromMusic.Playback.Cache.entries) do
        if entry.sound and entry.sound:isPlaying() then
            return true
        end
    end
    return false
end

local function pickBackgroundId(drama)
    local bestId, bestDiff = nil, nil
    for id, background in pairs(MaelstromMusic.Backgrounds) do
        local diff = math.abs(drama - background.drama)
        if not bestDiff or diff < bestDiff then
            bestId, bestDiff = id, diff
        end
    end
    return bestId
end

local function startNewGap()
    currentId = nil
    currentTrackIndex = nil
    pendingId = nil
    fadingOut = false
    gapTicksRemaining = ZombRand(MIN_GAP_TICKS, MAX_GAP_TICKS + 1)
end

local function ensurePicks(backgroundId, background)
    local picks = nextPicks[backgroundId]
    if not picks then
        picks = {}
        nextPicks[backgroundId] = picks
    end
    local afterIndex = #picks > 0 and picks[#picks].index or (backgroundId == currentId and currentTrackIndex or nil)
    while #picks < LOOKAHEAD do
        local name, index = MaelstromMusic.Playback.Track.chooseNext(background, afterIndex)
        if not name then
            break
        end
        table.insert(picks, { name = name, index = index })
        MaelstromMusic.Playback.Warmup.request(name)
        afterIndex = index
    end
end

local function primeMoods()
    local count = 0
    for backgroundId, background in pairs(MaelstromMusic.Backgrounds or {}) do
        local before = #(nextPicks[backgroundId] or {})
        ensurePicks(backgroundId, background)
        count = count + (#(nextPicks[backgroundId] or {}) - before)
    end
    if count > 0 then
        MaelstromMusic.Log.write("pre-warming " .. count .. " track(s) across background mood(s).")
    end
end

local function playTrack(backgroundId)
    local background = backgroundId and MaelstromMusic.Backgrounds[backgroundId]
    if not background then
        startNewGap()
        return
    end

    ensurePicks(backgroundId, background)
    local picks = nextPicks[backgroundId]
    local trackName, trackIndex
    if #picks > 0 then
        local pick = table.remove(picks, 1)
        trackName, trackIndex = pick.name, pick.index
    else
        trackName, trackIndex = MaelstromMusic.Playback.Track.chooseNext(background, currentTrackIndex)
    end
    if not trackName then
        startNewGap()
        return
    end

    currentId = backgroundId
    currentTrackIndex = trackIndex

    ensurePicks(backgroundId, background)

    MaelstromMusic.Log.write("background '" .. background.title .. "' now playing: " .. tostring(background.trackFiles[trackIndex]))

    if not sound then
        sound = MaelstromMusic.Sound:new()
        sound:set3D(false)
    end
    sound:setVolume(MaelstromMusic.VanillaMusic.optionVolume())
    sound:setFadeLevel(0)
    sound:play(trackName)
    sound:fadeTo(1, FADE_IN_MS)
end

local function beginFadeOut(nextId)
    if not sound or not sound:isPlaying() then
        if nextId then
            currentTrackIndex = nil
            playTrack(nextId)
        else
            startNewGap()
        end
        return
    end
    pendingId = nextId
    fadingOut = true
    sound:fadeOutAndStop(FADE_OUT_MS)
end

local function release()
    if sound then
        MaelstromMusic.Safe.call("could not stop the background soundtrack", function()
            sound:stop()
        end)
        sound = nil
    end
    takenOver = false
    radioSuppressed = false
    startNewGap()
    MaelstromMusic.VanillaMusic.claim(CLAIM_KEY, false)
    MaelstromMusic.VanillaMusic.refresh()
end

function MaelstromMusic.Ambience.Director.onTick()
    if not MaelstromMusic.ScanComplete then
        return
    end

    if not hasBackgrounds() then
        if takenOver then
            release()
        end
        return
    end

    if not takenOver then
        takenOver = true
        MaelstromMusic.VanillaMusic.claim(CLAIM_KEY, true)
        primeMoods()
        startNewGap()
    end
    MaelstromMusic.VanillaMusic.refresh()

    if fadingOut then
        if sound:updateFade() then
            return
        end
        fadingOut = false
        local nextId = pendingId
        pendingId = nil
        currentTrackIndex = nil
        if nextId then
            playTrack(nextId)
        else
            startNewGap()
        end
        return
    end

    if hasAudibleRadio() then
        if not radioSuppressed then
            radioSuppressed = true
            beginFadeOut(nil)
        end
        return
    end
    radioSuppressed = false

    if currentId then
        sound:updateFade()

        moodCounter = moodCounter + 1
        if moodCounter >= MOOD_CHECK_INTERVAL then
            moodCounter = 0
            local desiredId = pickBackgroundId(MaelstromMusic.Ambience.Mood.current())
            if desiredId ~= currentId then
                beginFadeOut(desiredId)
                return
            end
        end

        if not sound:isPlaying() then
            startNewGap()
        else
            sound:setVolume(MaelstromMusic.VanillaMusic.optionVolume())
        end
        return
    end

    if gapTicksRemaining > 0 then
        gapTicksRemaining = gapTicksRemaining - 1
        return
    end

    playTrack(pickBackgroundId(MaelstromMusic.Ambience.Mood.current()))
end

local function checkPlayerGone()
    if takenOver and not getPlayer() then
        release()
    end
end

Events.OnTick.Add(MaelstromMusic.Ambience.Director.onTick)
Events.OnRenderTick.Add(checkPlayerGone)
Events.OnPreMapLoad.Add(primeMoods)
Events.OnMainMenuEnter.Add(release)
