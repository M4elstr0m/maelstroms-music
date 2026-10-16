require "Namespace"
require "Log"
require "Safe"
require "VanillaMusic"
require "Backgrounds/Mood"
require "Backgrounds/Voice"

MaelstromMusic.Ambience.Director = {}

local CLAIM_KEY = "backgrounds"
local MOOD_CHECK_INTERVAL = 30

local Mood = MaelstromMusic.Ambience.Mood
local Voice = MaelstromMusic.Ambience.Voice

local moodCounter = 0
local takenOver = false
local radioSuppressed = false
local playerDead = false

-- Whether the adaptive soundtrack is in use.
function MaelstromMusic.Ambience.Director.isActive()
    return Mood.available()
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

-- Keeps the FMOD music state on InGame and stops vanilla music.
local function holdMusicState()
    MaelstromMusic.Safe.call("could not hold the background music state", function()
        getSoundManager():setMusicState("InGame")
        getSoundManager():StopMusic()
    end)
end

-- Stops the soundtrack and releases the claim on the vanilla music.
local function release()
    Voice.release()
    takenOver = false
    radioSuppressed = false
    MaelstromMusic.VanillaMusic.claim(CLAIM_KEY, false)
    MaelstromMusic.VanillaMusic.refresh()
end

-- Takes the vanilla soundtrack over the first time backgrounds are available.
local function takeOver()
    takenOver = true
    MaelstromMusic.VanillaMusic.claim(CLAIM_KEY, true)
    Voice.prime()
    Voice.startGap()
end

-- Re-evaluates the mood every few ticks, only rising drama cuts in immediately.
-- Calming down waits for the current track to end, then whichever mood fits by then plays.
local function followMood()
    moodCounter = moodCounter + 1
    if moodCounter < MOOD_CHECK_INTERVAL then
        return false
    end
    moodCounter = 0
    local desiredId = Mood.closest(Mood.current())
    if desiredId ~= Voice.currentId and MaelstromMusic.Backgrounds[desiredId].drama > MaelstromMusic.Backgrounds[Voice.currentId].drama then
        Voice.fadeOut(desiredId)
        return true
    end
    return false
end

-- State machine: takeover, fades, pause for radios, mood changes, end of track and gaps.
function MaelstromMusic.Ambience.Director.onTick()
    if not MaelstromMusic.ScanComplete or playerDead then
        return
    end

    if not Mood.available() then
        if takenOver then
            release()
        end
        return
    end

    if not takenOver then
        takeOver()
    end
    MaelstromMusic.VanillaMusic.refresh()
    holdMusicState()

    if Voice.fadingOut then
        Voice.settleFadeOut()
        return
    end

    if hasAudibleRadio() then
        if not radioSuppressed then
            radioSuppressed = true
            Voice.fadeOut(nil)
        end
        return
    end
    radioSuppressed = false

    if Voice.currentId then
        Voice.updateFade()
        if followMood() then
            return
        end
        if not Voice.isPlaying() then
            Voice.startGap()
        else
            Voice.refreshVolume()
        end
        return
    end

    if getTimestampMs() < Voice.gapEndsAt then
        return
    end

    Voice.play(Mood.closest(Mood.current()))
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
Events.OnPreMapLoad.Add(Voice.prime)
Events.OnMainMenuEnter.Add(release)
Events.OnPlayerDeath.Add(onPlayerDeath)
Events.OnCreatePlayer.Add(function() playerDead = false end)
