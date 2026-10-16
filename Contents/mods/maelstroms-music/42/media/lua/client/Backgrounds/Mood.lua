require "Namespace"

MaelstromMusic.Ambience.Mood = {}

-- Drama value from 0 to 10 based on the zombies visible or chasing the player.
function MaelstromMusic.Ambience.Mood.current()
    local player = getPlayer()
    if not player then
        return 0
    end

    local stats = player:getStats()
    local total = stats:getNumVisibleZombies() + stats:getNumChasingZombies()
    if total == 0 then
        return 0
    end

    return math.min(total + 3, 10)
end

-- Whether at least one background mood is available.
function MaelstromMusic.Ambience.Mood.available()
    if not MaelstromMusic.Backgrounds then
        return false
    end
    for _ in pairs(MaelstromMusic.Backgrounds) do
        return true
    end
    return false
end

-- Picks the mood whose drama value is closest to the given one.
function MaelstromMusic.Ambience.Mood.closest(drama)
    local bestId, bestDiff = nil, nil
    for id, background in pairs(MaelstromMusic.Backgrounds) do
        local diff = math.abs(drama - background.drama)
        if not bestDiff or diff < bestDiff then
            bestId, bestDiff = id, diff
        end
    end
    return bestId
end
