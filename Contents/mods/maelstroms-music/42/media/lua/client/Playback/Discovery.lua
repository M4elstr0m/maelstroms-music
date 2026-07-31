require "Namespace"
require "Device"

MaelstromMusic.Playback.Discovery = {}

local DISCOVERY_RADIUS = 20

function MaelstromMusic.Playback.Discovery.scan()
    local player = getPlayer()
    if not player then
        return
    end

    local primary = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()
    if primary and instanceof(primary, "Radio") then
        MaelstromMusic.Playback.Device.ensurePlaying(primary)
    end
    if secondary and instanceof(secondary, "Radio") then
        MaelstromMusic.Playback.Device.ensurePlaying(secondary)
    end

    if player:getVehicle() then
        local part = player:getVehicle():getPartById("Radio")
        if part and part:getDeviceData() then
            MaelstromMusic.Playback.Device.ensurePlaying(part)
        end
    end

    local square = player:getSquare()
    if square then
        local playerX, playerY, playerZ = player:getX(), player:getY(), player:getZ()
        local cell = getCell()
        for dx = -DISCOVERY_RADIUS, DISCOVERY_RADIUS do
            for dy = -DISCOVERY_RADIUS, DISCOVERY_RADIUS do
                local sq = cell:getGridSquare(playerX + dx, playerY + dy, playerZ)
                if sq then
                    local objects = sq:getObjects()
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        if instanceof(obj, "IsoRadio") and obj:getDeviceData() then
                            MaelstromMusic.Playback.Device.ensurePlaying(obj)
                        end
                    end
                end
            end
        end
    end
end
