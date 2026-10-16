require "Namespace"

MaelstromMusic.Playback.Device.Location = {}

-- World position of a device: its vehicle, the player carrying it or its own square.
function MaelstromMusic.Playback.Device.Location.of(device, deviceData)
    if deviceData.isVehicleDevice and deviceData:isVehicleDevice() then
        local vehicle = deviceData:getParent() and deviceData:getParent():getVehicle()
        if vehicle then
            return vehicle:getX(), vehicle:getY(), vehicle:getZ()
        end
    end
    if device.isInPlayerInventory and device:isInPlayerInventory() then
        local player = getPlayer()
        return player:getX(), player:getY(), player:getZ()
    end
    if device.getSquare and device:getSquare() then
        return device:getX(), device:getY(), device:getZ()
    end
    return nil, nil, nil
end

-- Whether the device still exists in the world, in a container or in a vehicle.
function MaelstromMusic.Playback.Device.Location.isPresent(device, deviceData)
    if deviceData.isVehicleDevice and deviceData:isVehicleDevice() then
        local part = deviceData:getParent()
        return part ~= nil and part:getVehicle() ~= nil
    end
    if instanceof(device, "InventoryItem") then
        return device:getContainer() ~= nil or device:getWorldItem() ~= nil
    end
    return device:getObjectIndex() ~= -1
end
