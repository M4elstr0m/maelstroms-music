require "Namespace"
require "Cache"
require "Device"
require "DeviceRange"

MaelstromMusic.Playback.Hooks = {}

local origPerformSetChannel = ISRadioAction.performSetChannel
function ISRadioAction:performSetChannel()
    local deviceData = self.deviceData
    local oldChannel = deviceData and deviceData:getChannel()

    origPerformSetChannel(self)

    if not deviceData then
        return
    end

    MaelstromMusic.Playback.Cache.ensureFrequencyMap()
    local newChannel = deviceData:getChannel()
    local entry = MaelstromMusic.Playback.Cache.get(deviceData)

    if entry and oldChannel == newChannel and MaelstromMusic.Playback.Cache.stationForFrequency(newChannel) == entry.stationId then
        MaelstromMusic.Playback.Device.playStation(entry.stationId, entry.device)
    elseif entry and MaelstromMusic.Playback.Cache.stationForFrequency(newChannel) ~= entry.stationId then
        entry.sound:stop()
        MaelstromMusic.Playback.Cache.remove(entry)
        local newStationId = MaelstromMusic.Playback.Cache.stationForFrequency(newChannel)
        if newStationId then
            MaelstromMusic.Playback.Device.playStation(newStationId, self.device)
        end
    elseif not entry then
        local newStationId = MaelstromMusic.Playback.Cache.stationForFrequency(newChannel)
        if newStationId then
            MaelstromMusic.Playback.Device.playStation(newStationId, self.device)
        end
    end
end

local origReadPresets = RWMChannel.readPresets
local origReadPresetsTV = RWMChannelTV.readPresets

local function ensureStationPresets(devicePresets, deviceData)
    local presets = devicePresets:getPresets()
    if not presets then
        return false
    end

    local wantKind = deviceData:getIsTelevision() and "television" or "radio"

    local kindCount = 0
    for _, station in pairs(MaelstromMusic.Broadcasts or {}) do
        if station.kind == wantKind then
            kindCount = kindCount + 1
        end
    end
    MaelstromMusic.Playback.DeviceRange.ensureWindow(deviceData, kindCount)

    local minChannel = deviceData:getMinChannelRange()
    local maxChannel = deviceData:getMaxChannelRange()

    local added = false
    for stationId, station in pairs(MaelstromMusic.Broadcasts or {}) do
        local freq = station.frequency
        if station.kind == wantKind and station.autoPreset and freq >= minChannel and freq <= maxChannel then
            local found = false
            for i = 0, presets:size() - 1 do
                if presets:get(i):getFrequency() == freq then
                    found = true
                    break
                end
            end
            if not found then
                if devicePresets:getMaxPresets() < presets:size() + 1 then
                    devicePresets:setMaxPresets(presets:size() + 1)
                end
                devicePresets:addPreset(station.title, freq)
                added = true
            end
        end
    end
    return added
end

function RWMChannel:readPresets(_selected)
    if self.deviceData and self.deviceData:getDevicePresets() then
        if ensureStationPresets(self.deviceData:getDevicePresets(), self.deviceData) then
            self.deviceData:transmitPresets()
        end
    end
    origReadPresets(self, _selected)
end

function RWMChannelTV:readPresets(_selected)
    if self.deviceData and self.deviceData:getDevicePresets() then
        if ensureStationPresets(self.deviceData:getDevicePresets(), self.deviceData) then
            self.deviceData:transmitPresets()
        end
    end
    origReadPresetsTV(self, _selected)
end
