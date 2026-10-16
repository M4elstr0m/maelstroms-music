require "Namespace"
require "Log"

MaelstromMusic.Scanner.Sequences = {}

-- Maps each track file of a station to its first index.
local function indexByFile(station)
    local indexes = {}
    for index, trackFile in ipairs(station.trackFiles) do
        if not indexes[trackFile] then
            indexes[trackFile] = index
        end
    end
    return indexes
end

-- Turns the "sequences" entries into forcedNext (before index to after index) and gated (after indexes),
-- logging entries that point at unknown tracks or repeat a "before".
local function link(station)
    local indexes = indexByFile(station)
    local forcedNext, gated = nil, nil
    for _, seq in ipairs(station.sequences) do
        local beforeIndex = indexes[seq.before]
        local afterIndex = indexes[seq.after]
        if beforeIndex and afterIndex then
            forcedNext = forcedNext or {}
            if forcedNext[beforeIndex] and forcedNext[beforeIndex] ~= afterIndex then
                MaelstromMusic.Log.write("'" .. station.title .. "' has more than one \"sequences\" entry for '" .. seq.before .. "' - keeping the last one.")
            end
            forcedNext[beforeIndex] = afterIndex
            gated = gated or {}
            gated[afterIndex] = true
        else
            MaelstromMusic.Log.write("'" .. station.title .. "' has a \"sequences\" entry referencing a track that isn't in this station ('" .. seq.before .. "' -> '" .. seq.after .. "'), skipping it.")
        end
    end
    return forcedNext, gated
end

-- Warns when every track is the target of a sequence, since none could then start on its own.
local function warnIfUnreachable(station, gated)
    local gatedCount = 0
    for _ in pairs(gated) do
        gatedCount = gatedCount + 1
    end
    if gatedCount >= #station.trackFiles then
        MaelstromMusic.Log.write("'" .. station.title .. "' has every track gated by \"sequences\" - nothing can ever play, since at least one track must be reachable on its own.")
    end
end

-- Warns once per loop when a chain of forced hand offs leads back to itself.
local function warnOnCycles(station, forcedNext)
    local reported = {}
    for start, _ in pairs(forcedNext) do
        if not reported[start] then
            local visited = {}
            local current = start
            while current and forcedNext[current] and not visited[current] do
                visited[current] = true
                current = forcedNext[current]
            end
            if current and visited[current] then
                for node in pairs(visited) do
                    reported[node] = true
                end
                MaelstromMusic.Log.write("'" .. station.title .. "' has a \"sequences\" cycle (some chain of \"before\"/\"after\" entries loops back on itself) - once entered it plays forever and every other track becomes unreachable. Check your chain for a loop.")
            end
        end
    end
end

-- forcedNext[beforeIndex] = afterIndex drives the forced hand-off itself. gated[index] marks
-- a track as an "after" target - those never come up on their own, only via their forced
-- predecessor(s), even in a chain (a track can be both a "before" and an "after" at once).
function MaelstromMusic.Scanner.Sequences.resolve(station)
    if not station.sequences then
        return nil, nil
    end
    local forcedNext, gated = link(station)
    if gated then
        warnIfUnreachable(station, gated)
    end
    if forcedNext then
        warnOnCycles(station, forcedNext)
    end
    return forcedNext, gated
end
