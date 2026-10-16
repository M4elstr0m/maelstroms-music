require "Namespace"
require "Log"

MaelstromMusic.Scanner.Merge = {}

-- Stations opted into "mergeTracks" and sharing the same title (case-insensitive) are
-- folded into a single station, tracks from every contributor. First source encountered
-- (base mod, then addons in modId order) keeps its stationId and wins on shuffle/fade/
-- frequency for the rest. Stations without mergeTracks never merge with anything, even
-- if another station happens to share their title.
function MaelstromMusic.Scanner.Merge.shared(entries, stations)
    local primaryIdByTitle = {}
    for _, entry in ipairs(entries) do
        local stationId, station = entry.stationId, entry.station
        if station.mergeTracks then
            local key = string.lower(station.title)
            local primaryId = primaryIdByTitle[key]
            if not primaryId then
                primaryIdByTitle[key] = stationId
                stations[stationId] = station
            else
                local primary = stations[primaryId]
                for i, trackFile in ipairs(station.trackFiles) do
                    table.insert(primary.trackFiles, trackFile)
                    table.insert(primary.trackDirs, station.trackDirs[i])
                end
                if station.sequences then
                    primary.sequences = primary.sequences or {}
                    for _, seq in ipairs(station.sequences) do
                        table.insert(primary.sequences, seq)
                    end
                end
                MaelstromMusic.Log.write("merged " .. #station.trackFiles .. " track(s) from '" .. station.ownerModId .. "' into shared " .. station.kind .. " '" .. primary.title .. "' (owned by '" .. primary.ownerModId .. "') via mergeTracks.")
            end
        else
            stations[stationId] = station
        end
    end
end
