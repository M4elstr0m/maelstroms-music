require "Namespace"
require "Frequency"
require "Hash"

MaelstromMusic.Playback.DeviceRange = {}

local FREQ_STEP = MaelstromMusic.FREQ_STEP

-- Returns an id that stays the same for a device across sessions, or nil.
local function stableDeviceId(deviceData)
    local ok, vehicle = pcall(function()
        return deviceData:isVehicleDevice() and deviceData:getParent() and deviceData:getParent():getVehicle()
    end)
    if ok and vehicle then
        return "vehicle:" .. tostring(vehicle:getId())
    end

    local ok2, id = pcall(function()
        return deviceData:getParent() and deviceData:getParent():getID()
    end)
    if ok2 and id then
        return "item:" .. tostring(id)
    end

    return nil
end

-- Widens the tunable range of a device with a per device window of the extended band,
-- so every station is reachable when there are more than the universal band holds.
function MaelstromMusic.Playback.DeviceRange.ensureWindow(deviceData, totalStationCount)
    local extendedMin = MaelstromMusic.Frequency.EXTENDED_MIN
    local extendedMax = MaelstromMusic.Frequency.EXTENDED_MAX
    local universalSlotCount = MaelstromMusic.Frequency.UNIVERSAL_SLOT_COUNT

    local nativeMin = deviceData:getMinChannelRange()
    local nativeMax = deviceData:getMaxChannelRange()

    if nativeMin <= extendedMin and nativeMax >= extendedMax then
        return
    end
    if totalStationCount <= universalSlotCount then
        return
    end

    local id = stableDeviceId(deviceData)
    if not id then
        return
    end

    local nativeSpanSlots = math.floor((nativeMax - nativeMin) / FREQ_STEP) + 1
    local extraWidth = math.min(nativeSpanSlots * FREQ_STEP, extendedMax - extendedMin)

    local maxOffsetSlots = math.floor(((extendedMax - extendedMin) - extraWidth) / FREQ_STEP)
    local offset = 0
    if maxOffsetSlots > 0 then
        offset = (MaelstromMusic.Hash.of(id) % (maxOffsetSlots + 1)) * FREQ_STEP
    end

    local extraMin = extendedMin + offset
    local extraMax = extraMin + extraWidth

    local newMin = math.min(nativeMin, extraMin)
    local newMax = math.max(nativeMax, extraMax)

    if newMin < nativeMin or newMax > nativeMax then
        deviceData:setMinChannelRange(newMin)
        deviceData:setMaxChannelRange(newMax)
    end
end
