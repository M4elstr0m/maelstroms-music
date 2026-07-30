require "Namespace"

MaelstromMusic.Playback.Track = {}

function MaelstromMusic.Playback.Track.chooseNext(stationId, currentIndex)
    local station = MaelstromMusic.Broadcasts and MaelstromMusic.Broadcasts[stationId]
    if not station or not station.tracks or #station.tracks == 0 then
        return nil, nil
    end
    local tracks = station.tracks
    local nextIndex
    if station.shuffle and #tracks > 1 then
        repeat
            nextIndex = ZombRand(1, #tracks + 1)
        until nextIndex ~= currentIndex
    else
        nextIndex = (currentIndex or 0) + 1
        if nextIndex > #tracks then
            nextIndex = 1
        end
    end
    return tracks[nextIndex], nextIndex
end
