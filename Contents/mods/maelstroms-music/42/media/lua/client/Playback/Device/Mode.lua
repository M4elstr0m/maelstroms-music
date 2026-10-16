require "Namespace"

MaelstromMusic.Playback.Device.Mode = {}

local VOLUME_MODIFIER = { held = 0.6, vehicleInside = 0.8, vehicleOutside = 0.3, world = 0.4 }

-- Playback mode of a device: held, vehicleInside, vehicleOutside or world.
function MaelstromMusic.Playback.Device.Mode.of(deviceData)
    if deviceData.isInventoryDevice and deviceData:isInventoryDevice() then
        return "held"
    end
    if deviceData.isVehicleDevice and deviceData:isVehicleDevice() then
        local part = deviceData:getParent()
        local vehicle = part and part:getVehicle()
        if vehicle and vehicle == getPlayer():getVehicle() then
            return "vehicleInside"
        end
        return "vehicleOutside"
    end
    return "world"
end

-- Whether a mode plays in the world rather than flat.
function MaelstromMusic.Playback.Device.Mode.isPositional(mode)
    return mode == "world" or mode == "vehicleOutside"
end

-- Whether a mode is carried by the player, so its loudness does not depend on the distance.
function MaelstromMusic.Playback.Device.Mode.isCarried(mode)
    return mode == "held" or mode == "vehicleInside"
end

-- Applies the loudness modifier and 2D or 3D playback of a mode to a sound.
function MaelstromMusic.Playback.Device.Mode.apply(sound, mode)
    local modifier = VOLUME_MODIFIER[mode]
    if sound.volumeModifier ~= modifier then
        sound:setVolumeModifier(modifier)
    end
    local positional = MaelstromMusic.Playback.Device.Mode.isPositional(mode)
    if sound.sound3D ~= positional then
        sound:set3D(positional)
    end
end
