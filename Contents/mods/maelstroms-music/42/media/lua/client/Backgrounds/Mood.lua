require "Namespace"

MaelstromMusic.Ambience.Mood = {}

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
