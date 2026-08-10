require "Namespace"

MaelstromMusic.Playback.Track = {}

function MaelstromMusic.Playback.Track.chooseNext(station, currentIndex)
    if not station or not station.tracks or #station.tracks == 0 then
        return nil, nil
    end
    local tracks = station.tracks
    if station.forcedNext and currentIndex and station.forcedNext[currentIndex] then
        local nextIndex = station.forcedNext[currentIndex]
        if tracks[nextIndex] then
            return tracks[nextIndex], nextIndex
        end
    end

    -- Gated tracks (an "after" target in sequences) never come up outside of a forced
    -- hand-off, so they're excluded from every normal shuffle/sequential pick below.
    local gated = station.gated
    local nextIndex
    if station.shuffle and #tracks > 1 then
        local eligible = {}
        for i = 1, #tracks do
            if i ~= currentIndex and not (gated and gated[i]) then
                table.insert(eligible, i)
            end
        end
        if #eligible == 0 then
            for i = 1, #tracks do
                table.insert(eligible, i)
            end
        end
        nextIndex = eligible[ZombRand(1, #eligible + 1)]
    else
        nextIndex = currentIndex or 0
        local attempts = 0
        repeat
            nextIndex = nextIndex + 1
            if nextIndex > #tracks then
                nextIndex = 1
            end
            attempts = attempts + 1
        until not (gated and gated[nextIndex]) or attempts > #tracks
    end
    return tracks[nextIndex], nextIndex
end
