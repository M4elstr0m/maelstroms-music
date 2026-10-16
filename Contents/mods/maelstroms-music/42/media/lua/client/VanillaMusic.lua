require "Namespace"
require "Log"
require "Safe"

MaelstromMusic.VanillaMusic = {}

local REAPPLY_INTERVAL_MS = 50

local claims = {}
local silenced = false
local lastAppliedAt = 0

-- The music volume option of the player as a value from 0 to 1.
function MaelstromMusic.VanillaMusic.optionVolume()
    local level = getCore():getOptionMusicVolume()
    if not level then
        return 1
    end
    return level / 10
end

-- Registers (wanted true) or releases a claim that keeps the vanilla soundtrack silent.
function MaelstromMusic.VanillaMusic.claim(key, wanted)
    claims[key] = wanted or nil
end

-- Whether at least one claim is active.
local function anyClaim()
    for _ in pairs(claims) do
        return true
    end
    return false
end

local lastLoggedLeak = nil
-- Logs once per track when vanilla music keeps playing although it should be silent.
local function checkLeak()
    local playing, name
    MaelstromMusic.Safe.call("could not check vanilla music state", function()
        playing = getSoundManager():isPlayingMusic()
        name = getSoundManager():getCurrentMusicName()
    end)
    if playing then
        if name ~= lastLoggedLeak then
            lastLoggedLeak = name
            MaelstromMusic.Log.write("[diag] vanilla music still playing while suppressed: '" .. tostring(name) .. "'")
        end
    else
        lastLoggedLeak = nil
    end
end

-- Drops every claim and restores the vanilla music volume.
function MaelstromMusic.VanillaMusic.restore()
    claims = {}
    silenced = false
    lastAppliedAt = 0
    MaelstromMusic.Safe.call("could not restore the vanilla soundtrack", function()
        getSoundManager():setMusicVolume(MaelstromMusic.VanillaMusic.optionVolume())
    end)
end

-- Silences vanilla music while any claim exists (reapplied every 50 ms), restores it when the last claim goes.
function MaelstromMusic.VanillaMusic.refresh()
    if anyClaim() then
        local now = getTimestampMs()
        if silenced and now - lastAppliedAt < REAPPLY_INTERVAL_MS then
            return
        end
        checkLeak()
        silenced = true
        lastAppliedAt = now
        MaelstromMusic.Safe.call("could not silence the vanilla soundtrack", function()
            getSoundManager():setMusicVolume(0)
        end)
    elseif silenced then
        silenced = false
        MaelstromMusic.Safe.call("could not restore the vanilla soundtrack", function()
            getSoundManager():setMusicVolume(MaelstromMusic.VanillaMusic.optionVolume())
        end)
    end
end
