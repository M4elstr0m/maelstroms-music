require "Namespace"
require "Log"
require "Playback/Cache"
require "Playback/Device/Location"
require "Playback/Device/Voices"

MaelstromMusic.Playback.Device.Orphans = {}

local ORPHAN_ADOPT_RADIUS = 20

-- Finds a playing orphaned entry of this device or of the same station nearby.
local function find(stationId, deviceData, x, y)
    local own = MaelstromMusic.Playback.Cache.get(deviceData)
    if own and own.orphanedAt then
        if own.sound:isPlaying() then
            return own
        end
        MaelstromMusic.Playback.Cache.remove(own)
    end
    return MaelstromMusic.Playback.Cache.takeOrphan(stationId, x, y, ORPHAN_ADOPT_RADIUS)
end

-- Re-attaches a playing orphaned entry to a moved device so the track keeps playing.
function MaelstromMusic.Playback.Device.Orphans.adopt(stationId, device, deviceData)
    local Voices = MaelstromMusic.Playback.Device.Voices
    local x, y, z = MaelstromMusic.Playback.Device.Location.of(device, deviceData)
    local entry = find(stationId, deviceData, x, y)
    if not entry then
        return false
    end
    entry.device = device
    entry.deviceData = deviceData
    entry.orphanedAt = nil
    entry.x, entry.y, entry.z = x or entry.x, y or entry.y, z or entry.z
    Voices.configure(entry.sound, device, deviceData, entry.companion ~= nil)
    if entry.companion then
        Voices.configure(entry.companion, device, deviceData, true)
    end
    entry.sound:setVolume(deviceData:getDeviceVolume())
    MaelstromMusic.Log.write("'" .. MaelstromMusic.Broadcasts[stationId].title .. "' keeps playing on the moved device.")
    return true
end
