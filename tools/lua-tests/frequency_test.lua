-- Run from the repository root: lua5.1 tools/lua-tests/frequency_test.lua
local Support = dofile("tools/lua-tests/support.lua")
require "Namespace"
require "Frequency"
local Frequency = MaelstromMusic.Frequency

local stable = Frequency.assign({ "radio_a", "radio_b", "tv_x", "radio_example" })
Support.equal("radio_a keeps its hashed frequency", stable.radio_a, 91000)
Support.equal("radio_b keeps its hashed frequency", stable.radio_b, 91200)
Support.equal("tv_x keeps its hashed frequency", stable.tv_x, 92600)
Support.equal("the example station keeps its hashed frequency", stable.radio_example, 88600)

local reversed = Frequency.assign({ "radio_example", "tv_x", "radio_b", "radio_a" })
Support.check("the result does not depend on the order of the ids when nothing collides",
    reversed.radio_a == 91000 and reversed.radio_b == 91200 and reversed.tv_x == 92600)

local fixed = Frequency.assign({ "radio_a", "radio_b", "radio_c" }, { radio_a = 91500, radio_b = 91500 })
Support.equal("a fixed frequency is honoured", fixed.radio_a, 91500)
Support.equal("a second claim on the same frequency falls back to a hashed one", fixed.radio_b, 91200)
Support.equal("an unfixed station avoids nothing it does not collide with", fixed.radio_c, 91400)

local reserving = Frequency.assign({ "radio_a" }, { radio_zzz = 91000 })
Support.equal("a fixed frequency of an unknown station is ignored", reserving.radio_a, 91000)

local ids = {}
for index = 1, 130 do ids[index] = "radio_station_" .. index end
local many = Frequency.assign(ids)
local universal, extended, seen, duplicates = 0, 0, {}, 0
for _, id in ipairs(ids) do
    local value = many[id]
    if seen[value] then duplicates = duplicates + 1 end
    seen[value] = true
    if value >= Frequency.UNIVERSAL_MIN and value <= Frequency.UNIVERSAL_MAX then universal = universal + 1 else extended = extended + 1 end
    Support.check(id .. " is on the dial step", value % MaelstromMusic.FREQ_STEP == 0)
end
Support.equal("the universal band is filled first", universal, Frequency.UNIVERSAL_SLOT_COUNT)
Support.equal("the rest goes to the extended band", extended, 29)
Support.equal("no frequency is given twice", duplicates, 0)
Support.equal("an overflow station lands below or above the universal band", many.radio_station_130, 238600)

local fixedOutside = Frequency.assign({ "radio_low", "radio_high" }, { radio_low = 12000, radio_high = 400000 })
Support.check("fixed frequencies in the extended band are kept", fixedOutside.radio_low == 12000 and fixedOutside.radio_high == 400000)

Support.finish()
