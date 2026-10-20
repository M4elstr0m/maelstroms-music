require "Namespace"
require "Playback/Track"
require "Playback/Warmup"

MaelstromMusic.Playback.PickQueue = {}
MaelstromMusic.Playback.PickQueue.__index = MaelstromMusic.Playback.PickQueue

local LOOKAHEAD = 2

-- Creates an empty queue of upcoming tracks, kept per station or mood id.
function MaelstromMusic.Playback.PickQueue.new()
    return setmetatable({ picksById = {} }, MaelstromMusic.Playback.PickQueue)
end

-- Number of tracks waiting for an id.
function MaelstromMusic.Playback.PickQueue:count(id)
    local picks = self.picksById[id]
    return picks and #picks or 0
end

-- Queues tracks for an id until the lookahead is full, continuing after the last queued track
-- (or afterIndex when none is queued), and asks for each to be pre-decoded.
function MaelstromMusic.Playback.PickQueue:fill(id, station, afterIndex)
    local picks = self.picksById[id]
    if not picks then
        picks = {}
        self.picksById[id] = picks
    end
    local previous = #picks > 0 and picks[#picks].index or afterIndex
    while #picks < LOOKAHEAD do
        local name, index = MaelstromMusic.Playback.Track.chooseNext(station, previous)
        if not name then
            break
        end
        table.insert(picks, { name = name, index = index })
        MaelstromMusic.Playback.Warmup.request(name)
        previous = index
    end
end

-- Removes and returns the next queued pick of an id, or nil when none is waiting.
function MaelstromMusic.Playback.PickQueue:take(id)
    local picks = self.picksById[id]
    return picks and table.remove(picks, 1) or nil
end

-- Queues the first tracks of the stations (at most limit of them when given) and returns how many tracks were queued.
function MaelstromMusic.Playback.PickQueue:prime(stationsById, limit)
    local queued, seeded = 0, 0
    for id, station in pairs(stationsById) do
        if limit and seeded >= limit then
            break
        end
        local before = self:count(id)
        self:fill(id, station)
        local added = self:count(id) - before
        if added > 0 then
            queued = queued + added
            seeded = seeded + 1
        end
    end
    return queued
end
