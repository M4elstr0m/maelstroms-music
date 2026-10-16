require "Namespace"
require "Log"
require "Safe"
require "Sound"
require "Options"
require "VanillaMusic"
require "Playback/PickQueue"
require "Playback/Track"

MaelstromMusic.Ambience.Voice = {
    currentId = nil,
    trackIndex = nil,
    pendingId = nil,
    fadingOut = false,
    gapEndsAt = 0,
}

local Voice = MaelstromMusic.Ambience.Voice

local FADE_IN_MS = 4000
local FADE_OUT_MS = 3000
local RESUME_ELIGIBLE_MS = 30000

local sound = nil
local upcoming = MaelstromMusic.Playback.PickQueue.new()
local interruptedTrack = {}
local trackStartedAt = 0

-- Whether the current track is still playing.
function Voice.isPlaying()
    return sound ~= nil and sound:isPlaying()
end

-- Applies the music volume option to the current track.
function Voice.refreshVolume()
    sound:setVolume(MaelstromMusic.VanillaMusic.optionVolume())
end

-- Advances the fade of the current track, returns true while it is still running.
function Voice.updateFade()
    return sound:updateFade()
end

-- Ends the current track and schedules the next one after a random gap taken from the options.
function Voice.startGap()
    Voice.currentId = nil
    Voice.trackIndex = nil
    Voice.pendingId = nil
    Voice.fadingOut = false
    local minSeconds, maxSeconds = MaelstromMusic.Options.backgroundGapSeconds()
    Voice.gapEndsAt = getTimestampMs() + ZombRand(minSeconds * 1000, maxSeconds * 1000 + 1)
end

-- Queues and pre-decodes the first tracks of every mood.
function Voice.prime()
    local queued = upcoming:prime(MaelstromMusic.Backgrounds or {})
    if queued > 0 then
        MaelstromMusic.Log.write("pre-warming " .. queued .. " track(s) across background mood(s).")
    end
end

-- Chooses the track a mood plays next: the one interrupted earlier, else the queued one, else a fresh pick.
local function chooseTrack(backgroundId, background)
    local resumeIndex = interruptedTrack[backgroundId]
    if resumeIndex and background.trackFiles[resumeIndex] then
        return background.tracks[resumeIndex], resumeIndex, true
    end
    upcoming:fill(backgroundId, background, backgroundId == Voice.currentId and Voice.trackIndex or nil)
    local pick = upcoming:take(backgroundId)
    if pick then
        return pick.name, pick.index, false
    end
    local trackName, trackIndex = MaelstromMusic.Playback.Track.chooseNext(background, Voice.trackIndex)
    return trackName, trackIndex, false
end

-- Plays the next track of a mood with a fade in, or starts a gap when the mood has nothing to play.
function Voice.play(backgroundId)
    local background = backgroundId and MaelstromMusic.Backgrounds[backgroundId]
    if not background then
        Voice.startGap()
        return
    end

    local trackName, trackIndex, resumed = chooseTrack(backgroundId, background)
    if not trackName then
        Voice.startGap()
        return
    end
    interruptedTrack[backgroundId] = nil

    Voice.currentId = backgroundId
    Voice.trackIndex = trackIndex
    upcoming:fill(backgroundId, background, trackIndex)

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
function Voice.fadeOut(nextId)
    if not Voice.isPlaying() then
        if nextId then
            Voice.trackIndex = nil
            Voice.play(nextId)
        else
            Voice.startGap()
        end
        return
    end
    if Voice.currentId and Voice.trackIndex and getTimestampMs() - trackStartedAt < RESUME_ELIGIBLE_MS then
        interruptedTrack[Voice.currentId] = Voice.trackIndex
    end
    Voice.pendingId = nextId
    Voice.fadingOut = true
    sound:fadeOutAndStop(FADE_OUT_MS)
end

-- Continues a fade out: while it runs nothing else happens, when it ends the next mood plays or a gap starts.
function Voice.settleFadeOut()
    if sound:updateFade() then
        return
    end
    Voice.fadingOut = false
    local nextId = Voice.pendingId
    Voice.pendingId = nil
    Voice.trackIndex = nil
    if nextId then
        Voice.play(nextId)
    else
        Voice.startGap()
    end
end

-- Stops the track and schedules a fresh gap.
function Voice.release()
    if sound then
        MaelstromMusic.Safe.call("could not stop the background soundtrack", function()
            sound:stop()
        end)
        sound = nil
    end
    Voice.startGap()
end
