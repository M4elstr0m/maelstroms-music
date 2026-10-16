require "Namespace"
require "Log"
require "Safe"
require "Sound"
require "Playback/Track"
require "Backgrounds/Mood"
require "Playback/Warmup"
require "VanillaMusic"
require "Options"

MaelstromMusic.Ambience.Director = {}

local CLAIM_KEY = "backgrounds"
local MOOD_CHECK_INTERVAL = 30
local FADE_IN_MS = 4000
local FADE_OUT_MS = 3000
local LOOKAHEAD = 2
local RESUME_ELIGIBLE_MS = 30000

local sound = nil
local currentId = nil
local currentTrackIndex = nil
local pendingId = nil
local fadingOut = false
local moodCounter = 0
local takenOver = false
local gapEndsAt = 0
local radioSuppressed = false
local playerDead = false
local nextPicks = {}
local interruptedTrack = {}
local trackStartedAt = 0

-- Whether at least one background mood is available.
local function hasBackgrounds()
    if not MaelstromMusic.Backgrounds then
        return false
    end
    for _ in pairs(MaelstromMusic.Backgrounds) do
        return true
    end
    return false
end

-- Whether the adaptive soundtrack is in use.
function MaelstromMusic.Ambience.Director.isActive()
    return hasBackgrounds()
end

-- Whether a radio or TV track is playing, which pauses the background soundtrack.
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

-- Picks the mood whose drama value is closest to the given one.
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

-- Ends the current track and schedules the next one after a random gap taken from the options.
local function startNewGap()
    currentId = nil
    currentTrackIndex = nil
    pendingId = nil
    fadingOut = false
    local minSeconds, maxSeconds = MaelstromMusic.Options.backgroundGapSeconds()
    gapEndsAt = getTimestampMs() + ZombRand(minSeconds * 1000, maxSeconds * 1000 + 1)
end

-- Keeps the next tracks of a mood queued and requests their pre-decoding.
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

-- Queues and pre-decodes the first tracks of every mood.
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

-- Plays the next track of a mood with a fade in, resuming an interrupted one when still eligible.
local function playTrack(backgroundId)
    local background = backgroundId and MaelstromMusic.Backgrounds[backgroundId]
    if not background then
        startNewGap()
        return
    end

    local trackName, trackIndex, resumed
    local resumeIndex = interruptedTrack[backgroundId]
    if resumeIndex and background.trackFiles[resumeIndex] then
        trackIndex = resumeIndex
        trackName = background.tracks[resumeIndex]
        resumed = true
    else
        ensurePicks(backgroundId, background)
        local picks = nextPicks[backgroundId]
        if #picks > 0 then
            local pick = table.remove(picks, 1)
            trackName, trackIndex = pick.name, pick.index
        else
            trackName, trackIndex = MaelstromMusic.Playback.Track.chooseNext(background, currentTrackIndex)
        end
    end
    if not trackName then
        startNewGap()
        return
    end
    interruptedTrack[backgroundId] = nil

    currentId = backgroundId
    currentTrackIndex = trackIndex

    ensurePicks(backgroundId, background)

    MaelstromMusic.Log.write("background '" .. background.title .. "' now playing: " .. tostring(background.trackFiles[trackIndex]) .. (resumed and " (resumed)" or ""))

    if not sound then
        sound = MaelstromMusic.Sound:new()
        sound:set3D(false)
    end
    sound:setVolume(MaelstromMusic.VanillaMusic.optionVolume())
    sound:setFadeLevel(0)
    sound:play(trackName)
    sound:fadeTo(1, FADE_IN_MS)
    trackStartedAt = getTimestampMs()
end

-- Fades the current track out, remembering it for a resume, then plays the next mood.
-- Starts the next mood directly when nothing is playing.
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
    if currentId and currentTrackIndex and getTimestampMs() - trackStartedAt < RESUME_ELIGIBLE_MS then
        interruptedTrack[currentId] = currentTrackIndex
    end
    pendingId = nextId
    fadingOut = true
    sound:fadeOutAndStop(FADE_OUT_MS)
end

-- Keeps the FMOD music state on InGame and stops vanilla music.
local function holdMusicState()
    MaelstromMusic.Safe.call("could not hold the background music state", function()
        getSoundManager():setMusicState("InGame")
        getSoundManager():StopMusic()
    end)
end

-- Stops the soundtrack and releases the claim on the vanilla music.
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

-- State machine: takeover, fades, pause for radios, mood changes, end of track and gaps.
function MaelstromMusic.Ambience.Director.onTick()
    if not MaelstromMusic.ScanComplete or playerDead then
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
    holdMusicState()

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
            -- Only rising drama cuts in immediately; calming down waits for the current track
            -- to end naturally, then whichever mood fits by then (possibly calmer still) plays.
            if desiredId ~= currentId and MaelstromMusic.Backgrounds[desiredId].drama > MaelstromMusic.Backgrounds[currentId].drama then
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

    if getTimestampMs() < gapEndsAt then
        return
    end

    playTrack(pickBackgroundId(MaelstromMusic.Ambience.Mood.current()))
end

-- Releases the soundtrack when the player dies so the game over music can play.
local function onPlayerDeath()
    playerDead = true
    if takenOver then
        release()
    end
end

-- Releases the soundtrack as soon as there is no player, which means back at the menu.
local function checkPlayerGone()
    if takenOver and not getPlayer() then
        release()
    end
end

Events.OnTick.Add(MaelstromMusic.Ambience.Director.onTick)
Events.OnRenderTick.Add(checkPlayerGone)
Events.OnPreMapLoad.Add(primeMoods)
Events.OnMainMenuEnter.Add(release)
Events.OnPlayerDeath.Add(onPlayerDeath)
Events.OnCreatePlayer.Add(function() playerDead = false end)
