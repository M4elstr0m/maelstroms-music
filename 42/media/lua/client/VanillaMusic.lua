require "Namespace"
require "Log"
require "Safe"

MaelstromMusic.VanillaMusic = {}

local REAPPLY_INTERVAL_MS = 50

local claims = {}
local silenced = false
local lastAppliedAt = 0

function MaelstromMusic.VanillaMusic.optionVolume()
    local level = getCore():getOptionMusicVolume()
    if not level then
        return 1
    end
    return level / 10
end

function MaelstromMusic.VanillaMusic.claim(key, wanted)
    claims[key] = wanted or nil
end

local function anyClaim()
    for _ in pairs(claims) do
        return true
    end
    return false
end

function MaelstromMusic.VanillaMusic.refresh()
    if anyClaim() then
        local now = getTimestampMs()
        if silenced and now - lastAppliedAt < REAPPLY_INTERVAL_MS then
            return
        end
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
