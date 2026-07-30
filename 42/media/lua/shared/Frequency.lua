require "Namespace"

MaelstromMusic.Frequency = {}

local FREQ_STEP = 200

local UNIVERSAL_MIN = 88000
local UNIVERSAL_MAX = 108000
local UNIVERSAL_SLOT_COUNT = math.floor((UNIVERSAL_MAX - UNIVERSAL_MIN) / FREQ_STEP) + 1

local EXTENDED_MIN = 10000
local EXTENDED_MAX = 500000
local BELOW_UNIVERSAL_SLOT_COUNT = math.floor((UNIVERSAL_MIN - EXTENDED_MIN) / FREQ_STEP)
local ABOVE_UNIVERSAL_SLOT_COUNT = math.floor((EXTENDED_MAX - UNIVERSAL_MAX) / FREQ_STEP)
local EXTENDED_SLOT_COUNT = BELOW_UNIVERSAL_SLOT_COUNT + ABOVE_UNIVERSAL_SLOT_COUNT

MaelstromMusic.Frequency.EXTENDED_MIN = EXTENDED_MIN
MaelstromMusic.Frequency.EXTENDED_MAX = EXTENDED_MAX
MaelstromMusic.Frequency.UNIVERSAL_MIN = UNIVERSAL_MIN
MaelstromMusic.Frequency.UNIVERSAL_MAX = UNIVERSAL_MAX
MaelstromMusic.Frequency.UNIVERSAL_SLOT_COUNT = UNIVERSAL_SLOT_COUNT

local function stationHash(str)
    local hash = 5381
    for i = 1, #str do
        hash = (hash * 33 + string.byte(str, i)) % 2147483647
    end
    return hash
end

local function probeSlot(seed, slotCount, takenSlots)
    local slot = seed % slotCount
    local attempts = 0
    while takenSlots[slot] and attempts < slotCount do
        slot = (slot + 1) % slotCount
        attempts = attempts + 1
    end
    if takenSlots[slot] then
        return nil
    end
    return slot
end

local function extendedSlotToFrequency(index)
    if index < BELOW_UNIVERSAL_SLOT_COUNT then
        return EXTENDED_MIN + index * FREQ_STEP
    end
    return (UNIVERSAL_MAX + FREQ_STEP) + (index - BELOW_UNIVERSAL_SLOT_COUNT) * FREQ_STEP
end

function MaelstromMusic.Frequency.assign(stationIds)
    local frequencyByStationId = {}
    local universalTaken = {}
    local extendedTaken = {}

    for _, stationId in ipairs(stationIds) do
        local hash = stationHash(stationId)
        local universalSlot = probeSlot(hash, UNIVERSAL_SLOT_COUNT, universalTaken)
        if universalSlot then
            universalTaken[universalSlot] = true
            frequencyByStationId[stationId] = UNIVERSAL_MIN + universalSlot * FREQ_STEP
        else
            local extendedSlot = probeSlot(hash, EXTENDED_SLOT_COUNT, extendedTaken)
            if extendedSlot then
                extendedTaken[extendedSlot] = true
                frequencyByStationId[stationId] = extendedSlotToFrequency(extendedSlot)
            end
        end
    end

    return frequencyByStationId
end
